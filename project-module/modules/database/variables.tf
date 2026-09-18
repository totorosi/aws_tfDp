variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = ""
}

variable "region" {
  description = "REGION"
  type        = string
  default     = ""
}

variable "mysql_sg_id" {
  description = "MySQL Security Group"
  type        = string
  default     = ""
}



variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "RDS 마스터 사용자 이름"
  type        = string
  default     = "dbadmin"
}

variable "db_cluster_instance_class" {
  description = <<-EOT
    Multi-AZ DB 클러스터의 인스턴스 클래스.
    리전과 엔진 버전에 따라 지원 목록이 다르므로 반드시 확인 후 지정하세요.
    sa-east-1 / MySQL 8.0.46 최소 사양은 db.m5d.large 입니다.
    (db.c6gd.medium 은 지원하지 않습니다)
  EOT
  type        = string
  default     = "db.m5d.large"
}

variable "db_subnet_ids" {
  description = <<-EOT
    RDS · RDS Proxy · 순환 Lambda 를 배치할 서브넷 ID 목록 (private 서브넷).

    [수정] 예전에는 이 모듈이 data "aws_subnets" 로 직접 조회했습니다.
    eks / compute 모듈은 이미 root 에서 값으로 전달받는 방식으로 바꿨는데
    database 만 옛 방식이라 일관성이 없었습니다.
    값으로 받으면 network -> database 의존 관계가 그래프에 명시되어
    Terraform 이 순서를 스스로 보장합니다.
  EOT
  type        = list(string)
}
