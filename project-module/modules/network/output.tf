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

output "internet_path" {
  description = <<-EOT
    인터넷 경로(라우팅 + NAT)가 살아 있음을 나타내는 값.

    [왜 필요한가]
    EKS 노드는 private(cluster) 서브넷에 있고, NAT 를 거쳐야 컨트롤 플레인·ECR·S3 에
    닿습니다. 그런데 eks 모듈은 network 에서 vpc_id 와 서브넷만 받기 때문에
    라우팅과 NAT 에는 의존 관계가 없습니다.

    그러면 destroy 때 Terraform 이 EKS 를 정리하는 도중에 인터넷 경로를 먼저 끊습니다.
    실제로 이렇게 깨졌습니다.
        NAT 인스턴스 삭제 -> 노드 NotReady -> LB Controller 죽음
        -> Ingress finalizer 를 뗄 주체가 없음 -> ALB 고아
        -> "Network vpc-... has some mapped public address(es)" 로 IGW 분리 실패

    이 값을 eks 모듈에 넘기면 의존 간선이 생겨, 노드 그룹이 사라진 뒤에야
    라우팅과 NAT 가 삭제됩니다. 값 자체는 쓰지 않습니다.
  EOT
  value = join(",", concat(
    [aws_route.public_internet_access.id],
    [for r in aws_route.private_nat_gateway_access : r.id],
    [for r in aws_route.private_nat_instance_access : r.id],
  ))
}
