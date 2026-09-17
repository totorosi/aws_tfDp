# ################################################################################
# store 모듈: 애플리케이션 데이터/로그/백업을 담는 범용 비공개 S3 버킷
# s3-website 모듈이 "퍼블릭 정적 웹사이트"라면, 이 모듈은 그 반대인 "비공개 저장소"입니다.
# ================================================================================
variable "bucket_name" {
  description = "생성할 S3 버킷 이름 (tag_header 뒤에 붙습니다. 전 세계에서 유일해야 함)"
  type        = string
  default     = "store"
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "region" {
  description = "REGION"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "객체가 남아 있어도 버킷을 삭제할지 여부 (실습 환경은 true 가 편합니다)"
  type        = bool
  default     = true
}

variable "enable_versioning" {
  description = "버킷 버전 관리 활성화 여부"
  type        = bool
  default     = true
}

# -------------------------------------------
# 암호화 옵션
variable "sse_algorithm" {
  description = "서버 측 기본 암호화 알고리즘 (AES256 또는 aws:kms)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm 은 AES256 또는 aws:kms 만 가능합니다."
  }
}

variable "kms_key_id" {
  description = "sse_algorithm 이 aws:kms 일 때 사용할 KMS 키 ID/ARN (비우면 AWS 관리형 키)"
  type        = string
  default     = ""
}

# -------------------------------------------
# 수명 주기 옵션
variable "lifecycle_rules" {
  description = <<-EOT
    객체 수명 주기 규칙 목록. 비워두면 규칙을 만들지 않습니다.
    예)
      lifecycle_rules = [{
        id                                 = "log-archive"
        prefix                             = "logs/"
        transition_days                    = 30
        transition_storage_class           = "STANDARD_IA"
        expiration_days                    = 365
        noncurrent_version_expiration_days = 30
      }]
  EOT
  type = list(object({
    id                                 = string
    prefix                             = optional(string, "")
    enabled                            = optional(bool, true)
    transition_days                    = optional(number)
    transition_storage_class           = optional(string, "STANDARD_IA")
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
    abort_incomplete_multipart_days    = optional(number, 7)
  }))
  default = []
}
