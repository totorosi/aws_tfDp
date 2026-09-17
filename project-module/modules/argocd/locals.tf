locals {
  tag_header = var.tag_header
  namespace  = var.namespace

  # 인증서가 지정되면 HTTPS(443) 리스너를 함께 엽니다.
  listen_ports = var.certificate_arn != "" ? jsonencode([{ HTTP = 80 }, { HTTPS = 443 }]) : jsonencode([{ HTTP = 80 }])

  ingress_annotations = merge(
    {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/listen-ports"     = local.listen_ports
      "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
      # ArgoCD 서버의 상태 확인 경로
      "alb.ingress.kubernetes.io/healthcheck-path"   = "/healthz"
      "alb.ingress.kubernetes.io/load-balancer-name" = "${var.tag_header}argocd"
    },
    var.certificate_arn != "" ? {
      "alb.ingress.kubernetes.io/certificate-arn" = var.certificate_arn
    } : {}
  )
}
