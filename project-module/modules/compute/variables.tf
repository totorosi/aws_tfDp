# ################################################################################
# compute 모듈: 범용 EC2 인스턴스
# --------------------------------------------------------------------------------
# 서브넷과 보안 그룹은 root 에서 network 모듈의 출력값을 전달받습니다.
# data 소스로 조회하면 plan 시점에 아직 없어서 실패하므로 값으로 넘겨받습니다.
# ================================================================================
variable "instance_count" {
  description = "생성할 인스턴스 개수. 0 이면 아무것도 만들지 않습니다"
  type        = number
  default     = 0
}

variable "subnet_ids" {
  description = <<-EOT
    인스턴스를 배치할 서브넷 ID 목록.
    instance_count 가 서브넷 수보다 많으면 순환하며 배치합니다.
  EOT
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "인스턴스에 적용할 보안 그룹 ID 목록"
  type        = list(string)
  default     = []
}

variable "ami_id" {
  description = "인스턴스 AMI ID"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "key_pair" {
  description = "SSH 키 페어 이름. 비우면 키 없이 생성합니다"
  type        = string
  default     = ""
}

variable "associate_public_ip_address" {
  description = "퍼블릭 IP 자동 할당 여부"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "부팅 시 실행할 스크립트. 비우면 실행하지 않습니다"
  type        = string
  default     = ""
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Name 태그 접미사. 여러 용도로 쓸 때 구분합니다 (예: web, batch)"
  type        = string
  default     = "instance"
}

# -------------------------------------------
# 루트 볼륨 옵션
variable "root_volume" {
  description = "루트 EBS 볼륨 설정"
  type = object({
    size                  = optional(number, 10)
    type                  = optional(string, "gp3")
    delete_on_termination = optional(bool, true) # 인스턴스 삭제 시 함께 삭제
    encrypted             = optional(bool, true)
  })
  default = {}
}

variable "enable_detailed_monitoring" {
  description = "상세 모니터링(1분 간격) 활성화 여부. 켜면 추가 비용이 발생합니다"
  type        = bool
  default     = false
}

# -------------------------------------------
# CodeDeploy 등 AWS 서비스와 연동할 때 필요한 값
variable "iam_instance_profile" {
  description = <<-EOT
    인스턴스에 붙일 IAM 인스턴스 프로파일 이름. 비우면 붙이지 않습니다.
    CodeDeploy 에이전트는 아티팩트를 S3 에서 받아가야 하므로 이 값이 필요합니다.
  EOT
  type        = string
  default     = ""
}

variable "extra_tags" {
  description = <<-EOT
    Name 외에 추가로 붙일 태그.
    CodeDeploy 배포 그룹은 EC2 태그로 대상을 찾으므로 여기에 식별 태그를 넣습니다.
    예: { CodeDeploy = "std15-ex-nginx" }
  EOT
  type        = map(string)
  default     = {}
}
