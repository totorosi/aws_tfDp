resource "aws_s3_bucket" "s3_website_bucket" {
  # 주의: 버킷 이름은 전 세계 AWS 사용자 중 유일해야 합니다!
  bucket = "${local.tag_header}s3-website-bucket"

  # true 면 객체가 남아 있어도 terraform destroy 로 버킷이 삭제됩니다.
  # 이게 없으면 index.html 을 한 번이라도 올리는 순간 destroy 가
  # BucketNotEmpty 로 실패합니다. (store 모듈도 같은 설정을 씁니다)
  force_destroy = var.force_destroy

  tags = {
    Name = "${local.tag_header}s3-website-bucket"
  }
}


resource "aws_s3_bucket_public_access_block" "s3_website_bucket_access" {
  bucket = aws_s3_bucket.s3_website_bucket.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "bucket_web_config" {
  bucket = aws_s3_bucket.s3_website_bucket.id

  # 접속자에게 index.html 파일이 최초 로딩 파일로 지정
  index_document {
    suffix = "index.html" # 대문 페이지 파일명
  }
  # 에러 발생할 경우 보여줄 파일 지정
  error_document {
    key = "error.html" # 페이지를 못 찾았을 때 보여줄 파일명
  }
}

# 3. 버킷 정책 적용 (누구나 읽기 가능)
resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.s3_website_bucket.id

  # public_access_block 설정이 먼저 완료된 후 실행되도록 보장
  depends_on = [aws_s3_bucket_public_access_block.s3_website_bucket_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"                                        # 모든 사용자
        Action    = "s3:GetObject"                             # 읽기 권한만 부여
        Resource  = "${aws_s3_bucket.s3_website_bucket.arn}/*" # 버킷 내부의 모든 객체
      },
    ]
  })
}


resource "aws_s3_bucket_cors_configuration" "website_cors" {
  bucket = aws_s3_bucket.s3_website_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"] # 정적 웹사이트인 경우 주로 GET, HEAD 사용
    allowed_origins = ["*"]           # 모든 곳(모든 도메인)에서 접근 허용
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
