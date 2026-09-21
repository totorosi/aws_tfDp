# ####################################################################################################
# CodeDeploy: EC2 에 배포
# ====================================================================================================
# 배포 그룹은 "태그로" 대상을 찾습니다. compute 모듈이 만든 EC2 에
# 같은 태그가 붙어 있어야 배포 대상이 됩니다. (root 의 module "compute" 의 extra_tags)
#
# 태그가 안 맞으면 배포가 "성공"으로 끝나면서 아무 데도 배포되지 않습니다.
# 에러가 안 나서 놓치기 쉬우니, 배포 후 대상 수를 꼭 확인하세요.
# ####################################################################################################
resource "aws_codedeploy_app" "this" {
  name             = "${local.name}-app"
  compute_platform = "Server" # EC2/온프레미스

  tags = { Name = "${local.name}-app" }
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name              = aws_codedeploy_app.this.name
  deployment_group_name = "${local.name}-dg"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = var.deployment_config_name

  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
  }

  # 이 태그가 붙은 EC2 가 배포 대상입니다.
  ec2_tag_set {
    ec2_tag_filter {
      type  = "KEY_AND_VALUE"
      key   = var.deploy_tag_key
      value = local.deploy_tag_value
    }
  }

  # 배포가 실패하면 직전 성공 버전으로 자동 되돌립니다.
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  tags = { Name = "${local.name}-dg" }
}
