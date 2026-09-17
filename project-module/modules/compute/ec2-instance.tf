resource "aws_instance" "ec2_instance" {
  ami           = local.ami_id
  instance_type = "t3.micro"

  # 퍼블릭 서브넷의 ID를 참조하여 연결합니다.
  subnet_id = aws_subnet.this["public${split("-", local.azs[0])[2]}"].id
  # 퍼블릭 IP 활성화
  associate_public_ip_address = true
  # NAT 인스턴스 필수 설정: 소스/대상 확인 비활성화
  source_dest_check = false

  # 볼륨 지정
  root_block_device {
    volume_size           = 10
    volume_type           = "gp3"
    delete_on_termination = true # 인스턴스 삭제 시 함께 삭제
  }

  key_name = var.ssh_key

  # 보안 그룹 정의
  vpc_security_group_ids = [
    aws_security_group.ssh_sg.id,
    aws_security_group.external_alb_sg.id
  ]

  # User Data
  user_data = <<-EOF
#!/bin/bash
apt update && apt install -y nginx unzip
systemctl enable nginx
systemctl start nginx
EOF
  tags      = { Name = "${local.tag_header}instance" }
}
