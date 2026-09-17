terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 버전은 부모와 모듈의 교집합에 맞춰집니다.
    }
  }
}