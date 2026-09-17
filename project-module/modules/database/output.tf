# ################################################################################
# RDS Cluster
# ================================================================================
output "cluster_identifier" {
  description = "RDS 클러스터 식별자"
  value       = aws_rds_cluster.mysql_cluster.cluster_identifier
}

output "cluster_endpoint" {
  description = "RDS 클러스터 쓰기(Writer) 엔드포인트"
  value       = aws_rds_cluster.mysql_cluster.endpoint
}

output "cluster_reader_endpoint" {
  description = "RDS 클러스터 읽기(Reader) 엔드포인트"
  value       = aws_rds_cluster.mysql_cluster.reader_endpoint
}

output "cluster_port" {
  description = "RDS 접속 포트"
  value       = aws_rds_cluster.mysql_cluster.port
}

output "database_name" {
  description = "최초 생성되는 데이터베이스 이름"
  value       = aws_rds_cluster.mysql_cluster.database_name
}

output "master_username" {
  description = "RDS 마스터 사용자 이름 (비밀번호는 Secrets Manager 에서 조회하세요)"
  value       = aws_rds_cluster.mysql_cluster.master_username
}

output "db_subnet_group_name" {
  description = "DB 서브넷 그룹 이름"
  value       = aws_db_subnet_group.subnet_group.name
}

# ################################################################################
# RDS Proxy
# ################################################################################
output "proxy_name" {
  description = "RDS Proxy 이름"
  value       = aws_db_proxy.proxy.name
}

output "proxy_endpoint" {
  description = "RDS Proxy 엔드포인트 (애플리케이션은 이 주소로 접속합니다)"
  value       = aws_db_proxy.proxy.endpoint
}

# ################################################################################
# Secrets Manager
# ================================================================================
output "secret_name" {
  description = "DB 접속 정보가 담긴 Secrets Manager 시크릿 이름"
  value       = aws_secretsmanager_secret.mysql_secrets_manager.name
}

output "secret_arn" {
  description = "DB 접속 정보가 담긴 Secrets Manager 시크릿 ARN"
  value       = aws_secretsmanager_secret.mysql_secrets_manager.arn
}

output "get_secret_command" {
  description = "DB 비밀번호를 조회하는 명령어 (비밀번호는 출력값으로 노출하지 않습니다)"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.mysql_secrets_manager.name} --region ${local.region} --query SecretString --output text"
}

# ################################################################################
# 보안 그룹
# ================================================================================
output "lambda_security_group_id" {
  description = "암호 순환 Lambda 용 보안 그룹 ID"
  value       = aws_security_group.lambda_sg.id
}
