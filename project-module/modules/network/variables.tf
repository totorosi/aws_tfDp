variable "vpc_cidr_block" {
  description = "Network CIDR"
  type        = string
  default     = ""
}

variable "subnet_map" {
  description = "Subnet Information"
  type        = map(map(string))
  default     = {}
}

variable "subnet_type" {
  description = "Public, Private, Cluster"
  type        = list(string)
  default     = []
}

variable "azs" {
  description = "Network CIDR"
  type        = list(string)
  default     = []
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

variable "ssh_key" {
  description = "SSH Key"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain Name"
  type        = string
  default     = ""
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "ami_id" {
  description = "NAT Instance를 위한 AMI Image ID"
  type        = string
  default     = ""
}

variable "ami_type" {
  description = "NAT Instance를 위한 OS 구분"
  type        = string
  default     = ""
}

variable "inbound_ports" {
  type    = list(map(number))
  default = []
}

variable "region" {
  description = "REGION"
  type        = string
  default     = ""
}

variable "key_pair" {
  description = "SSH Key Pair"
  type        = string
  default     = ""
}

variable "route_map" {
  description = "라우팅 테이블 생성을 위한 변수 설정"
  type        = map(map(string))
  default     = {}
}

