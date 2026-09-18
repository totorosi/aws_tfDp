variable "vpc_cidr_block" {
  description = "VPC CIDR"
  type        = string
  default     = ""
}

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

variable "subnet_map" {
  description = "서브넷 이름 -> {type, az, cidr, rt} 맵"
  type        = map(map(string))
  default     = {}
}

variable "subnet_type" {
  description = "서브넷 종류 목록 (public, private, cluster). NACL 을 종류별로 만듭니다"
  type        = list(string)
  default     = []
}

variable "route_map" {
  description = "라우팅 테이블 생성을 위한 맵"
  type        = map(map(string))
  default     = {}
}

variable "azs" {
  description = "가용 영역 목록"
  type        = list(string)
  default     = []
}

variable "create_nat_gateway" {
  description = "NAT Gateway 생성 여부 (true-NAT Gateway / false-NAT Instance)"
  type        = bool
  default     = true
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

# -------------------------------------------
# NAT Instance 전용 (create_nat_gateway = false 일 때만 사용)
variable "ami_id" {
  description = "NAT Instance 용 AMI ID"
  type        = string
  default     = ""
}

variable "ami_type" {
  description = "NAT Instance 용 OS 구분 (ubuntu2404 면 우분투 user-data 를 씁니다)"
  type        = string
  default     = ""
}

variable "key_pair" {
  description = "NAT Instance 용 SSH 키 페어 이름. 비우면 키 없이 생성합니다"
  type        = string
  default     = ""
}
