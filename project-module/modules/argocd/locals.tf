locals {
  namespace = var.namespace

  # 도메인을 쓰지 않으므로 인증서 ARN 을 직접 지정했을 때만 HTTPS 를 엽니다.
  enable_https = var.certificate_arn != ""

  listen_ports = local.enable_https ? jsonencode([{ HTTP = 80 }, { HTTPS = 443 }]) : jsonencode([{ HTTP = 80 }])

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
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
    } : {}
  )
}
