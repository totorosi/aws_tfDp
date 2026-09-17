# ################################################################
# 라우팅 테이블 구성
# ================================================================
resource "aws_route_table" "this" {
  for_each = merge(local.route_map)

  vpc_id = aws_vpc.this.id

  tags = {
    # 요청하신 Name="${v.tags['Service']}-rt" 형식 적용
    Name = "${local.tag_header}${each.key}-rt"
  }
}

# 서브넷을 라우팅 테이블에 등록
resource "aws_route_table_association" "this" {
  # 생성된 12개의 서브넷 전체를 순회합니다.
  for_each = aws_subnet.this

  subnet_id = each.value.id

  # 서브넷의 'Service' 태그(public, app, db, cluster)를 키로 사용하여
  # 그에 맞는 라우팅 테이블 ID를 동적으로 선택합니다.
  route_table_id = aws_route_table.this[each.value.tags["RouteTable"]].id
}

# 1. 퍼블릭 라우팅 설정 (0.0.0.0/0 -> IGW)
resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.this["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# 1. NAT Gateway 경로 (count가 0보다 클 때만)
resource "aws_route" "private_nat_gateway_access" {
  for_each = local.create_nat_gateway ? toset([
    for k, v in local.route_map : k if v.type != "public"
  ]) : toset([]) # 0이 아니면 빈 리스트를 반환해 리소스 생성 안 함

  route_table_id         = aws_route_table.this[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# 2. NAT Instance 경로 (count가 정확히 0일 때만)
resource "aws_route" "private_nat_instance_access" {
  for_each = !local.create_nat_gateway ? toset([
    for k, v in local.route_map : k if v.type != "public"
  ]) : toset([]) # 0이 아니면 빈 리스트를 반환해 리소스 생성 안 함

  route_table_id         = aws_route_table.this[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id

  depends_on = [aws_instance.nat_instance]
}
