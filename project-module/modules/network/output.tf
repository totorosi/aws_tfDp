output "network" {
  description = "VPC와 Subnet 리소스 전체 객체"
  value = {
    vpc = aws_vpc.this
    subnets = aws_subnet.this
  }
}

output "mysql_sg" {
  value = aws_security_group.mysql_sg.id
}