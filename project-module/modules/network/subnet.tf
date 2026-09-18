# ################################################################
# Subnet 구성
# 가용 영역을 local 블력에 변수로 정의
# local.az_names = data.aws_availability_zones.available_az.names
# ================================================================
# Public subnet 구성
resource "aws_subnet" "this" { # 변수나 로컬 변수에 위 map 구조가 할당되어 있다고 가정합니다.
  # 예: for_each = var.subnet_info 또는 for_each = local.flat_subnet_map
  for_each = local.subnet_map

  vpc_id = aws_vpc.this.id

  # 맵 내부의 az, cidr 값을 각각 할당
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  # 서비스가 public인 경우에만 퍼블릭 IP 자동 할당 활성화
  map_public_ip_on_launch = each.value.type == "public" ? true : false
  # 서비스가 public인 경우에만 시작 시 DNS A 레코드 활성화
  # enable_resource_name_dns_a_record_on_launch = each.value.service == "public" ? true : false
  enable_resource_name_dns_a_record_on_launch = true
  # 태그 관리 (service 값을 활용하여 용도별 태그 자동 부여)
  tags = merge({
    "Name"        = "${local.tag_header}${each.key}-subnet"
    "Type"        = each.value.type
    "Environment" = "test"
    "RouteTable"  = each.value.rt
    },
    # 1. Public 서브넷용 태그: External ELB용
    each.value.type == "public" ? {
      "kubernetes.io/role/elb"                               = "1"
      "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
    } : {},

    # 2. Cluster(Private) 서브넷용 태그: Internal ELB용
    each.value.type == "cluster" ? {
      "kubernetes.io/role/internal-elb"                      = "1"
      "kubernetes.io/cluster/${local.tag_header}eks-cluster" = "shared"
    } : {}
  )
}
