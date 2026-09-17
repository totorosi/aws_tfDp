# ####################################################################################################
# ArgoCD 설치 (Helm)
# ====================================================================================================
# ALB 가 TLS 를 끝내고 뒤로는 HTTP 로 보내므로 argocd-server 를 insecure 모드로 둡니다.
# 이 설정이 없으면 ArgoCD 가 자체 HTTPS 를 하려 해서 ALB 와 리다이렉트 루프가 생깁니다.
# ####################################################################################################
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  namespace        = local.namespace
  create_namespace = true

  # 파드가 Ready 될 때까지 기다립니다. 아래 Application 생성이 CRD 를 필요로 합니다.
  wait    = true
  timeout = 900

  values = [yamlencode({
    configs = {
      params = {
        # ALB 가 TLS 종료 -> 백엔드는 평문 HTTP
        "server.insecure" = true
      }
    }

    server = {
      # 외부 노출은 아래 Ingress(ALB)가 담당하므로 Service 는 ClusterIP 로 둡니다.
      service = {
        type = "ClusterIP"
      }
    }
  })]
}
