variable "subnet_type" {
  description = "Subnet Type"
  type        = list(string)
  default     = []
}

variable "cidr_header" {
  description = "Network CIDR"
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owner Name"
  type        = string
  default     = ""
}

variable "env_type" {
  description = "Environment"
  type        = string
  default     = ""
}
# -------------------------------------------
# VPC 속성 정의
variable "vpc_options" {
  description = "VPC 상세 설정 옵션"
  type = object({
    instance_tenancy                     = optional(string, "default")
    enable_dns_support                   = optional(bool, true)
    enable_dns_hostnames                 = optional(bool, true)
    assign_generated_ipv6_cidr_block     = optional(bool, false)
    enable_network_address_usage_metrics = optional(bool, false)
  })

  default = {
    instance_tenancy                     = "default"
    enable_dns_support                   = true
    enable_dns_hostnames                 = true
    assign_generated_ipv6_cidr_block     = false
    enable_network_address_usage_metrics = false
  }
}



variable "create_nat_gateway" {
  description = "NAT Gateway의 생성 여부(true-생성 / false-미생성)"
  type        = bool
  default     = true
}

variable "key_pair" {
  description = "SSH Key"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain Name"
  type        = string
  default     = ""
}

variable "ami_type" {
  description = "AMI"
  type        = string
  default     = ""
}
# ################################################################################
# ArgoCD
# ================================================================================
variable "argocd_repo_url" {
  description = "ArgoCD 가 동기화할 Git 저장소 주소 (비우면 Application 을 만들지 않음)"
  type        = string
  default     = ""
}

variable "argocd_target_revision" {
  description = "동기화할 브랜치/태그"
  type        = string
  default     = "main"
}

variable "argocd_path" {
  description = "저장소 내 매니페스트 경로"
  type        = string
  default     = "k8s/app"
}

variable "argocd_create_ingress" {
  description = "ArgoCD UI 용 ALB Ingress 생성 여부"
  type        = bool
  default     = true
}

variable "argocd_certificate_arn" {
  description = "ArgoCD UI HTTPS 용 ACM 인증서 ARN (비우면 HTTP 80 만)"
  type        = string
  default     = ""
}

# ################################################################################
# compute (범용 EC2)
# ================================================================================
variable "ec2_instance_count" {
  description = "생성할 EC2 인스턴스 개수. 0 이면 만들지 않습니다"
  type        = number
  default     = 0
}

variable "ec2_instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "ec2_associate_public_ip" {
  description = "EC2 에 퍼블릭 IP 자동 할당 여부"
  type        = bool
  default     = false
}

# ################################################################################
# database (RDS)
# ================================================================================
variable "create_rds" {
  description = <<-EOT
    RDS Multi-AZ DB 클러스터 생성 여부.
    [비용 주의] sa-east-1 최소 사양이 db.m5d.large 이고 인스턴스를 3대 띄웁니다.
    필요할 때만 true 로 바꾸세요.
  EOT
  type        = bool
  default     = false
}

variable "db_cluster_instance_class" {
  description = "Multi-AZ DB 클러스터 인스턴스 클래스 (리전·엔진 버전별 지원 목록이 다름)"
  type        = string
  default     = "db.m5d.large"
}

# ################################################################################
# store (범용 비공개 S3)
# ================================================================================
variable "store_bucket_name" {
  description = "범용 스토리지 버킷 이름 (tag_header 뒤에 붙습니다)"
  type        = string
  default     = "store"
}

variable "store_lifecycle_rules" {
  description = "객체 수명 주기 규칙. 비우면 규칙을 만들지 않습니다"
  type = list(object({
    id                                 = string
    prefix                             = optional(string, "")
    enabled                            = optional(bool, true)
    transition_days                    = optional(number)
    transition_storage_class           = optional(string, "STANDARD_IA")
    expiration_days                    = optional(number)
    noncurrent_version_expiration_days = optional(number)
    abort_incomplete_multipart_days    = optional(number, 7)
  }))
  default = []
}

# ################################################################################
# 보안
# ================================================================================
variable "ssh_allowed_cidrs" {
  description = <<-EOT
    SSH(22) 접속을 허용할 CIDR 목록. 비우면 SSH 규칙을 만들지 않습니다.
    예전에는 0.0.0.0/0 으로 전 세계에 열려 있었습니다.
    필요할 때만 본인 공인 IP 를 지정하세요. 예: ["203.0.113.4/32"]
    (확인: curl -s https://checkip.amazonaws.com)
  EOT
  type        = list(string)
  default     = []
}

# ################################################################################
# CI/CD (CodePipeline + CodeBuild + CodeDeploy -> EC2)
# --------------------------------------------------------------------------------
# [주의] CodeDeploy 는 EKS 를 지원하지 않습니다 (EC2/온프레미스, Lambda, ECS 만).
#        그래서 이 파이프라인은 EC2 로 배포합니다.
#        EKS 배포는 기존대로 ArgoCD 가 담당하며 서로 독립입니다.
#
# 켜려면 terraform.tfvars 에서
#   create_cicd        = true
#   ec2_instance_count = 2      <- 배포 대상이 될 EC2. 0 이면 배포할 곳이 없습니다
#   ec2_associate_public_ip = true
# ################################################################################
variable "create_cicd" {
  description = "CodePipeline / CodeBuild / CodeDeploy 생성 여부"
  type        = bool
  default     = false
}

variable "cicd_github_repository" {
  description = "파이프라인이 감시할 GitHub 저장소 (소유자/저장소)"
  type        = string
  default     = ""
}

variable "cicd_github_branch" {
  description = "감시할 브랜치"
  type        = string
  default     = "main"
}

variable "cicd_codestar_connection_arn" {
  description = <<-EOT
    이미 승인된 CodeStar Connection ARN. 비우면 새로 만듭니다.
    새로 만든 연결은 PENDING 상태이므로 콘솔에서 한 번 승인해야 합니다.
    (AWS 가 요구하는 OAuth 절차라 Terraform 으로 자동화할 수 없습니다)
  EOT
  type        = string
  default     = ""
}
