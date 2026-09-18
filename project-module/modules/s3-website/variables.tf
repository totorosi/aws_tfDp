variable "tag_header" {
  description = "Resource Name or Tag:Name Header"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "객체가 남아 있어도 버킷을 삭제할지 여부 (실습 환경은 true 가 편합니다)"
  type        = bool
  default     = true
}
