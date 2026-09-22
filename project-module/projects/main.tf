module "network" {
  source = "../modules/network"

  azs                = local.azs
  vpc_cidr_block     = local.vpc_cidr_block
  subnet_map         = local.subnet_map
  route_map          = local.route_map
  subnet_type        = var.subnet_type
  tag_header         = local.tag_header
  create_nat_gateway = var.create_nat_gateway
  key_pair           = var.key_pair
  vpc_options        = local.vpc_options
  ami_type           = var.ami_type
  ami_id             = local.ami_id
  ssh_allowed_cidrs  = var.ssh_allowed_cidrs
}

# --------------------------------------------------------------------------------
# module "eks" {
# source = "../modules/eks"

# key_pair   = local.key_pair
# tag_header = local.tag_header
# region     = local.region

# VPC 와 서브넷을 값으로 넘겨주면 network -> eks 의존 관계가 그래프에 생겨
# Terraform 이 순서를 알아서 보장합니다. (depends_on 불필요)
# vpc_id             = local.vpc_id
# cluster_subnet_ids = local.cluster_subnet_ids

# [중요] 인터넷 경로(NAT/라우팅)를 값으로 받아 의존 간선을 만듭니다.
# 이게 없으면 destroy 때 EKS 정리 도중에 NAT 가 먼저 사라져
# 노드가 NotReady 가 되고 Ingress finalizer 가 남습니다.
# network_internet_path = module.network.internet_path

# CI(GitHub Actions) 역할에 클러스터 admin 을 부여합니다.
# 이게 없으면 OIDC 로 전환한 CI 가 kubernetes/helm 프로바이더에서 Unauthorized 로 막힙니다.
# eks_admin_principal_arns = local.eks_admin_principal_arns
# }

# --------------------------------------------------------------------------------
# ArgoCD + Ingress (GitOps 배포 진입점)
# --------------------------------------------------------------------------------
# [핵심] depends_on = [module.eks] 가 "한 번에 삭제"의 뼈대입니다.
#
# Terraform 은 의존 관계의 "역순"으로 파괴합니다. 이 한 줄로 argocd 모듈의 모든
# 리소스가 eks 모듈의 모든 리소스보다 먼저 파괴되는 것이 보장됩니다.
#
#   파괴 순서
#     Application(finalizer -> ArgoCD 가 nginx 리소스 회수)
#       -> ArgoCD Ingress -> ArgoCD Helm
#       -> [eks] ingress_cleanup -> LB Controller -> CRD/SA -> 노드그룹 -> 클러스터
#
# 이 순서 덕분에 Ingress 가 지워지는 모든 시점에 LB Controller 와 노드가 살아 있어,
# 컨트롤러가 ALB·타겟그룹·보안그룹을 스스로 회수합니다.
#
# 예전에는 argocd 모듈이 자체 provider 블록을 갖고 있어 이 depends_on 을 쓸 수
# 없었습니다. provider 설정을 provider.tf(루트)로 옮겨서 풀었습니다.
# module "argocd" {
# source = "../modules/argocd"

# depends_on = [module.eks]

# tag_header = local.tag_header

# ArgoCD 가 바라볼 Git 저장소. k8s/app 의 매니페스트를 클러스터에 맞춥니다.
# git_repo_url        = var.argocd_repo_url
# git_target_revision = var.argocd_target_revision
# git_path            = var.argocd_path

# UI 접속용 ALB. 도메인을 쓰지 않으므로 ALB 기본 주소로 접속합니다.
# 인증서 ARN 을 지정하면 HTTPS 도 함께 엽니다. (기본값은 HTTP 만)
# create_ingress  = var.argocd_create_ingress
# certificate_arn = var.argocd_certificate_arn
# }

# --------------------------------------------------------------------------------
# 범용 비공개 S3 스토리지. s3-website 가 퍼블릭 정적 사이트라면 이쪽은 그 반대입니다.
# 퍼블릭 차단 + 버전 관리 + SSE + HTTPS 강제 정책이 들어갑니다.
module "store" {
  source = "../modules/store"

  bucket_name = var.store_bucket_name
  tag_header  = local.tag_header

  lifecycle_rules = var.store_lifecycle_rules
}

