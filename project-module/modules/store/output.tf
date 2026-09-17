output "bucket_name" {
  description = "생성된 S3 버킷 이름"
  value       = aws_s3_bucket.store.id
}

output "bucket_arn" {
  description = "생성된 S3 버킷 ARN"
  value       = aws_s3_bucket.store.arn
}

output "bucket_domain_name" {
  description = "버킷 도메인 이름"
  value       = aws_s3_bucket.store.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "리전이 포함된 버킷 도메인 이름 (CloudFront Origin 등에 사용)"
  value       = aws_s3_bucket.store.bucket_regional_domain_name
}

output "bucket_region" {
  description = "버킷이 위치한 리전"
  value       = aws_s3_bucket.store.region
}
