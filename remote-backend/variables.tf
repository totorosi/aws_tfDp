# ####################################################################################################
# [보안] 아래 값들은 계정 식별 정보를 포함하므로 코드에 직접 적지 않습니다.
#        terraform.tfvars.example 을 terraform.tfvars 로 복사해서 채우세요.
#        (terraform.tfvars 는 .gitignore 에 등록되어 git 에 올라가지 않습니다)
# ====================================================================================================
variable "bucket_name" {
  description = "상태 파일(tfstate)을 저장할 S3 버킷 이름 (전 세계에서 유일해야 함)"
  type        = string
}

variable "lock_table_name" {
  description = "상태 잠금(state lock)에 사용할 DynamoDB 테이블 이름"
  type        = string
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "billing_mode" {
  description = "DynamoDB 요금 방식 (PAY_PER_REQUEST 또는 PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

# ####################################################################################################
# GitHub Actions OIDC
# ####################################################################################################
variable "github_repository" {
  description = <<-EOT
    이 역할을 쓸 GitHub 저장소. "소유자/저장소" 형식입니다.
    예: "totorosi/aws_tfDp"
    여기 적힌 저장소의 워크플로만 이 역할을 가져갈 수 있습니다.
  EOT
  type        = string
}

variable "github_branches" {
  description = "이 역할을 쓸 수 있는 브랜치 목록"
  type        = list(string)
  default     = ["main"]
}

variable "github_allow_pull_request" {
  description = <<-EOT
    PR 워크플로도 이 역할을 쓰게 할지 여부.
    terraform.yml 은 PR 에서 plan 만 돌리므로 true 가 필요합니다.
    false 로 두면 PR 의 plan 단계가 인증에 실패합니다.
  EOT
  type        = bool
  default     = true
}

variable "create_github_oidc_provider" {
  description = <<-EOT
    GitHub OIDC 공급자를 이 코드가 만들지 여부.

    [주의] 공급자는 AWS 계정당 하나뿐인 공용 리소스입니다.
    이 계정을 여럿이 함께 쓴다면 다른 사람이 이미 만들었을 수 있고,
    그때 true 로 두면 EntityAlreadyExists 로 apply 가 실패합니다.
    또 내가 만든 것을 지우면 남의 CI 도 함께 깨집니다.

    확인:  aws iam list-open-id-connect-providers | grep githubusercontent
    있으면 false 로 두세요. 역할은 어느 쪽이든 정상 동작합니다.
  EOT
  type        = bool
  default     = true
}

variable "github_actions_policy_arns" {
  description = <<-EOT
    GitHub Actions 역할에 붙일 정책 목록.

    기본값은 AdministratorAccess 입니다. 지금 CI 가 쓰는 IAM 사용자가
    (BIPA17-MSP-Students 그룹을 통해) 가진 권한과 같습니다.
    즉 이번 전환으로 권한이 넓어지지도 좁아지지도 않습니다.
    OIDC 는 "자격 증명 보관 문제"를 고치는 것이지 "권한 범위 문제"를 고치지 않습니다.

    권한을 좁히려면 이 목록을 필요한 정책으로 교체하세요.
  EOT
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
