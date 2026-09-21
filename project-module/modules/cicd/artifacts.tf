# ####################################################################################################
# 아티팩트 버킷
# ====================================================================================================
# CodePipeline 이 단계 사이에 결과물을 주고받을 때 쓰는 저장소입니다.
# Source 가 받아온 소스, Build 가 만든 배포 번들이 여기에 쌓입니다.
# ####################################################################################################
resource "aws_s3_bucket" "artifacts" {
  bucket = "${local.name}-pipeline-artifacts"

  # destroy 를 한 번에 끝내려면 true 여야 합니다.
  # 파이프라인이 한 번이라도 돌면 버킷에 객체가 쌓이는데,
  # false 면 terraform destroy 가 BucketNotEmpty 로 실패합니다.
  force_destroy = var.artifact_force_destroy

  tags = { Name = "${local.name}-pipeline-artifacts" }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 오래된 아티팩트를 자동으로 정리해 비용을 막습니다.
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
