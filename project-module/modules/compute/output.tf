output "instance_ids" {
  description = "생성된 인스턴스 ID 목록"
  value       = aws_instance.this[*].id
}

output "instances" {
  description = "Name 태그 -> 주요 정보 맵"
  value = {
    for i in aws_instance.this : i.tags["Name"] => {
      id         = i.id
      private_ip = i.private_ip
      public_ip  = i.public_ip
      subnet_id  = i.subnet_id
      az         = i.availability_zone
    }
  }
}

output "ssh_commands" {
  description = "퍼블릭 IP 가 있는 인스턴스의 SSH 접속 명령"
  value = [
    for i in aws_instance.this :
    "ssh -i ~/.ssh/${i.key_name}.pem ubuntu@${i.public_ip}"
    if i.public_ip != "" && i.key_name != ""
  ]
}
