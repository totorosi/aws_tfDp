locals {
  tag_header      = var.tag_header
  namespace       = var.namespace
  service_account = "external-dns"

  # IRSA 신뢰 정책 조건에 쓸 OIDC 발급자.
  # ARN 형식: arn:aws:iam::<계정>:oidc-provider/oidc.eks.<리전>.amazonaws.com/id/<ID>
  # 여기서 "oidc-provider/" 뒤쪽만 잘라냅니다. (정규식보다 split 이 읽기 쉽습니다)
  oidc_issuer = split("oidc-provider/", var.oidc_provider_arn)[1]
}
