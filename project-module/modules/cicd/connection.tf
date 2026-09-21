# ####################################################################################################
# GitHub 연결 (CodeStar Connection)
# ====================================================================================================
# [반드시 알아야 할 것]
# Terraform 이 이 리소스를 만들면 상태가 PENDING 입니다. 그대로는 파이프라인이 돌지 않습니다.
# AWS 콘솔에서 사람이 GitHub 로 로그인해 한 번 승인해야 AVAILABLE 로 바뀝니다.
#
# 이건 OAuth 핸드셰이크라 Terraform 으로 자동화할 수 없습니다. AWS 의 제약입니다.
#
# 승인 위치:
#   콘솔 > CodePipeline > Settings > Connections > 해당 연결 > "Update pending connection"
#
# 확인 명령:
#   aws codestar-connections list-connections --region <리전> \
#     --query "Connections[].[ConnectionName,ConnectionStatus]" --output table
# ####################################################################################################
resource "aws_codestarconnections_connection" "github" {
  count = local.create_connection ? 1 : 0

  name          = substr("${local.name}-github", 0, 32) # 이름은 32자 제한
  provider_type = "GitHub"

  tags = { Name = "${local.name}-github" }
}
