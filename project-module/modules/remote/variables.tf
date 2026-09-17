# ################################################################################
# remote 모듈: Terraform 원격 상태(remote backend) 저장소를 만드는 모듈
# ================================================================================
variable "bucket_name" {
  description = "상태 파일(tfstate)을 저장할 S3 버킷 이름 (전 세계에서 유일해야 함)"
  type        = string
}

variable "lock_table_name" {
  description = "상태 잠금(state lock)에 사용할 DynamoDB 테이블 이름"
  type        = string
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

# -------------------------------------------
# S3 옵션
variable "enable_versioning" {
  description = "버킷 버전 관리 활성화 여부 (상태 파일 복구를 위해 true 권장)"
  type        = bool
  default     = true
}

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
# DynamoDB 옵션
variable "billing_mode" {
  description = <<-EOT
    DynamoDB 요금 방식.
      PROVISIONED      : 성능을 미리 예약 (강사님 원본 설정)
      PAY_PER_REQUEST  : 쓴 만큼만 지불. 잠금 테이블은 트래픽이 거의 없어서
                         실습 환경에서는 이 쪽이 훨씬 저렴합니다.
  EOT
  type        = string
  default     = "PROVISIONED"

  validation {
    condition     = contains(["PROVISIONED", "PAY_PER_REQUEST"], var.billing_mode)
    error_message = "billing_mode 는 PROVISIONED 또는 PAY_PER_REQUEST 만 가능합니다."
  }
}

variable "read_capacity" {
  description = "RCU (billing_mode 가 PROVISIONED 일 때만 사용)"
  type        = number
  default     = 20
}

variable "write_capacity" {
  description = "WCU (billing_mode 가 PROVISIONED 일 때만 사용)"
  type        = number
  default     = 20
}

variable "enable_point_in_time_recovery" {
  description = "DynamoDB 시점 복구(PITR) 활성화 여부"
  type        = bool
  default     = false
}
