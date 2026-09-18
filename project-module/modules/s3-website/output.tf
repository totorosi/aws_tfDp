output "bucket_name" {
  description = "정적 웹사이트용 S3 버킷 이름"
  value       = aws_s3_bucket.s3_website_bucket.id
}

output "bucket_arn" {
  description = "정적 웹사이트용 S3 버킷 ARN"
  value       = aws_s3_bucket.s3_website_bucket.arn
}

output "website_url" {
  description = "브라우저에서 바로 열 수 있는 웹사이트 주소"
  value       = "http://${aws_s3_bucket_website_configuration.bucket_web_config.website_endpoint}"
}
