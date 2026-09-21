# ################################################################################
# Terraform Block 
# ================================================================================
terraform {
  # 이 코드를 실행할 수 있는 Terraform CLI 최소 버전.
  # optional() 타입 지정, validation 블록 등을 쓰므로 1.5 이상이 필요합니다.
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0" # 6.0~<7.0
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

    # 아래 4개는 코드에서 쓰고 있지만 선언이 빠져 있던 것들입니다.
    # 선언하지 않아도 Terraform 이 리소스 이름 접두사를 보고 알아서 받아오지만,
    # 그러면 버전을 고정할 수 없어 어느 날 갑자기 메이저 업그레이드가 될 수 있습니다.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0" # eks 모듈: data "tls_certificate" (OIDC 지문 추출)
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0" # eks 모듈: data "http" (LB Controller IAM 정책/CRD 다운로드)
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0" # eks 모듈: null_resource (kubeconfig 갱신)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # database 모듈: random_password (DB 비밀번호 생성)
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


# ################################################################################
# 쿠버네티스 계열 프로바이더 (클러스터 접속 정보는 eks 모듈 출력값에서 받습니다)
# --------------------------------------------------------------------------------
# [중요] 이 블록들이 루트에 있어야 하는 이유
#
# Terraform 은 "자기 안에 provider 블록을 가진 모듈"에 depends_on / count /
# for_each 를 쓰지 못하게 막습니다. argocd 모듈이 자체 provider 를 선언하고 있던
# 동안에는 module "argocd" 에 depends_on 을 걸 수 없었고, 그래서 destroy 순서를
# 어노테이션 참조 같은 우회 수단으로만 만들 수 있었습니다.
#
# 설정을 루트로 올리면 argocd 모듈은 provider 를 물려받기만 하므로
# depends_on 이 열립니다. 이게 Terraform 이 권장하는 구조이기도 합니다.
# (modules/eks 는 자기 자신이 클러스터를 만드는 모듈이라 예외로 자체 설정을 유지합니다)
# ################################################################################
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# load_config_file = false : ~/.kube/config 에 남아 있는 옛 클러스터를 보지 않습니다.
provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}
