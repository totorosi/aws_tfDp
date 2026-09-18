locals {
  # [주의] 값이 빈 문자열인 태그는 제외합니다.
  # default_tags 는 모든 리소스에 붙는데, CloudFormation(SAR 스택)은
  # 태그 값이 ""이면 "Member must have length greater than or equal to 1"로
  # 거부합니다. domain_name 을 비워두면 바로 이 에러가 납니다.
  common_tags = {
    for k, v in {
      Course      = "BIPA17"
      ManageBy    = "Terraform"
      Project     = "bipa17-Solution-Architect"
      Domain      = var.domain_name
      Environment = var.env_type # prod, dev, test, lab
      Owner       = var.owner    # secret.auto.tfvars 에서 주입
    } : k => v if v != ""
  }

  key_pair = var.key_pair

  # 가용 영역을 local 블력에 변수로 정의
  azs = data.aws_availability_zones.available_az.names

  # VPC CIDR 블록을 local 변수로 정의
  vpc_cidr_block = "${var.cidr_header}.0.0/16"

  subnet_map = merge([
    for idx, key in var.subnet_type : {
      for i, az_name in local.azs : "${key}${split("-", az_name)[2]}" => {
        type = key
        az   = az_name
        cidr = "${var.cidr_header}.${i + (idx * 10 + 1)}.0/24"
        rt = key == "private" ? "${key}${split("-", az_name)[2]}" : (
          key
        )
      }
    }
  ]...)

  route_map = {
    for item in flatten([
      for type in var.subnet_type :
      type == "private" ? [
        for az in local.azs : {
          key  = "private${split("-", az)[2]}"
          type = type
        }
        ] : [
        {
          key  = type
          type = type
        }
      ]
      ]) : item.key => {
      type = item.type
    }
  }

  tag_header = (var.owner != "" && var.env_type != "") ? "${var.owner}-${var.env_type}-" : (
    (var.owner != "") ? "${var.owner}-" : ""
  )
  vpc_options = var.vpc_options


  ami_id = var.ami_type == "ubuntu2404" ? data.aws_ami.ubuntu_24_04.id : data.aws_ami.amazon_linux_2023.id

  region = data.aws_region.current.region


  vpc_id = module.network.network.vpc.id

  mysql_sg_id = module.network.mysql_sg

  # EKS 모듈에 넘길 cluster 타입 서브넷 ID 목록.
  # data 소스로 조회하지 않고 network 모듈 출력값에서 직접 뽑아내므로
  # Terraform 이 network -> eks 순서를 자동으로 보장합니다.
  # compute 모듈에 넘길 public 서브넷 ID 목록
  public_subnet_ids = [
    for k, v in module.network.network.subnets : v.id if v.tags["Type"] == "public"
  ]

  # database 모듈에 넘길 private 서브넷 ID 목록
  private_subnet_ids = [
    for k, v in module.network.network.subnets : v.id if v.tags["Type"] == "private"
  ]

  # compute 인스턴스에 붙일 보안 그룹 (SSH + 외부 HTTP/HTTPS)
  ec2_security_group_ids = [module.network.ssh_sg, module.network.external_alb_sg]

  cluster_subnet_ids = [
    for k, v in module.network.network.subnets : v.id if v.tags["Type"] == "cluster"
  ]
}


