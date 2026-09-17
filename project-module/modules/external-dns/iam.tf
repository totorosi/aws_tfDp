# ####################################################################################################
# external-dns 용 IRSA (IAM Roles for Service Accounts)
# ====================================================================================================
# 파드에 액세스 키를 넣지 않고, 쿠버네티스 ServiceAccount 토큰으로
# IAM 역할을 위임받게 하는 방식입니다.
# ####################################################################################################
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # 지정한 네임스페이스의 그 ServiceAccount 만 이 역할을 쓸 수 있게 제한합니다.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${local.namespace}:${local.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${local.tag_header}external-dns-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = { Name = "${local.tag_header}external-dns-role" }
}

# Route53 최소 권한:
#   - 레코드 변경은 호스팅 영역 단위
#   - 목록 조회는 리소스 단위 제한이 불가해 "*" 를 씁니다 (AWS 사양)
data "aws_iam_policy_document" "route53" {
  statement {
    sid       = "ChangeRecordSets"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:aws:route53:::hostedzone/*"]
  }

  statement {
    sid    = "ListZonesAndRecords"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "${local.tag_header}external-dns-policy"
  description = "external-dns 가 Route53 레코드를 관리하기 위한 정책"
  policy      = data.aws_iam_policy_document.route53.json

  tags = { Name = "${local.tag_header}external-dns-policy" }
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}
