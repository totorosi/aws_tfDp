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

# # EC2 Instance 속성
# variable "ec2_options" {
#   description           = "EC2 Instance에 필요한 속성값"
#   type = object({
#     count                                 = optional(number, "default")
#     ami_id                                = optional(string, "")
#     instance_type                         = optional(string, "t3.micro"
#     subnet_id                             = optional(string, "")
#     ssociate_public_ip_address            = optional(bool, false)
#     volume_size                           = optional(number, 10)
#     volume_type                           = optional(string, "gp3"
#     delete_on_termination                 = optional(bool, true) # 인스턴스 삭제 시 함께 삭제
#     key_name                              = optional(string, "")
#     vpc_security_group_ids                = optional(list(string), []) 
#   })

#   default = {
#     count                                 = 0
#     ami_id                                = ""
#     instance_type                         = ""
#     subnet_id                             = ""
#     ssociate_public_ip_address            = false
#     volume_size                           = 10
#     volume_type                           = "gp3"
#     delete_on_termination                 = true # 인스턴스 삭제 시 함께 삭제
#     key_name                              = ""
#     vpc_security_group_ids                = []
#   }
# }


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
