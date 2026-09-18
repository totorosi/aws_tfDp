output "bucket_name" {
  description = "생성된 S3 버킷 이름"
  value       = aws_s3_bucket.store.id
}

output "bucket_arn" {
  description = "생성된 S3 버킷 ARN"
  value       = aws_s3_bucket.store.arn
}
