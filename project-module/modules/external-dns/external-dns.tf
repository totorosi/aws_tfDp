# ####################################################################################################
# external-dns 설치
# ====================================================================================================
# Ingress 와 Service 를 감시하다가, host 이름에 맞는 Route53 레코드를 만들고 갱신합니다.
# ArgoCD 가 관리하는 Ingress 처럼 Terraform 이 소유하지 않는 리소스도 대상이 됩니다.
# ####################################################################################################
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.chart_version

  namespace = local.namespace

  wait    = true
  timeout = 600

  values = [yamlencode({
    provider = {
      name = "aws"
    }

    # 관리 대상 도메인. 비워두면 계정의 모든 영역을 건드리므로 반드시 지정합니다.
    domainFilters = var.domain_filters

    # upsert-only: 레코드를 만들고 고치기만 하고 지우지는 않습니다.
    policy = var.policy

    # 감시할 리소스 종류
    sources = ["ingress", "service"]

    # 이 external-dns 가 만든 레코드임을 표시하는 TXT 레코드의 식별자.
    # 여러 클러스터가 같은 호스팅 영역을 공유할 때 서로의 레코드를 건드리지 않게 해줍니다.
    txtOwnerId = var.cluster_name

    serviceAccount = {
      create = true
      name   = local.service_account
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
      }
    }
  })]

  depends_on = [aws_iam_role_policy_attachment.external_dns]
}
