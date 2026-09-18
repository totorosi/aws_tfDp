# ################################################################################
# Network
# ================================================================================
output "vpc_id" {
  description = "생성된 VPC ID"
  value       = module.network.network.vpc.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR 블록"
  value       = module.network.network.vpc.cidr_block
}

output "subnet_ids" {
  description = "서브넷 이름 -> 서브넷 ID 맵"
  value       = { for k, v in module.network.network.subnets : k => v.id }
}

output "subnets_by_type" {
  description = "서브넷 타입(public/private/cluster) -> 서브넷 ID 목록"
  value = {
    for type in var.subnet_type : type => [
      for k, v in module.network.network.subnets : v.id if v.tags["Type"] == type
    ]
  }
}

output "mysql_security_group_id" {
  description = "MySQL 용 보안 그룹 ID"
  value       = module.network.mysql_sg
}

# ################################################################################
# EKS
# ================================================================================
output "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "쿠버네티스 API 서버 엔드포인트"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS 컨트롤 플레인 쿠버네티스 버전"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "IRSA 용 OIDC 공급자 ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_node_group_name" {
  description = "관리형 노드 그룹 이름"
  value       = module.eks.node_group_name
}

output "eks_kubeconfig_command" {
  description = "이 클러스터에 접속하기 위한 명령어"
  value       = module.eks.kubeconfig_command
}

# ################################################################################
# Static Web Site (S3)
# ================================================================================
output "website_bucket_name" {
  description = "정적 웹사이트용 S3 버킷 이름"
  value       = module.static_web_site.bucket_name
}

output "website_url" {
  description = "브라우저에서 바로 열 수 있는 정적 웹사이트 주소"
  value       = module.static_web_site.website_url
}

# ################################################################################
# Database (RDS + Proxy + Secrets Manager)
# --------------------------------------------------------------------------------
# module "rds" 가 count 를 쓰므로 [0] 인덱스로 접근하고,
# create_rds = false 일 때는 try 로 빈 값을 돌려줍니다.
# ################################################################################
output "rds_cluster_endpoint" {
  description = "RDS 클러스터 쓰기(Writer) 엔드포인트"
  value       = try(module.rds[0].cluster_endpoint, "")
}

output "rds_reader_endpoint" {
  description = "RDS 클러스터 읽기(Reader) 엔드포인트"
  value       = try(module.rds[0].cluster_reader_endpoint, "")
}

output "rds_proxy_endpoint" {
  description = "RDS Proxy 엔드포인트 (애플리케이션은 이 주소로 접속합니다)"
  value       = try(module.rds[0].proxy_endpoint, "")
}

output "rds_database_name" {
  description = "최초 생성되는 데이터베이스 이름"
  value       = try(module.rds[0].database_name, "")
}

output "rds_master_username" {
  description = "RDS 마스터 사용자 이름"
  value       = try(module.rds[0].master_username, "")
}

output "rds_secret_name" {
  description = "DB 접속 정보가 담긴 Secrets Manager 시크릿 이름"
  value       = try(module.rds[0].secret_name, "")
}

output "rds_get_password_command" {
  description = "DB 비밀번호 조회 명령 (비밀번호 자체는 출력하지 않습니다)"
  value       = try(module.rds[0].get_secret_command, "")
}

# ################################################################################
# store (범용 비공개 S3)
# ################################################################################
output "store_bucket_name" {
  description = "범용 스토리지 버킷 이름"
  value       = module.store.bucket_name
}

output "store_bucket_arn" {
  description = "범용 스토리지 버킷 ARN"
  value       = module.store.bucket_arn
}

# ################################################################################
# 공통 정보
# ================================================================================
output "region" {
  description = "리소스가 배포된 리전"
  value       = local.region
}

output "tag_header" {
  description = "모든 리소스 이름에 붙는 접두사"
  value       = local.tag_header
}

# ################################################################################
# ArgoCD
# ================================================================================
output "argocd_namespace" {
  description = "ArgoCD 네임스페이스"
  value       = module.argocd.namespace
}

output "argocd_url" {
  description = "ArgoCD UI 접속 주소"
  value       = module.argocd.url
}

output "argocd_alb_hostname" {
  description = "ArgoCD UI 의 ALB 기본 주소"
  value       = module.argocd.ingress_hostname
}

output "argocd_initial_password_command" {
  description = "ArgoCD admin 초기 비밀번호 조회 명령"
  value       = module.argocd.initial_password_command
}

output "argocd_application_name" {
  description = "생성된 ArgoCD Application 이름"
  value       = module.argocd.application_name
}

# ################################################################################
# external-dns
# ================================================================================
output "external_dns_role_arn" {
  description = "external-dns 가 사용하는 IAM 역할 ARN"
  value       = module.external_dns.role_arn
}

output "external_dns_logs_command" {
  description = "external-dns 동작 로그 확인 명령"
  value       = module.external_dns.logs_command
}

# ################################################################################
# compute (범용 EC2)
# ================================================================================
output "ec2_instance_ids" {
  description = "생성된 EC2 인스턴스 ID 목록 (ec2_instance_count 가 0 이면 빈 목록)"
  value       = module.compute.instance_ids
}

output "ec2_instances" {
  description = "EC2 인스턴스 상세 (이름 -> ID/IP/AZ)"
  value       = module.compute.instances
}

output "ec2_ssh_commands" {
  description = "퍼블릭 IP 가 있는 인스턴스의 SSH 접속 명령"
  value       = module.compute.ssh_commands
}
