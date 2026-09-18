# ################################################################################
# [참고] 클러스터 접속 정보(cluster_name / endpoint / CA)는 더 이상 받지 않습니다.
# --------------------------------------------------------------------------------
# 예전에는 이 모듈이 자체 provider 블록을 갖고 있어서 그 값들이 필요했습니다.
# 그런데 provider 를 가진 모듈에는 Terraform 이 depends_on 을 막기 때문에
# destroy 순서를 제대로 잡을 수 없었습니다.
#
# 이제 provider 설정은 루트(projects/provider.tf)에 있고 이 모듈은 물려받기만 합니다.
# 덕분에 root 에서 module "argocd" 에 depends_on = [module.eks] 를 걸 수 있습니다.
# ################################################################################
variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

# ################################################################################
# ArgoCD 설치 옵션
# ================================================================================
variable "chart_version" {
  description = "argo-cd Helm 차트 버전"
  type        = string
  default     = "10.9.1"
}

variable "namespace" {
  description = "ArgoCD 를 설치할 네임스페이스"
  type        = string
  default     = "argocd"
}

# ################################################################################
# ArgoCD UI 접속용 Ingress (ALB)
# --------------------------------------------------------------------------------
# 도메인을 쓰지 않으므로 ALB 기본 주소(...elb.amazonaws.com)로 접속합니다.
# ================================================================================
variable "create_ingress" {
  description = "ArgoCD UI 용 ALB Ingress 생성 여부"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = <<-EOT
    HTTPS 리스너에 쓸 ACM 인증서 ARN. 비우면 HTTP 80 만 엽니다.
    도메인 없이 ALB 기본 주소로 접속하면 인증서 이름이 맞지 않아 브라우저 경고가
    나므로, 기본값은 비워 두고 HTTP 로 씁니다.
  EOT
  type        = string
  default     = ""
}

# ################################################################################
# ArgoCD 가 바라볼 Git 저장소 (Application)
# ================================================================================
variable "create_application" {
  description = "ArgoCD Application 리소스 생성 여부"
  type        = bool
  default     = true
}

variable "git_repo_url" {
  description = "ArgoCD 가 동기화할 Git 저장소 주소"
  type        = string
  default     = ""
}

variable "git_target_revision" {
  description = "동기화할 브랜치/태그"
  type        = string
  default     = "main"
}

variable "git_path" {
  description = "저장소 내 매니페스트 경로"
  type        = string
  default     = "k8s/app"
}

variable "app_name" {
  description = "ArgoCD Application 이름"
  type        = string
  default     = "web"
}

variable "app_namespace" {
  description = "앱이 배포될 네임스페이스"
  type        = string
  default     = "web"
}
