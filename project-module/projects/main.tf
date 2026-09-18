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
module "eks" {
  source = "../modules/eks"

  key_pair   = local.key_pair
  tag_header = local.tag_header

  # VPC 와 서브넷을 값으로 넘겨주면 network -> eks 의존 관계가 그래프에 생겨
  # Terraform 이 순서를 알아서 보장합니다. (depends_on 불필요)
  vpc_id             = local.vpc_id
  cluster_subnet_ids = local.cluster_subnet_ids
}

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
module "argocd" {
  source = "../modules/argocd"

  depends_on = [module.eks]

  tag_header = local.tag_header

  # ArgoCD 가 바라볼 Git 저장소. k8s/app 의 매니페스트를 클러스터에 맞춥니다.
  git_repo_url        = var.argocd_repo_url
  git_target_revision = var.argocd_target_revision
  git_path            = var.argocd_path

  # UI 접속용 ALB. 도메인을 쓰지 않으므로 ALB 기본 주소로 접속합니다.
  # 인증서 ARN 을 지정하면 HTTPS 도 함께 엽니다. (기본값은 HTTP 만)
  create_ingress  = var.argocd_create_ingress
  certificate_arn = var.argocd_certificate_arn
}

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
# 범용 EC2. instance_count 기본값이 0 이라 값을 주기 전까지 아무것도 만들지 않습니다.
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
}
