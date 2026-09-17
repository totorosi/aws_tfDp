# ################################################################################
# EKS 구축 프로세스
# 네트워크 구성 => IAM권한설정 => EKS 클러스터 구성 => 노드 그룹 정의 => 액세스 환경 정의
# ================================================================================
# 서브넷 공통:     "kubernetes.io/cluster/<EKS이름>" = "shared"
# 퍼블릭 서브넷:   "kubernetes.io/role/elb" = "1"
# 프라이빗 서브넷: "kubernetes.io/role/internal-elb" = "1"
# ################################################################################




# ################################################################################
# 1. EKS 및 워커노드를 위한 보안 그룹 생성
# ================================================================================
# 노드와 컨트롤 플레인(k8s master)간 통신을 위한 포트: 10250/tcp
# 노드간 통신 모두 열어줌
resource "aws_security_group" "k8s_sg" {
  name        = "${local.tag_header}k8s-sg"
  description = "the cluster to allow internal communication"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks대신
    # secrity_groups = [aws_eks_cluster.k8s.vpc_config[0].cluster_primary_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}k8s-sg"
  }
}

# ################################################################################
# 2. k8s master 및 워커 노드용 역할 및 정책 생성
# ================================================================================
# 클러스터(k8s)용 역할(role) 생성
resource "aws_iam_role" "cluster_role" {
  name = "${local.tag_header}eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "eks.amazonaws.com" }
      }
    ]
  })
}

# 역할에서 사용할 정책 연결
# 정책 연결: 콘솔(IAM-Policy) AmazonEKSClusterPolicy(ARN)
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}
# --------------------------------------------------------------------------------
# 워커노드용 역할 및 정책
resource "aws_iam_role" "node_role" {
  name = "${local.tag_header}eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

locals {
  node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    # ECR 레포지토리 이미지 읽기
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    # SSM: SSH 없이 터미널 접속 가능
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    # Logging: 파드 및 시스템 로그 전송
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    # S3: 설정 파일이나 이미지 읽기 (필요 시 수정)
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  for_each   = toset(local.node_policies)
  policy_arn = each.value
  role       = aws_iam_role.node_role.name
}

# ################################################################################
# 3. EKS Cluster 리소스 생성
# ================================================================================
resource "aws_eks_cluster" "k8s" {
  name = "${local.tag_header}eks-cluster"

  # 워커 노드 AMI(data.aws_ami.eks_al2023_latest)와 동일한 버전으로 맞춥니다.
  # 컨트롤 플레인과 노드 버전이 어긋나면 노드가 클러스터에 조인하지 못합니다.
  version = local.k8s_version

  # 클러스터 역할
  role_arn = aws_iam_role.cluster_role.arn

  # 네트워크 설정
  vpc_config {
    subnet_ids = local.subnet_ids
  }

  # 사용자 연결 설정
  access_config {
    # EKS 클러스터가 사용자나 역할을 어떤 방식으로 인식하게 할지 지정
    # API_AND_CONFIG_MAP / ConfigMap
    authentication_mode = "API_AND_CONFIG_MAP"

    # 생성자에게 자동으로 관리자 권할을 부여
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ================================================================================
# EKS OIDC 공급자 설정 (IRSA용)
# --------------------------------------------------------------------------------
# 1. EKS 클러스터의 OIDC 발급자 URL에서 'https://' 제거 (Thumbprint 추출을 위한 data 소스 또는 함수 활용)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.k8s.identity[0].oidc[0].issuer
  depends_on = [aws_eks_cluster.k8s]
}

# 2. OIDC 공급자 등록
# 삭제: aws iam delete-open-id-connect-provider \
# --open-id-connect-provider-arn arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.<REGION>.amazonaws.com/id/<OIDC_ID>
resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.k8s.identity[0].oidc[0].issuer
}


# ################################################################################
# 4. 노드 그룹 구성
# ================================================================================
resource "aws_launch_template" "launch_template" {
  # 생성될 인스턴스들에 부여할 이름의 접두서
  name_prefix = "${local.tag_header}k8s-node-"
  # image_id대신 ami_type = "AL2023_x86_64_STANDARD"를 사용할 경우 user data를 제외
  image_id      = data.aws_ami.eks_al2023_latest.id
  instance_type = "t3.small"
  key_name      = local.key_pair != "" ? local.key_pair : null
  vpc_security_group_ids = [
    aws_security_group.k8s_sg.id,
    aws_eks_cluster.k8s.vpc_config[0].cluster_security_group_id # 0.0.0.0/0에 의미 없음, 삭제 고려 필요
  ]

  update_default_version = true
  user_data = base64encode(<<-EOT
    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${aws_eks_cluster.k8s.name}
        apiServerEndpoint: ${aws_eks_cluster.k8s.endpoint}
        certificateAuthority: ${aws_eks_cluster.k8s.certificate_authority[0].data}
        cidr: ${aws_eks_cluster.k8s.kubernetes_network_config[0].service_ipv4_cidr}
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.tag_header}k8s-node" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${local.tag_header}k8s-volume" }
  }
}

