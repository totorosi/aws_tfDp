# ####################################################################################################
# ArgoCD Application
# ====================================================================================================
# ArgoCD 가 Git 저장소를 보고 클러스터를 그 상태로 맞추게 하는 리소스입니다.
# 이것만 만들어두면 이후 배포는 git push 로 이루어집니다. (GitOps)
#
# kubernetes_manifest 가 아니라 kubectl_manifest 를 쓰는 이유:
#   kubernetes_manifest 는 plan 단계에서 CRD 스키마를 조회하는데,
#   그때는 ArgoCD 가 아직 설치 전이라 Application CRD 가 없어 실패합니다.
# ####################################################################################################
resource "kubectl_manifest" "application" {
  count = var.create_application && var.git_repo_url != "" ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name = var.app_name
      # Application 은 반드시 ArgoCD 가 설치된 네임스페이스에 있어야 인식됩니다.
      namespace = local.namespace
    }
    spec = {
      project = "default"

      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_target_revision
        path           = var.git_path
      }

      destination = {
        # ArgoCD 가 자기가 돌고 있는 클러스터를 가리키는 고정 주소입니다.
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }

      syncPolicy = {
        automated = {
          # git 에서 지운 리소스를 클러스터에서도 지웁니다.
          prune = true
          # 누가 클러스터를 손으로 고치면 git 상태로 되돌립니다.
          selfHeal = true
        }
        syncOptions = [
          # 대상 네임스페이스가 없으면 만들어 줍니다.
          "CreateNamespace=true",
        ]
      }
    }
  })

  depends_on = [helm_release.argocd]
}
