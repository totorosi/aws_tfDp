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
