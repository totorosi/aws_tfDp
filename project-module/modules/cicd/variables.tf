# ####################################################################################################
# cicd 모듈: CodePipeline + CodeBuild + CodeDeploy 로 EC2 에 배포하는 파이프라인
# ----------------------------------------------------------------------------------------------------
# [왜 EKS 가 아니라 EC2 인가]
# CodeDeploy 가 지원하는 배포 대상은 EC2/온프레미스, Lambda, ECS 셋뿐입니다.
# EKS 는 지원하지 않습니다. 그래서 이 파이프라인의 대상은 EC2 이고,
# EKS 쪽 배포는 기존대로 ArgoCD 가 담당합니다. 둘은 서로 독립입니다.
# ####################################################################################################
variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "region" {
  description = "REGION"
  type        = string
}

# ####################################################################################################
# 소스 (GitHub)
# ####################################################################################################
variable "github_repository" {
  description = <<-EOT
    파이프라인이 감시할 GitHub 저장소. "소유자/저장소" 형식입니다.
    예: "totorosi/aws_tfDp"
  EOT
  type        = string
}

variable "github_branch" {
  description = "감시할 브랜치"
  type        = string
  default     = "main"
}

variable "codestar_connection_arn" {
  description = <<-EOT
    이미 승인된 CodeStar Connection 의 ARN.
    비워 두면 이 모듈이 새로 만듭니다.

    [중요] 새로 만든 연결은 PENDING 상태로 생성됩니다.
    AWS 콘솔에서 사람이 한 번 GitHub 로그인으로 승인해야 AVAILABLE 이 됩니다.
    이건 AWS 가 요구하는 절차라 Terraform 으로 자동화할 수 없습니다.
  EOT
  type        = string
  default     = ""
}

# ####################################################################################################
# 빌드
# ####################################################################################################
variable "buildspec_path" {
  description = "저장소 안의 buildspec 파일 경로"
  type        = string
  default     = "app/buildspec.yml"
}

variable "codebuild_image" {
  description = "CodeBuild 가 쓸 컨테이너 이미지"
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}

variable "codebuild_compute_type" {
  description = "CodeBuild 인스턴스 크기"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

# ####################################################################################################
# 배포 (CodeDeploy -> EC2)
# ####################################################################################################
variable "deploy_tag_key" {
  description = <<-EOT
    CodeDeploy 배포 그룹이 대상 EC2 를 찾을 때 쓰는 태그 키.
    compute 모듈에 같은 태그를 붙여야 배포 대상이 됩니다.
  EOT
  type        = string
  default     = "CodeDeploy"
}

variable "deploy_tag_value" {
  description = "위 태그의 값. 비우면 tag_header + 'nginx' 를 씁니다"
  type        = string
  default     = ""
}

variable "deployment_config_name" {
  description = <<-EOT
    배포 방식.
      CodeDeployDefault.OneAtATime  : 한 대씩. 실패해도 나머지는 살아 있음 (기본값)
      CodeDeployDefault.HalfAtATime : 절반씩
      CodeDeployDefault.AllAtOnce   : 전부 동시에. 빠르지만 실패하면 전체 중단
  EOT
  type        = string
  default     = "CodeDeployDefault.OneAtATime"
}

variable "artifact_force_destroy" {
  description = "아티팩트가 남아 있어도 버킷을 삭제할지 여부 (destroy 를 한 번에 끝내려면 true)"
  type        = bool
  default     = true
}
