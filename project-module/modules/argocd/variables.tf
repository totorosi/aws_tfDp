# ################################################################################
# 클러스터 접속 정보 (root 에서 module.eks 출력값을 전달)
# ================================================================================
variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "cluster_endpoint" {
  description = "쿠버네티스 API 서버 엔드포인트"
  type        = string
}

variable "cluster_ca_certificate" {
  description = "클러스터 CA 인증서 (base64)"
  type        = string
  sensitive   = true
}

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
# ================================================================================
variable "create_ingress" {
  description = "ArgoCD UI 용 ALB Ingress 생성 여부"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "HTTPS 리스너에 쓸 ACM 인증서 ARN (비우면 HTTP 80 만 엽니다)"
  type        = string
  default     = ""
}

variable "ingress_host" {
  description = "ArgoCD UI 도메인 (비우면 ALB 기본 주소로 접속)"
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
