# ####################################################################################################
# GitHub 연결 (CodeStar Connection)
# ====================================================================================================
# [이 코드가 왜 remote-backend 에 있나]
# 이 연결은 콘솔에서 사람이 GitHub 로그인으로 한 번 승인해야 쓸 수 있습니다.
# OAuth 핸드셰이크라 Terraform 으로 자동화할 수 없습니다.
#
# 그런데 project-module/projects 에 두면 terraform destroy 할 때 함께 지워지고,
# 다시 apply 할 때마다 사람이 콘솔에 들어가 또 승인해야 합니다.
#
# remote-backend 는 destroy 대상이 아니므로, 한 번 승인하면 계속 씁니다.
# OIDC 공급자(github-oidc.tf)를 여기에 둔 것과 같은 이유입니다.
#
# [projects 는 이 연결을 어떻게 찾나]
# ARN 을 주고받지 않고 "이름으로 조회"합니다.
#   data "aws_codestarconnections_connection" { name = ... }
# ARN 에는 계정 ID 가 들어가는데 이 저장소는 공개라 코드에 남기지 않기 위해서입니다.
#
# [승인 방법]
#   1) 콘솔 > CodePipeline > 설정 > 연결
#   2) 해당 연결 선택 > "보류 중인 연결 업데이트" > GitHub 로그인 > 저장소 승인
#   3) 확인:
#      aws codestar-connections list-connections --region <리전> \
#        --query "Connections[].[ConnectionName,ConnectionStatus]" --output table
# ####################################################################################################
resource "aws_codestarconnections_connection" "github" {
  count = var.codestar_connection_name != "" ? 1 : 0

  name          = var.codestar_connection_name # 32자 제한
  provider_type = "GitHub"

  # [중요] 이름을 바꾸면 연결이 새로 만들어집니다.
  # 새 연결은 PENDING 상태라 사람이 콘솔에서 다시 승인해야 합니다.
  # 승인된 연결을 유지하려면 이 값을 바꾸지 마세요.
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = var.codestar_connection_name }
}
