# ####################################################################################################
# S3 Endpoint 설정: VPC 내에서 S3 서비스에 대한 프라이빗 액세스를 제공하는 Gateway Endpoint 생성
# ====================================================================================================
# 1. S3 서비스 데이터 소스 정의 (리전별 서비스 이름을 가져옴)
# data.tf에 아래 내용을 정의하였음.
data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

# 2. S3 Gateway Endpoint 생성
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.this.id
  service_name = data.aws_vpc_endpoint_service.s3.service_name

  # 엔드포인트 타입 지정
  vpc_endpoint_type = "Gateway"

  # 3. 모든 라우팅 테이블에 엔드포인트 연결
  route_table_ids = [for rt in aws_route_table.this : rt.id]

  tags = {
    Name = "${local.tag_header}s3-endpoint"
  }
}

# 3. ECR API Interface Endpoint (com.amazonaws.<region>.ecr.api): 제어 및 관리 API
# 역할: IAM 인증, 이미지 메타데이터 조회, 리포지토리 생성 및 삭제 등 ECR API 제어 명령을 처리합니다.
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.ecr.api"
  vpc_endpoint_type = "Interface"

  # Public Subnet를 제외한 나머지 서브넷 ID 목록 대입
  subnet_ids = toset([
    for s in aws_subnet.this : s.id
    if lookup(s.tags, "Type", "") == "private"
  ])
  security_group_ids  = [aws_security_group.external_alb_sg.id]
  private_dns_enabled = true # ECR 기본 URL 주소 호환을 위해 필수

  tags = {
    Name = "${local.tag_header}-ecr-api-vpce"
  }
}

# 4. ECR DKR Interface Endpoint (com.amazonaws.<region>.ecr.dkr): Docker Registry / 이미지 전송
# 역할: 실제 Docker 데몬이 Container Image Layer를 가져오거나(Pull) 업로드(Push)하는
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${local.region}.ecr.dkr"
  vpc_endpoint_type = "Interface"

  # Public Subnet를 제외한 나머지 서브넷 ID 목록 대입
  subnet_ids = toset([
    for s in aws_subnet.this : s.id
    if lookup(s.tags, "Type", "") == "private"
  ])
  security_group_ids  = [aws_security_group.external_alb_sg.id]
  private_dns_enabled = true # ECR 기본 URL 주소 호환을 위해 필수

  tags = {
    Name = "${local.tag_header}-ecr-dkr-vpce"
  }
}
