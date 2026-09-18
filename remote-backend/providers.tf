# provider.tf
# ####################################################################################################
# 1. 테라폼 실행 환경 설정 블록
# ====================================================================================================
# 이 프로젝트에서 사용할 테라폼 자체의 설정과 필요한 플러그인들을 정의합니다.
terraform {
  # 프로젝트에서 사용할 클라우드 제공자(Provider) 목록을 정의합니다.
  required_providers {
    # 'aws'라는 이름으로 사용할 프로바이더 설정을 시작합니다.
    aws = {
      # 프로바이더 다운로드 경로입니다. (공식 HashiCorp 저장소의 AWS 플러그인)
      source = "hashicorp/aws"

      # 사용할 버전을 지정합니다. 
      # ~> 5.0의 의미: 5.0 이상 버전 중 가장 최신 패치 버전을 사용하겠다는 뜻입니다. (예: 5.1, 5.2 등)
      version = "~> 6.0"
    }

    # OIDC 공급자 등록 시 GitHub 인증서 지문을 받아옵니다.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  # ------------------------------------------------------------------------------------------------
  # [보안] 버킷/테이블 이름에는 계정 식별 정보가 들어가므로 코드에 적지 않습니다.
  #        아래처럼 값이 빠진 형태를 "부분 구성(partial configuration)"이라고 하며,
  #        backend 블록은 변수(var)를 쓸 수 없기 때문에 이 방식만 가능합니다.
  #
  #        [로컬 실행] backend.hcl.example 을 backend.hcl 로 복사해 본인 값을 채운 뒤
  #            terraform init -backend-config=backend.hcl
  #
  #        [최초 1회 부트스트랩] 이 디렉터리는 자기가 쓸 버킷을 자기가 만드는 코드입니다.
  #            1) 아래 backend "s3" 블록 전체를 주석 처리
  #            2) terraform init && terraform apply   (S3 버킷 + DynamoDB 테이블 생성)
  #            3) 주석을 다시 해제
  #            4) terraform init -backend-config=backend.hcl -migrate-state
  # ------------------------------------------------------------------------------------------------
  backend "s3" {
    # bucket / dynamodb_table 은 backend.hcl 로 주입합니다.
    key     = "TerraformState/remote-backend/terraform.tfstate" # 버킷 내 저장 경로
    region  = "sa-east-1"                                       # 리전 (민감 정보 아님)
    encrypt = true                                              # 상태 파일 암호화 여부
  }
}

# AWS 프로바이더 설정 블록
provider "aws" {
  # 인프라가 생성될 물리적 위치(리전)를 지정합니다.
  region = "sa-east-1"
}

