# ################################################################################
# EKS 클러스터 정보
# --------------------------------------------------------------------------------
# root 의 provider 설정(projects/provider.tf)과 output.tf 가 아래 값들을 씁니다.
# ================================================================================
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = aws_eks_cluster.k8s.name
}

output "cluster_endpoint" {
  description = "쿠버네티스 API 서버 엔드포인트"
  value       = aws_eks_cluster.k8s.endpoint
}

output "cluster_version" {
  description = "EKS 컨트롤 플레인 쿠버네티스 버전"
  value       = aws_eks_cluster.k8s.version
}

output "cluster_certificate_authority_data" {
  description = "kubeconfig 에 들어가는 클러스터 CA 인증서 (base64)"
  value       = aws_eks_cluster.k8s.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "IRSA 용 OIDC 공급자 ARN"
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "node_group_name" {
  description = "관리형 노드 그룹 이름"
  value       = aws_eks_node_group.eks_node_group.node_group_name
}

output "kubeconfig_command" {
  description = "로컬에서 이 클러스터에 접속하기 위한 명령어"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${aws_eks_cluster.k8s.name}"
}
