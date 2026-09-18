# ####################################################################################################
# store 모듈 사용 예시
# ====================================================================================================
# module "store" {
#   source     = "../modules/store"
#   tag_header = local.tag_header
#
#   lifecycle_rules = [{
#     id                                 = "log-archive"
#     prefix                             = "logs/"
#     transition_days                    = 30
#     expiration_days                    = 365
#     noncurrent_version_expiration_days = 30
#   }]
# }
# ####################################################################################################

# ####################################################################################################
# 1. 비공개 S3 버킷 생성
# ====================================================================================================
resource "aws_s3_bucket" "store" {
  # 주의: 버킷 이름은 전 세계 AWS 사용자 중 유일해야 합니다!
  bucket = local.bucket_name

  # true 면 객체가 남아 있어도 terraform destroy 로 버킷이 삭제됩니다.
  force_destroy = local.force_destroy

  tags = { Name = local.bucket_name }
}

# ####################################################################################################
# 2. 퍼블릭 접근 전면 차단 (s3-website 모듈과 정반대 설정입니다)
# ====================================================================================================
resource "aws_s3_bucket_public_access_block" "store_access" {
  bucket = aws_s3_bucket.store.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# 소유권을 버킷 소유자로 고정해 ACL 자체를 쓰지 않도록 합니다.
resource "aws_s3_bucket_ownership_controls" "store_ownership" {
  bucket = aws_s3_bucket.store.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ####################################################################################################
# 3. 버전 관리 및 서버 측 암호화
# ====================================================================================================
resource "aws_s3_bucket_versioning" "store_versioning" {
  bucket = aws_s3_bucket.store.id

  versioning_configuration {
    status = local.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "store_sse" {
  bucket = aws_s3_bucket.store.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = local.sse_algorithm == "aws:kms" && local.kms_key_id != "" ? local.kms_key_id : null
    }
    bucket_key_enabled = local.sse_algorithm == "aws:kms"
  }
}

# ####################################################################################################
# 4. HTTPS(TLS) 통신 강제
# 암호화되지 않은 HTTP 요청을 버킷 정책으로 거부합니다.
# ====================================================================================================
resource "aws_s3_bucket_policy" "deny_insecure_transport" {
  bucket = aws_s3_bucket.store.id

  # 퍼블릭 차단 설정이 먼저 완료된 후 실행되도록 보장
  depends_on = [aws_s3_bucket_public_access_block.store_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.store.arn,
          "${aws_s3_bucket.store.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}

# ####################################################################################################
# 5. 수명 주기 규칙 (lifecycle_rules 변수가 비어 있으면 생성되지 않음)
# ====================================================================================================
resource "aws_s3_bucket_lifecycle_configuration" "store_lifecycle" {
  count = length(local.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.store.id

  # 버전 관리 설정이 끝난 뒤 적용되어야 합니다.
  depends_on = [aws_s3_bucket_versioning.store_versioning]

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      # AWS Provider 6.x 부터 filter 블록이 필수입니다.
      filter {
        prefix = rule.value.prefix
      }

      # 일정 기간이 지나면 더 저렴한 스토리지 클래스로 이동
      dynamic "transition" {
        for_each = rule.value.transition_days != null ? [1] : []
        content {
          days          = rule.value.transition_days
          storage_class = rule.value.transition_storage_class
        }
      }

      # 일정 기간이 지나면 객체 삭제
      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }

      # 구버전(noncurrent) 객체 정리
      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_version_expiration_days
        }
      }

      # 업로드가 중단되어 남은 조각을 정리해 비용 낭비를 막습니다.
      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_days != null ? [1] : []
        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_days
        }
      }
    }
  }
}
