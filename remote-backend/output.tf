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

output "github_actions_role_arn" {
  description = <<-EOT
    GitHub Actions 가 가져갈 역할의 ARN.
    이 값을 GitHub 저장소 Secret 의 AWS_ROLE_ARN 에 넣으면
    워크플로가 액세스 키 대신 OIDC 로 인증합니다.
  EOT
  value       = aws_iam_role.github_actions.arn
}

output "codestar_connection_name" {
  description = "GitHub 연결 이름. projects 가 이 이름으로 연결을 찾습니다"
  value       = try(aws_codestarconnections_connection.github[0].name, "")
}

output "codestar_connection_status" {
  description = <<-EOT
    연결 상태. PENDING 이면 콘솔에서 승인해야 파이프라인이 돕니다.
      콘솔 > CodePipeline > 설정 > 연결 > 보류 중인 연결 업데이트
  EOT
  value       = try(aws_codestarconnections_connection.github[0].connection_status, "")
}
