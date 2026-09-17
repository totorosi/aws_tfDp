# ####################################################################################################
# ArgoCD UI 용 Route53 레코드
# ====================================================================================================
# ALB 는 LB Controller 가 만들지만 이 Ingress 는 Terraform 이 소유하므로,
# status 에서 ALB 주소를 직접 읽을 수 있습니다.
#
# alias 레코드 대신 CNAME 을 쓰는 이유:
#   alias 는 ALB 의 zone_id 가 필요해서 data "aws_lb" 조회가 들어가는데,
#   그 조회가 ALB 생성(2~3분)보다 먼저 돌면 "no matching LB found" 로 깨집니다.
#   CNAME 은 hostname 만 있으면 되므로 그 경합이 없습니다.
#   (zone apex 에는 CNAME 을 못 쓰지만, 여기는 서브도메인이라 문제없습니다)
# ####################################################################################################
data "aws_route53_zone" "this" {
  count = local.create_dns_record ? 1 : 0

  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_route53_record" "argocd" {
  count = local.create_dns_record ? 1 : 0

  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.ingress_host
  type    = "CNAME"
  ttl     = 60

  records = [
    kubernetes_ingress_v1.argocd[0].status[0].load_balancer[0].ingress[0].hostname
  ]
}
