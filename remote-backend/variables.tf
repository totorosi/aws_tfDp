# ####################################################################################################
# [보안] 아래 값들은 계정 식별 정보를 포함하므로 코드에 직접 적지 않습니다.
#        terraform.tfvars.example 을 terraform.tfvars 로 복사해서 채우세요.
#        (terraform.tfvars 는 .gitignore 에 등록되어 git 에 올라가지 않습니다)
# ====================================================================================================
variable "bucket_name" {
  description = "상태 파일(tfstate)을 저장할 S3 버킷 이름 (전 세계에서 유일해야 함)"
  type        = string
}

variable "lock_table_name" {
  description = "상태 잠금(state lock)에 사용할 DynamoDB 테이블 이름"
  type        = string
}
