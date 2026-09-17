# ################################################################
# Internet Gateway 구성
# =================================================================
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.tag_header}igw"
  }
}

# ################################################################
# NAT Gateway 구성
# =================================================================
# Elastic IP 할당
resource "aws_eip" "this" {
  count = local.create_nat_gateway ? 1 : 0

  domain = "vpc"
  tags = { Name = "${local.tag_header}nat-eip" }
}

# # NAT 게이트웨이 생성
resource "aws_nat_gateway" "this" {
  count = local.create_nat_gateway ? 1 : 0

  # eip 정의: count=0인경우 인덱스로 인한 에러 방지 위해 조건문으로 0개 생성하도록 설정
  allocation_id = aws_eip.this[count.index].id

  # keys() 함수로 이름 목록을 만든 뒤, 그중 첫 번째([0]) 이름의 ID를 가져옵니다.
  # 예: keys(aws_subnet.this) -> ["public1a", "public1b", "public1c"]
  subnet_id = aws_subnet.this["public${split("-",local.azs[0])[2]}"].id
  
  # IGW를 지정하여 최종적인 대문을 정의 해줍니다.
  depends_on = [ aws_internet_gateway.this ]
  tags = { Name = "${local.tag_header}nat" }
}