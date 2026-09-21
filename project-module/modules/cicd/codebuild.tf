# ####################################################################################################
# CodeBuild: 배포 번들 만들기
# ====================================================================================================
# 지금은 nginx 공개 이미지를 쓰고 애플리케이션 소스가 없으므로,
# 이 단계는 "컴파일"이 아니라 "CodeDeploy 가 먹을 배포 번들 조립"입니다.
#   app/appspec.yml, app/scripts/, app/html/  ->  아티팩트 zip
# 나중에 실제 소스가 생기면 buildspec.yml 의 build 단계만 채우면 됩니다.
# ####################################################################################################
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${local.name}-build"
  retention_in_days = 7

  tags = { Name = "${local.name}-build-logs" }
}

resource "aws_codebuild_project" "this" {
  name          = "${local.name}-build"
  description   = "Build deployment bundle for ${local.name}"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "LINUX_CONTAINER"
    compute_type    = var.codebuild_compute_type
    image           = var.codebuild_image
    privileged_mode = false
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_path
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.codebuild.name
    }
  }

  tags = { Name = "${local.name}-build" }
}
