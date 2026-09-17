locals {
  tag_header = var.tag_header
  namespace  = var.namespace

  # host 를 지정하면 LB Controller 가 그 이름과 맞는 ACM 인증서를 자동으로 찾습니다.
  # 따라서 certificate_arn 을 적지 않아도 HTTPS 가 붙습니다.
  # (ARN 에는 계정 ID 가 들어가므로 공개 저장소에는 적지 않는 편이 낫습니다)
  enable_https = var.certificate_arn != "" || var.ingress_host != ""

  # Ingress 를 만들고, 호스트 이름과 호스팅 영역이 모두 주어졌을 때만 DNS 레코드를 만듭니다.
  create_dns_record = var.create_ingress && var.ingress_host != "" && var.route53_zone_name != ""

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
    } : {},
    # HTTPS 가 켜지면 HTTP 요청을 HTTPS 로 넘깁니다.
    local.enable_https ? {
      "alb.ingress.kubernetes.io/ssl-redirect" = "443"
    } : {}
  )
}
