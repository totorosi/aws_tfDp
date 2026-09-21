terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2" # 락 파일 기준 3.2.1. 메이저 업그레이드 차단용
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1" # 락 파일이 고정한 버전. 에디터가 보는 스키마도 여기에 맞춰집니다
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19" # 락 파일 기준 1.19.0. 메이저 업그레이드 차단용
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # Route53 레코드 생성에 필요
    }
  }
}
