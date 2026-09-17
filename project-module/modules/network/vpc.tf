resource "aws_vpc" "this" {
  # 묶여있는 vpc_options 오브젝트에서 값을 가져옵니다.
  cidr_block                           = var.vpc_cidr_block
  instance_tenancy                     = var.vpc_options.instance_tenancy
  enable_dns_support                   = var.vpc_options.enable_dns_support
  enable_dns_hostnames                 = var.vpc_options.enable_dns_hostnames
  assign_generated_ipv6_cidr_block     = var.vpc_options.assign_generated_ipv6_cidr_block
  enable_network_address_usage_metrics = var.vpc_options.enable_network_address_usage_metrics
  tags = { Name = "${local.tag_header}vpc" }
}


# 2. 기본 라우팅 테이블에 Name 태그만 설정
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.this.default_route_table_id

  # route 블록을 작성하지 않으면 기존 기본 설정(VPC Local)이 그대로 유지됩니다.
  tags = {
    Name = "${local.tag_header}default-rt"
  }
}

# 3. VPC 생성 시 기본 생성된 Default Security Group 제어
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  # 태그 부여 (Name 및 추가 태그 지정)
  tags = {
    Name        = "${local.tag_header}default-sg"
    Environment = "dev"
  }

  # 보안 강화를 위해 기본 규칙을 비워두는 것을 권장합니다 (선택사항)
  # ingress = []
  # egress  = []
}