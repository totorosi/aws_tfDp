output "namespace" {
  description = "ArgoCD 가 설치된 네임스페이스"
  value       = local.namespace
}

output "chart_version" {
  description = "설치된 argo-cd 차트 버전"
  value       = helm_release.argocd.version
}

output "ingress_hostname" {
  description = "ArgoCD UI 의 ALB 주소 (생성에 2~3분 걸립니다)"
  value = try(
    kubernetes_ingress_v1.argocd[0].status[0].load_balancer[0].ingress[0].hostname,
    "생성 중 - 잠시 후 kubectl -n ${local.namespace} get ingress 로 확인하세요"
  )
}

output "initial_password_command" {
  description = "ArgoCD admin 초기 비밀번호 조회 명령"
  value       = "kubectl -n ${local.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}

output "application_name" {
  description = "생성된 ArgoCD Application 이름 (없으면 빈 값)"
  value       = var.create_application && var.git_repo_url != "" ? var.app_name : ""
}
