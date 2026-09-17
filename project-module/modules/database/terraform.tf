terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 버전은 부모와 모듈의 교집합에 맞춰집니다.
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # random_password (DB 비밀번호 생성)
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0" # null_resource (DB 초기화 - 현재 주석 처리됨)
    }
  }
}
