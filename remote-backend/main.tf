# ####################################################################################################
# 2.상태값 저장을 위한 S3 Bucket 생성
# ====================================================================================================
# S3 버킷 생성
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name # 전 세계 유일한 이름이어야 함 (terraform.tfvars 에서 지정)

  lifecycle {
    prevent_destroy = true # 실수로 삭제되는 것을 방지
  }
}

# 버킷 버전 관리 활성화 (상태 복구용)
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ####################################################################################################
# 3.상태 잠금용 DynamoDB 테이블 생성
# ====================================================================================================
resource "aws_dynamodb_table" "terraform_lock" {
  name = var.lock_table_name
  # 테이블의 비용 지불 방식 및 처리 성능 관리 모드
  billing_mode   = "PROVISIONED" # PROVISIONED(사용할 성릉 예약), PAY_PER_REQUEST(쓴 만큼 지불)
  read_capacity  = 20            # RCU(초당 4KB 데이터 1개 읽기) --> 1RCU
  write_capacity = 20            # WCU(초당 1KB 데이터 1개 읽기) --> 1WCU
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
