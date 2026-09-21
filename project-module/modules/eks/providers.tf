# modules/eks/providers.tf (또는 자식 모듈 내 설정 파일)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # 버전은 부모와 모듈의 교집합에 맞춰집니다.
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0" # data "tls_certificate" (OIDC 지문 추출)
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0" # data "http" (LB Controller IAM 정책 / CRD 다운로드)
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0" # null_resource (kubeconfig 갱신)
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19" # 락 파일 기준 1.19.0. 메이저 업그레이드 차단용
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2" # 락 파일 기준 3.2.1. 메이저 업그레이드 차단용
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1" # 락 파일이 고정한 버전. 에디터가 보는 스키마도 여기에 맞춰집니다
    }
  }
}

provider "kubernetes" {
  host                   = aws_eks_cluster.k8s.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.k8s.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.k8s.name]
  }
}

# [중요] kubectl 프로바이더도 반드시 설정해야 합니다.
# 이 블록이 없으면 gavinbunney/kubectl 은 기본값인 ~/.kube/config 를 읽습니다.
# 그 파일은 이전 실습의 삭제된 클러스터를 가리킬 수 있어
# "dial tcp: lookup ... no such host" 로 실패합니다.
# 아래처럼 클러스터 리소스에서 직접 접속 정보를 받아오면 그 문제가 사라집니다.
provider "kubectl" {
  host                   = aws_eks_cluster.k8s.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.k8s.certificate_authority[0].data)
  load_config_file       = false # ~/.kube/config 를 읽지 않음
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.k8s.name]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.k8s.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.k8s.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.k8s.name]
    }
  }
}