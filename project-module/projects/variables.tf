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