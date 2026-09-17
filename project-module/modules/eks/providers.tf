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
      version = ">= 1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0" # 필요에 따라 버전 지정
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.1"
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