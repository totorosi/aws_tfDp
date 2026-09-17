# modules/eks/providers.tf (또는 자식 모듈 내 설정 파일)
terraform {
  required_providers {
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