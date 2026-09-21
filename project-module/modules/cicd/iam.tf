# ####################################################################################################
# IAM 역할 4개
# ====================================================================================================
#   1. EC2 인스턴스        : CodeDeploy 에이전트가 S3 에서 아티팩트를 받아감
#   2. CodeDeploy 서비스   : EC2 를 찾고 배포를 지시
#   3. CodeBuild 서비스    : 소스를 받아 빌드하고 결과를 S3 에 올림
#   4. CodePipeline 서비스 : 단계들을 이어 붙이고 각 서비스를 호출
#
# 관리형 정책으로 때울 수 있는 곳은 관리형을 쓰고,
# S3 접근처럼 대상을 좁힐 수 있는 곳은 이 버킷만 허용합니다.
# ####################################################################################################

# ####################################################################################################
# 1. EC2 인스턴스 역할
# ####################################################################################################
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name}-deploy-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "${local.name}-deploy-ec2-role" }
}

# 에이전트가 배포 번들을 받아갈 수 있어야 합니다. 이 버킷으로만 한정합니다.
data "aws_iam_policy_document" "ec2_artifacts_read" {
  statement {
    sid       = "ReadDeployArtifacts"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }
}

resource "aws_iam_role_policy" "ec2_artifacts_read" {
  name   = "${local.name}-deploy-artifacts-read"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ec2_artifacts_read.json
}

# 에이전트 설치 스크립트를 S3(aws-codedeploy-<region>)에서 받아오고,
# SSM 으로 키 없이 접속할 수 있게 합니다.
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-deploy-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ####################################################################################################
# 2. CodeDeploy 서비스 역할
# ####################################################################################################
data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${local.name}-codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json
  tags               = { Name = "${local.name}-codedeploy-role" }
}

# EC2 조회 / 태그 조회 / Auto Scaling 연동에 필요한 AWS 관리형 정책입니다.
resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# ####################################################################################################
# 3. CodeBuild 서비스 역할
# ####################################################################################################
data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.name}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = { Name = "${local.name}-codebuild-role" }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.region}:*:log-group:/aws/codebuild/${local.name}*"]
  }

  statement {
    sid    = "Artifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${local.name}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

# ####################################################################################################
# 4. CodePipeline 서비스 역할
# ####################################################################################################
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${local.name}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = { Name = "${local.name}-codepipeline-role" }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid    = "Artifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }

  # Source 단계가 GitHub 연결을 쓰기 위한 권한입니다.
  statement {
    sid       = "UseGitHubConnection"
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [local.connection_arn]
  }

  statement {
    sid    = "StartBuild"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds",
    ]
    resources = [aws_codebuild_project.this.arn]
  }

  statement {
    sid    = "Deploy"
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
    ]
    resources = ["*"] # CodeDeploy 는 배포 설정 조회에 리소스 한정이 어렵습니다
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "${local.name}-codepipeline-policy"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}
