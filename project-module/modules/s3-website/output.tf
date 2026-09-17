output "bucket_name" {
  description = "정적 웹사이트용 S3 버킷 이름"
  value       = aws_s3_bucket.s3_website_bucket.id
}

output "bucket_arn" {
  description = "정적 웹사이트용 S3 버킷 ARN"
  value       = aws_s3_bucket.s3_website_bucket.arn
}

output "website_endpoint" {
  description = "S3 정적 웹사이트 호스팅 엔드포인트 (도메인만)"
  value       = aws_s3_bucket_website_configuration.bucket_web_config.website_endpoint
}

output "website_url" {
  description = "브라우저에서 바로 열 수 있는 웹사이트 주소"
  value       = "http://${aws_s3_bucket_website_configuration.bucket_web_config.website_endpoint}"
}

output "bucket_regional_domain_name" {
  description = "리전이 포함된 버킷 도메인 이름 (CloudFront Origin 등에 사용)"
  value       = aws_s3_bucket.s3_website_bucket.bucket_regional_domain_name
}