# --------------------------------------------------------------------------------
module "static_web_site" {
  source = "../modules/s3-website"

  tag_header = local.tag_header
}

# --------------------------------------------------------------------------------
# RDS Multi-AZ DB 클러스터 + RDS Proxy + Secrets Manager 자동 순환
# [비용 주의] sa-east-1 에서 쓸 수 있는 최소 사양이 db.m5d.large 이고
# Multi-AZ 클러스터는 인스턴스를 3대 띄웁니다. 실습이 끝나면 바로 정리하세요.
# 쓰지 않을 때는 terraform.tfvars 에서 create_rds = false 로 두면 됩니다.
module "rds" {
  source = "../modules/database"
  count  = var.create_rds ? 1 : 0

  tag_header  = local.tag_header
  vpc_id      = local.vpc_id
  region      = local.region
  mysql_sg_id = local.mysql_sg_id

  # network 모듈 출력값 전달. data 소스로 조회하지 않습니다.
  db_subnet_ids = local.private_subnet_ids

  db_cluster_instance_class = var.db_cluster_instance_class
}

# --------------------------------------------------------------------------------
# 범용 EC2. CodePipeline 을 켜면 이 인스턴스들이 CodeDeploy 배포 대상이 됩니다.
# create_cicd = true 일 때 인스턴스 프로파일과 식별 태그가 자동으로 붙습니다.
module "compute" {
  source = "../modules/compute"

  instance_count = var.ec2_instance_count
  instance_type  = var.ec2_instance_type

  # network 모듈 출력값을 전달합니다. data 소스로 조회하면
  # plan 시점에 서브넷이 아직 없어 실패합니다.
  subnet_ids             = local.public_subnet_ids
  vpc_security_group_ids = local.ec2_security_group_ids

  ami_id     = local.ami_id
  key_pair   = var.key_pair
  tag_header = local.tag_header

  associate_public_ip_address = var.ec2_associate_public_ip

  # --------------------------------------------------------------------------
  # CodeDeploy 연동
  # --------------------------------------------------------------------------
  # 1) 인스턴스 프로파일: 에이전트가 S3 에서 배포 번들을 받아가려면 필요합니다.
  # 2) 태그: 배포 그룹이 이 태그로 대상을 찾습니다.
  #    태그가 안 맞으면 배포가 "성공"으로 끝나면서 아무 데도 배포되지 않습니다.
  # 3) user_data: CodeDeploy 에이전트를 설치합니다. 없으면 배포가 타임아웃됩니다.
  #
  # cicd 모듈이 꺼져 있으면(count=0) 셋 다 빈 값이 되어 평범한 EC2 가 됩니다.
  iam_instance_profile = try(module.cicd[0].instance_profile_name, "")
  extra_tags           = try(module.cicd[0].deploy_tags, {})
  user_data            = local.codedeploy_user_data
}

# --------------------------------------------------------------------------------
# CodePipeline + CodeBuild + CodeDeploy (EC2 배포)
# --------------------------------------------------------------------------------
# [EKS 가 아니라 EC2 인 이유]
# CodeDeploy 가 지원하는 배포 대상은 EC2/온프레미스, Lambda, ECS 셋뿐입니다.
# EKS 는 지원하지 않습니다. 그래서 이 파이프라인은 EC2 로 배포하고,
# EKS 쪽 배포는 기존대로 ArgoCD 가 담당합니다. 두 경로는 서로 독립입니다.
#
#   GitHub ──> CodePipeline ──> CodeBuild ──> CodeDeploy ──> EC2 (nginx)
#   GitHub ──> ArgoCD ────────────────────────────────────> EKS (nginx)
module "cicd" {
  source = "../modules/cicd"
  count  = var.create_cicd ? 1 : 0

  tag_header = local.tag_header
  region     = local.region

  github_repository = var.cicd_github_repository
  github_branch     = var.cicd_github_branch

  # 이미 승인된 연결이 있으면 그 ARN 을 넣으세요. 비우면 새로 만듭니다.
  # (새로 만든 연결은 콘솔에서 사람이 한 번 승인해야 합니다)
  codestar_connection_arn = local.cicd_connection_arn
}