# 노드 그룹 생성: subnet_ids      = data.aws_subnets.ian_cluster_subnets.ids
resource "aws_eks_node_group" "eks_node_group" {
  node_group_name = "${local.tag_header}eks-node-group"
  cluster_name    = aws_eks_cluster.k8s.name

  node_role_arn = aws_iam_role.node_role.arn
  subnet_ids    = local.subnet_ids


  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  launch_template {
    name    = aws_launch_template.launch_template.name
    version = aws_launch_template.launch_template.latest_version # 삭제 / version = $Default
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy
  ]

}


# ################################################################################
# [추가] 사용자 연결
# ================================================================================
resource "null_resource" "update_kubeconfig" {
  depends_on = [aws_eks_node_group.eks_node_group]
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.k8s.name}"
  }
}


# ################################################################################
# 5. 사용자 등록
# ================================================================================
# [중요] 위 access_config에 bootstrap_cluster_creator_admin_permissions = true 가 켜져 있으므로,
# 클러스터를 "생성한" 사용자(= terraform 을 실행한 IAM 사용자)는 이미 admin 권한을 가집니다.
# 본인을 여기에 다시 등록하면 ResourceInUseException(이미 존재함) 에러가 납니다.
# 따라서 기본값은 빈 리스트이며, "본인 외 다른 사용자/역할"에게 권한을 줄 때만 값을 채우세요.
#   예) eks_admin_principal_arns = ["arn:aws:iam::<ACCOUNT_ID>:user/<다른-IAM-사용자명>"]
resource "aws_eks_access_entry" "addon_member" {
  for_each = toset(local.eks_admin_principal_arns)

  cluster_name = aws_eks_cluster.k8s.name
  # 등록할 사용자의 계정 ARN
  principal_arn = each.value

  # 아래와 같이 지정하고 사용자 계정을 IAM에서 역할 부여
  kubernetes_groups = ["master"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "role_admin" {
  for_each = aws_eks_access_entry.addon_member

  cluster_name  = aws_eks_cluster.k8s.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value.principal_arn

  access_scope {
    type = "cluster" # 적용범위: 클러스터 전체
  }

  depends_on = [aws_eks_access_entry.addon_member]
}




# ################################################################################
# [추가] ELB : EKS AWS LBC를 쓰면 Ingress 를 통해 생성되므로 테라폼 코드 생략
# 다만 Ingress를 사용하기 위해서는 사전 준비가 필요하여 이를 아래와 같이 정의
# ================================================================================
# ELB용 정책 생성
# --------------------------------------------------------------------------------
# 1. 깃허브에서 IAM 정책 JSON 파일을 가져옴
data "http" "iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

# 2. 가져온 JSON을 이용해 IAM 정책 생성
resource "aws_iam_policy" "lb_controller" {
  name        = "${local.tag_header}AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "AWS Load Balancer Controller IAM Policy"
  policy      = data.http.iam_policy.response_body

  tags = {
    Name  = "${local.tag_header}AWSLoadBalancerControllerIAMPolicy"
  }
}

# ================================================================================
# CRD(Custom Resource Definitions) 설치
# AWS에서 지원하지 않는 리소스를 추가
# --------------------------------------------------------------------------------
# 1. 쿠버네티스 사용을 위한 프로바이더 정의(main.tf에 작성 및 이 모듈로 전달)
# 쿠버네티스 클러스터와 통신할 수 있도록 프로바이더를 설정
#[ 위치 이동 ]

# 2. 허브의 CRD YAML 파일을 가져와  kubectl_manifest 리소스에서 사용할 수 있도록 함
data "http" "alb_controller_crds" {
  url = "https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml"
  # 참고: kustomize(-k) 방식 대신 공식 차트 저장소에 포함된 통합 CRD 원본 파일을 직접 참조하는 것이 테라폼에서 가장 안정적입니다.
}

# 3. kubectl_manifest 리소스를 통해 클러스터에 적용
resource "kubectl_manifest" "crd" {
  for_each  = data.http.alb_controller_crds.response_body != "" ?toset(split("---\n", data.http.alb_controller_crds.response_body)) : []
  yaml_body = each.value
}









# ================================================================================
# amserviceaccount 생성
# --------------------------------------------------------------------------------
# 1. IAM 역할 생성 및 OIDC 신뢰 관계 설정 (IRSA)
data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${local.tag_header}AWSLoadBalancerControllerRole"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
}

# 2. 지정해주신 IAM 정책을 역할에 연결 (Attach)
resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  # 이 모듈이 위에서 직접 생성한 정책을 참조합니다 (기존 하드코딩 ARN은 다른 계정/이름이라 실패)
  policy_arn = aws_iam_policy.lb_controller.arn
}

# 3. 쿠버네티스 ServiceAccount 생성 (역할 ARN 어노테이션 포함)
resource "kubernetes_service_account_v1" "lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lb_controller.arn
    }
  }
}



# ================================================================================
# AWS Load Balancer Controller 설치
# --------------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = "${local.tag_header}eks-cluster"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = local.region
  }

  set {
    name  = "vpcId"
    value = local.vpc_id
  }
}


