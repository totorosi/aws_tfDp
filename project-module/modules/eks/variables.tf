variable "key_pair" {
  description = "SSH Key"
  type        = string
  default     = ""
}

variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "region" {
  description = "REGION"
  type        = string
  default     = ""
}

variable "node_instance_type" {
  description = "node instance type"
  type        = string
  default     = ""
}

variable "eks_admin_principal_arns" {
  description = "EKS 클러스터에 admin 권한을 추가로 부여할 IAM 사용자/역할 ARN 목록 (클러스터 생성자 본인은 제외)"
  type        = list(string)
  default     = []
}

variable "k8s_version" {
  description = "EKS 컨트롤 플레인 및 워커 노드 AMI의 쿠버네티스 버전"
  type        = string
  default     = "1.35"
}

# --------------------------------------------------------------------------------
# 아래 두 값은 root 모듈에서 module.network 의 출력값을 그대로 넘겨받습니다.
# data 소스로 조회하면 plan 시점에 VPC 가 아직 없어 실패하므로 변수로 받습니다.
variable "vpc_id" {
  description = "EKS 를 배치할 VPC ID (module.network 출력값)"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "EKS 클러스터/노드가 사용할 서브넷 ID 목록 (Type=cluster 서브넷)"
  type        = list(string)
}
