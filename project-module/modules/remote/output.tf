output "bucket_name" {
  description = "상태 파일이 저장되는 S3 버킷 이름 (backend 의 bucket 값)"
  value       = aws_s3_bucket.terraform_state.id
}

output "bucket_arn" {
  description = "상태 저장 S3 버킷 ARN"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "상태 잠금 DynamoDB 테이블 이름 (backend 의 dynamodb_table 값)"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "backend_config" {
  description = "이 값을 그대로 backend.hcl 에 옮겨 적으면 됩니다."
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = aws_s3_bucket.terraform_state.region
    dynamodb_table = aws_dynamodb_table.terraform_lock.name
    encrypt        = true
  }
}
