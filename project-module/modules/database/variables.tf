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
