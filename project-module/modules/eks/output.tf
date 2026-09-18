# ################################################################################
# EKS 클러스터 정보
# ================================================================================
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.k8s.name
}

output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = aws_eks_cluster.k8s.arn
}

output "cluster_endpoint" {
  description = "쿠버네티스 API 서버 엔드포인트"
  value       = aws_eks_cluster.k8s.endpoint
}

output "cluster_version" {
  description = "EKS 컨트롤 플레인 쿠버네티스 버전"
  value       = aws_eks_cluster.k8s.version
}

output "cluster_security_group_id" {
  description = "EKS 가 자동 생성한 클러스터 보안 그룹 ID"
  value       = aws_eks_cluster.k8s.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "kubeconfig 에 들어가는 클러스터 CA 인증서 (base64)"
  value       = aws_eks_cluster.k8s.certificate_authority[0].data
  sensitive   = true
}

# ################################################################################
# OIDC (IRSA)
# ================================================================================
output "oidc_provider_arn" {
  description = "IRSA 용 OIDC 공급자 ARN"
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "oidc_issuer_url" {
  description = "OIDC 발급자 URL"
  value       = aws_eks_cluster.k8s.identity[0].oidc[0].issuer
}

# ################################################################################
# 노드 그룹 / IAM
# ================================================================================
output "node_group_name" {
  description = "관리형 노드 그룹 이름"
  value       = aws_eks_node_group.eks_node_group.node_group_name
}

output "node_role_arn" {
  description = "워커 노드 IAM 역할 ARN"
  value       = aws_iam_role.node_role.arn
}

output "cluster_role_arn" {
  description = "EKS 클러스터 IAM 역할 ARN"
  value       = aws_iam_role.cluster_role.arn
}

output "lb_controller_role_arn" {
  description = "AWS Load Balancer Controller 용 IRSA 역할 ARN"
  value       = aws_iam_role.lb_controller.arn
}

output "lb_controller_policy_arn" {
  description = "AWS Load Balancer Controller 용 IAM 정책 ARN"
  value       = aws_iam_policy.lb_controller.arn
}

# ################################################################################
# 접속 명령어
# ================================================================================
output "kubeconfig_command" {
  description = "로컬에서 이 클러스터에 접속하기 위한 명령어"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.k8s.name}"
}

output "lb_controller_release_id" {
  description = <<-EOT
    LB Controller Helm 릴리스 ID.
    이 값을 Ingress 를 만드는 모듈에 넘기면 의존 관계가 생겨,
    destroy 시 Ingress 가 컨트롤러보다 먼저 파괴됩니다.
    컨트롤러가 살아 있어야 ALB·타겟그룹·보안그룹까지 정리됩니다.
  EOT
  value       = helm_release.aws_load_balancer_controller.id
}
