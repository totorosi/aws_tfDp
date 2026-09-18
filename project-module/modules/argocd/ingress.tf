# ####################################################################################################
# ArgoCD UI 접속용 ALB Ingress
# ====================================================================================================
# 실제 ALB 는 이 Ingress 를 보고 AWS Load Balancer Controller 가 만듭니다.
# Terraform 이 aws_lb 를 직접 만들지 않습니다.
#
# 도메인을 쓰지 않으므로 host 규칙 없이 모든 요청을 받습니다.
# 접속 주소는 terraform output argocd_url 로 확인하세요.
#
# [destroy 순서] root 에서 module "argocd" 에 depends_on = [module.eks] 가 걸려 있어
# 이 Ingress 는 LB Controller 보다 반드시 먼저 파괴됩니다.
# 그래야 컨트롤러가 자기가 만든 ALB·타겟그룹·보안그룹을 회수할 수 있습니다.
# ####################################################################################################
resource "kubernetes_ingress_v1" "argocd" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name        = "argocd-server"
    namespace   = local.namespace
    annotations = local.ingress_annotations
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # ALB 가 실제로 붙어 hostname 이 나올 때까지 기다립니다.
  # 이게 없으면 output 이 빈 값으로 나옵니다.
  wait_for_load_balancer = true

  depends_on = [helm_release.argocd]
}
