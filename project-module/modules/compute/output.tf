output "instance_ids" {
  description = "생성된 인스턴스 ID 목록"
  value       = aws_instance.this[*].id
}

output "private_ips" {
  description = "인스턴스 프라이빗 IP 목록"
  value       = aws_instance.this[*].private_ip
}

output "public_ips" {
  description = "인스턴스 퍼블릭 IP 목록 (associate_public_ip_address 가 false 면 빈 값)"
  value       = aws_instance.this[*].public_ip
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
