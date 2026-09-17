resource "aws_network_acl" "this" {
  for_each = toset(local.subnet_type)
  vpc_id = aws_vpc.this.id

  # 인바운드 규칙: 모든 IP에서 HTTP(80), HTTPS(443) 및 임시 포트 허용
  ingress {
    rule_no    = 100         # 👈 원하는 100번 지정
    protocol   = "-1"        # -1은 모든 프로토콜(TCP, UDP, ICMP 등)을 의미합니다.
    action     = "allow"     # 👈 Allow 설정
    cidr_block = "0.0.0.0/0" # 모든 IP 대역
    from_port  = 0
    to_port    = 0
  }

  # 아웃바운드 규칙: 모든 트래픽 허용
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "${local.tag_header}${each.value}-nacl"
  }
}

# 서브넷과 네트워크 ACL 명시적 연결
resource "aws_network_acl_association" "nacl_assoc" {
  for_each = local.subnet_map
  subnet_id      = aws_subnet.this[each.key].id
  network_acl_id = aws_network_acl.this[each.value.type].id
}
