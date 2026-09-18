# ####################################################################################################
# GitHub Actions 용 OIDC 인증
# ====================================================================================================
# [이 코드가 왜 remote-backend 에 있나]
# project-module/projects 에 두면 terraform destroy 할 때 이 역할도 함께 지워집니다.
# 그러면 CI 가 다시는 AWS 에 붙지 못합니다. (destroy 를 CI 로 돌렸다면 자기 발등 찍기)
# remote-backend 는 부트스트랩 코드라 destroy 대상이 아니므로 여기가 맞습니다.
#
# [OIDC 가 무엇을 고치나]
#   기존: IAM 액세스 키(AKIA...)를 GitHub Secret 에 보관
#         -> 만료 없음. 유출되면 지울 때까지 유효하고, 어디서든 쓸 수 있음
#   변경: GitHub 이 실행할 때마다 "나는 이 저장소의 이 워크플로다"라는 서명된 토큰 발급
#         -> AWS 가 확인하고 1시간짜리 임시 자격 증명 발급. 보관되는 비밀이 없음
#
# [고치지 못하는 것]
# OIDC 는 "자격 증명이 새는 문제"를 고칠 뿐 "권한이 넓은 문제"는 고치지 않습니다.
# 아래 역할은 현재 IAM 사용자와 같은 권한(AdministratorAccess)을 갖습니다.
# 지금 CI 가 쓰는 권한과 똑같으므로 이번 변경으로 권한이 넓어지지도 좁아지지도 않습니다.
# 권한을 좁히는 건 별개의 작업입니다.
# ####################################################################################################

data "aws_caller_identity" "current" {}

# ####################################################################################################
# 1. GitHub OIDC 공급자
# ----------------------------------------------------------------------------------------------------
# [주의] 이건 계정당 하나뿐인 공용 리소스입니다.
# 이 AWS 계정은 반 전체가 함께 쓰므로, 다른 사람이 이미 만들었을 수 있습니다.
# 그 경우 create_github_oidc_provider = false 로 두면 만들지 않고 기존 것을 참조합니다.
#
# 확인 방법:
#   aws iam list-open-id-connect-providers | grep githubusercontent
# ####################################################################################################
data "tls_certificate" "github" {
  count = var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS 는 이 공급자에 한해 자체 신뢰 저장소로 검증하므로 지문은 사실상 형식상 값입니다.
  # 그래도 손으로 적어 두면 언젠가 만료되므로 실시간으로 받아옵니다.
  thumbprint_list = [for c in data.tls_certificate.github[0].certificates : c.sha1_fingerprint]

  # [중요] 이 공급자는 계정당 하나뿐인 공용 리소스입니다.
  # 반 전체가 같은 계정을 쓰므로, 이걸 지우면 다른 사람의 CI 도 함께 깨집니다.
  # 실수로 destroy 되지 않도록 잠가 둡니다.
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = "github-actions-oidc" }
}

locals {
  # 공급자 ARN 은 계정당 하나이고 형식이 고정입니다.
  # 이 코드가 만들었든 다른 사람이 만들었든 값이 같으므로 직접 조립합니다.
  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  # 이 역할을 쓸 수 있는 GitHub 워크플로의 신원(subject) 목록.
  #   ref:refs/heads/<브랜치>  : 그 브랜치에서 돈 워크플로
  #   pull_request             : PR 로 돈 워크플로 (plan 전용)
  # 여기에 없는 저장소나 브랜치는 이 역할을 절대 가져갈 수 없습니다.
  github_subjects = [
    for s in concat(
      [for b in var.github_branches : "repo:${var.github_repository}:ref:refs/heads/${b}"],
      var.github_allow_pull_request ? ["repo:${var.github_repository}:pull_request"] : []
    ) : s
  ]
}

# ####################################################################################################
# 2. GitHub Actions 가 가져갈 IAM 역할
# ####################################################################################################
data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    # 토큰의 수신자가 STS 인지 확인합니다. 이게 없으면 다른 서비스용 토큰도 통과합니다.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # 어느 저장소·브랜치의 워크플로인지 제한합니다. 이게 이 설정의 핵심입니다.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subjects
    }
  }
}

resource "aws_iam_role" "github_actions" {
  # [중요] 계정을 여럿이 공유하므로 이름에 반드시 본인 접두사를 붙입니다.
  name        = "${var.tag_header}github-actions-role"
  description = "Assumed by GitHub Actions via OIDC for ${var.github_repository}"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json

  # 워크플로 한 번 도는 시간이면 충분합니다.
  max_session_duration = 3600

  tags = { Name = "${var.tag_header}github-actions-role" }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  for_each = toset(var.github_actions_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
