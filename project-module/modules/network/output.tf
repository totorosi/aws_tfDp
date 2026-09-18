output "network" {
  description = "VPC와 Subnet 리소스 전체 객체"
  value = {
    vpc     = aws_vpc.this
    subnets = aws_subnet.this
  }
}

output "mysql_sg" {
  value = aws_security_group.mysql_sg.id
}
output "ssh_sg" {
  description = "SSH 접속용 보안 그룹 ID"
  value       = aws_security_group.ssh_sg.id
}

output "external_alb_sg" {
  description = "외부 HTTP/HTTPS 허용 보안 그룹 ID"
  value       = aws_security_group.external_alb_sg.id
}
