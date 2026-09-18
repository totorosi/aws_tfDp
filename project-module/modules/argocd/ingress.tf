# ####################################################################################################
# ArgoCD UI 접속용 ALB Ingress
# ====================================================================================================
# 실제 ALB 는 이 Ingress 를 보고 AWS Load Balancer Controller 가 만듭니다.
# Terraform 이 aws_lb 를 직접 만들지 않습니다.
# ####################################################################################################
resource "kubernetes_ingress_v1" "argocd" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name      = "argocd-server"
    namespace = local.namespace

    annotations = merge(local.ingress_annotations, {
      # 이 Ingress 를 실제로 처리하는 LB Controller 릴리스를 기록합니다.
      # 값을 남기는 동시에 Terraform 에 의존 관계를 알려주는 역할을 합니다.
      # destroy 는 역순이므로 Ingress 가 컨트롤러보다 먼저 파괴되고,
      # 그때 컨트롤러가 ALB·타겟그룹·보안그룹까지 스스로 회수합니다.
      "lab.internal/lb-controller-release" = var.lb_controller_release_id
    })
  }

  spec {
    ingress_class_name = "alb"

    rule {
      # 도메인을 지정하면 그 호스트로만, 비우면 모든 요청을 받습니다.
      host = var.ingress_host != "" ? var.ingress_host : null

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

  depends_on = [helm_release.argocd]
}
