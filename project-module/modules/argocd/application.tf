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

      # ------------------------------------------------------------------------
      # [destroy 핵심] 이 finalizer 가 "한 번에 삭제"를 가능하게 합니다.
      #
      # 이게 없으면 Application 만 사라지고 그 앱이 만든 리소스
      # (Deployment / Service / Ingress / Namespace)는 클러스터에 그대로 남습니다.
      # 특히 Ingress 가 남으면 ALB 도 남고, ALB 가 남으면 IGW 분리와 VPC 삭제가 막힙니다.
      #
      # finalizer 가 있으면 Application 을 지울 때 ArgoCD 가 자기가 배포한 리소스를
      # 역순으로 전부 회수한 뒤에야 Application 이 사라집니다.
      # Ingress 가 지워지면 LB Controller 가 ALB 와 타겟그룹까지 스스로 정리합니다.
      #
      # 이게 안전하게 동작하려면 Application 이 지워지는 시점에
      # ArgoCD 와 LB Controller 가 모두 살아 있어야 합니다. 그 순서는
      # root 의 depends_on = [module.eks] 와 아래 depends_on 이 함께 보장합니다.
      # ------------------------------------------------------------------------
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
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
