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
  region             = local.region
}

# --------------------------------------------------------------------------------
module "eks" {
  source = "../modules/eks"

  key_pair   = local.key_pair
  tag_header = local.tag_header
  region     = local.region

  # VPC 와 서브넷을 값으로 넘겨주면 network -> eks 의존 관계가 그래프에 생겨
  # Terraform 이 순서를 알아서 보장합니다. (depends_on 불필요)
  vpc_id             = local.vpc_id
  cluster_subnet_ids = local.cluster_subnet_ids
}

# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------
# --------------------------------------------------------------------------------
module "external_dns" {
  source = "../modules/external-dns"

  # 클러스터 접속 정보 (eks 모듈 출력값)
  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  oidc_provider_arn      = module.eks.oidc_provider_arn

  tag_header = local.tag_header

  # 관리할 도메인. 비워두면 모듈이 아무 레코드도 만들지 않습니다.
  domain_filters = var.external_dns_domains

  # upsert-only: 레코드를 만들고 고치기만 하고 지우지는 않습니다.
  policy = var.external_dns_policy
}

# --------------------------------------------------------------------------------
module "argocd" {
  source = "../modules/argocd"

  # 클러스터 접속 정보 (eks 모듈 출력값)
  cluster_name           = module.eks.cluster_name
  cluster_endpoint       = module.eks.cluster_endpoint
  cluster_ca_certificate = module.eks.cluster_certificate_authority_data

  tag_header = local.tag_header

  # ArgoCD 가 바라볼 Git 저장소. k8s/app 의 매니페스트를 클러스터에 맞춥니다.
  git_repo_url        = var.argocd_repo_url
  git_target_revision = var.argocd_target_revision
  git_path            = var.argocd_path

  # UI 접속용 ALB. 인증서를 지정하면 HTTPS 도 함께 엽니다.
  create_ingress  = var.argocd_create_ingress
  certificate_arn = var.argocd_certificate_arn

  # 도메인을 지정하면 HTTPS 리스너가 열리고(와일드카드 인증서 자동 탐색),
  # 호스팅 영역까지 주면 Route53 레코드도 함께 만듭니다.
  ingress_host      = var.argocd_ingress_host
  route53_zone_name = var.argocd_route53_zone_name
}

# --------------------------------------------------------------------------------
module "static_web_site" {
  source = "../modules/s3-website"

  tag_header = local.tag_header
  region     = local.region
}

# --------------------------------------------------------------------------------
# [비활성화] RDS Multi-AZ DB 클러스터
# sa-east-1 에서 쓸 수 있는 최소 사양이 db.m5d.large 이고 클러스터가 인스턴스를
# 3대 띄우므로 실습 비용이 큽니다. DB 가 필요해지면 아래 주석을 해제하세요.
# (output.tf 의 rds_* 출력값도 함께 주석 해제해야 합니다)
# module "rds" {
#   source      = "../modules/database"
#   tag_header  = local.tag_header
#   vpc_id      = local.vpc_id
#   region      = local.region
#   mysql_sg_id = local.mysql_sg_id
# }

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
