# ################################################################################
# Terraform Block 
# ================================================================================
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0" # 6.0~<7.0
    }
    
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0" # 필요에 따라 버전 지정
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
  }
  # ------------------------------------------------------------------------------------------------
  # [보안] 버킷/테이블 이름에는 계정 식별 정보가 들어가므로 코드에 적지 않습니다.
  #        값이 빠진 이 형태를 "부분 구성(partial configuration)"이라고 하며,
  #        backend 블록은 변수(var)를 쓸 수 없기 때문에 이 방식만 가능합니다.
  #
  #        backend.hcl.example 을 backend.hcl 로 복사해 본인 값을 채운 뒤 아래처럼 실행하세요.
  #            terraform init -backend-config=backend.hcl
  # ------------------------------------------------------------------------------------------------
  backend "s3" {
    # bucket / dynamodb_table 은 backend.hcl 로 주입합니다.
    key     = "TerraformState/project-module/terraform.tfstate" # 버킷 내 저장 경로
    region  = "sa-east-1"                                       # 리전 (민감 정보 아님)
    encrypt = true                                              # 상태 파일 암호화 여부
  }

  #  required_providers {
  #    google = {
  #      source = "hashicorp/google"
  #      version = "~>6.0" # 6.0~<7.0
  #    }
  #  }
}

# ################################################################################
# Provider Block
# ================================================================================
provider "aws" {
  region = "sa-east-1" # AWS CLI 환경설정값이 우선함.

  # 기본 태그 설정: 태라폼으로 생성한 리소스들에 추가
  default_tags {
    tags = local.common_tags
  }
}

# 별칭을 사용한 추가 리전 (서울)
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"

  default_tags {
    tags = local.common_tags
  }
}

