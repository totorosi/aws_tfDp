# ################################################################################
# external-dns: Ingress/Service 를 보고 Route53 레코드를 자동으로 맞춰주는 컨트롤러
# --------------------------------------------------------------------------------
# ArgoCD 가 관리하는 Ingress 처럼 Terraform 이 소유하지 않는 리소스도
# 알아서 DNS 를 걸어줍니다. ALB 주소가 바뀌어도 따라갑니다.
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

variable "oidc_provider_arn" {
  description = "IRSA 용 OIDC 공급자 ARN (eks 모듈 출력값)"
  type        = string
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "chart_version" {
  description = "external-dns Helm 차트 버전"
  type        = string
  default     = "1.22.0"
}

variable "namespace" {
  description = "external-dns 를 설치할 네임스페이스"
  type        = string
  default     = "kube-system"
}

variable "domain_filters" {
  description = <<-EOT
    관리할 도메인 목록. 반드시 지정하세요.
    비워두면 계정의 모든 호스팅 영역을 건드리게 되어 위험합니다.
    예: ["example.com"]
  EOT
  type        = list(string)
  default     = []
}

variable "policy" {
  description = <<-EOT
    레코드 관리 방식.
      upsert-only : 레코드를 만들고 고치기만 합니다 (삭제 안 함). 안전한 기본값.
      sync        : Ingress 가 사라지면 레코드도 지웁니다.
  EOT
  type        = string
  default     = "upsert-only"

  validation {
    condition     = contains(["upsert-only", "sync"], var.policy)
    error_message = "policy 는 upsert-only 또는 sync 만 가능합니다."
  }
}
