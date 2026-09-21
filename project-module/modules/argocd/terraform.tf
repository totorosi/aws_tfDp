terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2" # 락 파일 기준 3.2.1. 메이저 업그레이드 차단용
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0" # 3.0 에서 set / kubernetes 가 블록에서 속성으로 바뀜
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
