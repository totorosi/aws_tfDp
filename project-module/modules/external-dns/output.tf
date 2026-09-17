output "role_arn" {
  description = "external-dns 가 사용하는 IAM 역할 ARN"
  value       = aws_iam_role.external_dns.arn
}

output "namespace" {
  description = "external-dns 가 설치된 네임스페이스"
  value       = local.namespace
}

output "domain_filters" {
  description = "관리 대상 도메인 목록"
  value       = var.domain_filters
}

output "logs_command" {
  description = "external-dns 동작 로그 확인 명령"
  value       = "kubectl -n ${local.namespace} logs -l app.kubernetes.io/name=external-dns -f"
}
