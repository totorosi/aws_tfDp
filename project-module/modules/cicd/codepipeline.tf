# ####################################################################################################
# CodePipeline: 세 단계를 이어 붙임
# ====================================================================================================
#   Source : GitHub 의 지정 브랜치를 받아옴 (CodeStar Connection)
#   Build  : CodeBuild 가 배포 번들 조립
#   Deploy : CodeDeploy 가 EC2 에 배포
#
# main 에 push 하면 자동으로 돕니다. 연결이 AVAILABLE 이어야 동작합니다.
# ####################################################################################################
resource "aws_codepipeline" "this" {
  name          = "${local.name}-pipeline"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        ConnectionArn    = local.connection_arn
        FullRepositoryId = var.github_repository
        BranchName       = var.github_branch
        # true 면 변경을 감지해 자동 실행합니다.
        DetectChanges = true
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildBundle"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]
      output_artifacts = ["bundle"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployToEC2"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["bundle"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.this.name
        DeploymentGroupName = aws_codedeploy_deployment_group.this.deployment_group_name
      }
    }
  }

  tags = { Name = "${local.name}-pipeline" }

  depends_on = [aws_iam_role_policy.codepipeline]
}
