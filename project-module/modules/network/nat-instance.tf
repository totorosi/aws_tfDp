resource "aws_instance" "nat_instance" {
  count         = !local.create_nat_gateway ? 1 : 0
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

  # 키 페어 이름이 비어 있으면 null로 넘겨 EC2 생성 실패를 방지합니다.
  key_name = local.key_pair != "" ? local.key_pair : null

  # 보안 그룹 정의
  vpc_security_group_ids = [aws_security_group.nat_sg.id]

  # User Data
  user_data = local.ami_type == "ubuntu2404" ? file("${path.module}/nat-user-data-ubuntu.sh") : (
  file("${path.module}/nat-user-data-amazon.sh"))

  tags = { Name = "${local.tag_header}nat-instance" }
}
