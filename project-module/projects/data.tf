# 리전 정보
data "aws_region" "current" {}

# 현재 리전의 가용영역 정보를 가져오는 데이터 소스 정의
data "aws_availability_zones" "available_az" {
  state = "available"
}

# 아마존 리눅스 정보를 가져오는 데이터 소스 정의
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name = "name"
    # kernel 버전까지 적으면 에러 날 확률이 높습니다. 아래 형식이 가장 안전합니다.
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Ubuntu AMI
data "aws_ami" "ubuntu_24_04" {
  # 조건에 맞는 여러개의 리소스가 검색되었을 때 최신 버전으로 선택
  most_recent = true
  # Canonical(우분투 공식 계정)의 고유 ID입니다. "canonical" 문자열보다 ID 지정이 더 안전합니다.
  owners = ["099720109477"]

  filter {
    name = "name"
    # 24.04(Noble) 버전의 정식 릴리스 및 패치 버전을 모두 포함하는 가장 안전한 패턴입니다.
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# ################################################################################
# CI 역할 조회
# --------------------------------------------------------------------------------
# ARN 에는 계정 ID 가 들어갑니다. 공개 저장소에 적지 않으려고 이름으로 조회해
# ARN 을 얻습니다. 역할은 remote-backend 가 만듭니다.
# ################################################################################
data "aws_iam_role" "ci" {
  count = local.ci_role_name != "" ? 1 : 0
  name  = local.ci_role_name
}
