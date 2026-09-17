# ####################################################################################################
# remote 모듈 사용 예시
# ====================================================================================================
# module "remote" {
#   source          = "../modules/remote"
#   bucket_name     = "<본인-상태저장-S3-버킷-이름>"
#   lock_table_name = "<본인-상태잠금-DynamoDB-테이블-이름>"
#   tag_header      = local.tag_header
#   billing_mode    = "PAY_PER_REQUEST" # 잠금 테이블은 트래픽이 적어 이 쪽이 저렴합니다.
# }
#
# [주의] 이 모듈이 만드는 버킷을 backend "s3" 로 쓰려면 닭-달걀 문제가 생깁니다.
#        버킷이 없는 최초 1회는 backend 블록을 주석 처리한 채 apply 한 뒤,
#        주석을 풀고 terraform init -migrate-state 로 상태를 옮기세요.
# ####################################################################################################

# ####################################################################################################
# 1. 상태값 저장을 위한 S3 Bucket 생성
# ====================================================================================================
resource "aws_s3_bucket" "terraform_state" {
  bucket = local.bucket_name

  lifecycle {
    # 실수로 삭제되는 것을 방지합니다.
    # 이 값은 변수로 지정할 수 없으므로, 정말 지워야 할 때는 이 블록을 직접 주석 처리하세요.
    prevent_destroy = true
  }

  tags = { Name = "${local.tag_header}tfstate-bucket" }
}

# 버킷 버전 관리 활성화 (상태 복구용)
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = local.enable_versioning ? "Enabled" : "Suspended"
  }
}

# 기본 서버 측 암호화 (상태 파일에는 평문 비밀번호가 담길 수 있어 반드시 켜야 합니다)
resource "aws_s3_bucket_server_side_encryption_configuration" "state_sse" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = local.sse_algorithm == "aws:kms" && local.kms_key_id != "" ? local.kms_key_id : null
    }
    # 같은 KMS 키로 반복 호출하는 비용을 줄여줍니다.
    bucket_key_enabled = local.sse_algorithm == "aws:kms"
  }
}

# 상태 파일은 절대 공개되면 안 되므로 퍼블릭 접근을 전부 차단합니다.
resource "aws_s3_bucket_public_access_block" "state_access" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# ####################################################################################################
# 2. 상태 잠금용 DynamoDB 테이블 생성
# ====================================================================================================
resource "aws_dynamodb_table" "terraform_lock" {
  name = local.lock_table_name

  # 테이블의 비용 지불 방식 및 처리 성능 관리 모드
  billing_mode   = local.billing_mode
  read_capacity  = local.read_capacity  # RCU(초당 4KB 데이터 1개 읽기) --> 1RCU
  write_capacity = local.write_capacity # WCU(초당 1KB 데이터 1개 쓰기) --> 1WCU

  # Terraform 이 요구하는 고정 키 이름입니다. 바꾸면 잠금이 동작하지 않습니다.
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = local.enable_point_in_time_recovery
  }

  tags = { Name = "${local.tag_header}terraform-lock" }
}
