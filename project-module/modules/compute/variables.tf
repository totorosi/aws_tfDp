variable "ec2_options" {
  description           = "EC2 Instance에 필요한 속성값"
  type = object({
    count                                 = number
    ami_id                                = string
    instance_type                         = string
    subnet_id                             = string
    ssociate_public_ip_address            = bool
    volume_size                           = number
    volume_type                           = string
    delete_on_termination                 = bool # 인스턴스 삭제 시 함께 삭제
    key_name                              = string
    vpc_security_group_ids                = list(string)
  })

  default = {
    count                                 = 0
    ami_id                                = ""
    instance_type                         = ""
    subnet_id                             = ""
    ssociate_public_ip_address            = false
    volume_size                           = 10
    volume_type                           = "gp3"
    delete_on_termination                 = true # 인스턴스 삭제 시 함께 삭제
    key_name                              = ""
    vpc_security_group_ids                = []
  }
}