output "bucket_name" {
  description = "상태 파일이 저장되는 S3 버킷 이름 (backend 의 bucket 값)"
  value       = module.remote.bucket_name
}

output "lock_table_name" {
  description = "상태 잠금 DynamoDB 테이블 이름 (backend 의 dynamodb_table 값)"
  value       = module.remote.lock_table_name
}

output "backend_config" {
  description = "이 값을 그대로 backend.hcl 에 옮겨 적으면 됩니다"
  value       = module.remote.backend_config
}
