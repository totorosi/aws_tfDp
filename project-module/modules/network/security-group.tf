# ####################################################################################################
# 외부 HTTP/HTTPS 허용 보안 그룹
# ====================================================================================================
# compute 모듈의 EC2 에 붙습니다. (root 의 local.ec2_security_group_ids)
# ####################################################################################################
resource "aws_security_group" "external_alb_sg" {
  name        = "${local.tag_header}external-alb-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow HTTP and HTTPS Traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0 # 모든 포트
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}external-alb-sg" }
}

# ####################################################################################################
# SSH
# ====================================================================================================
resource "aws_security_group" "ssh_sg" {
  name        = "${local.tag_header}ssh-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow SSH Traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0 # 모든 포트
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}ssh-sg" }
}

# ####################################################################################################
# NAT Instance
# ====================================================================================================
resource "aws_security_group" "nat_sg" {
  name        = "${local.tag_header}nat-sg"
  description = "Security Group for NAT Instance"
  vpc_id      = aws_vpc.this.id

  # 1. 관리자용 SSH 접속 (실무에서는 본인 공인 IP로 제한 권장)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실무에선 본인 IP 권장
  }

  # 2. VPC 내부에서 오는 모든 트래픽 (NAT 대상)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  # 3. 외부(인터넷)로 모든 패킷 내보내기 (필수)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}nat-sg" }
}

# ####################################################################################################
# MySQL
# ====================================================================================================
# database 모듈의 RDS 와 RDS Proxy 에 붙습니다. (root 의 local.mysql_sg_id)
# ####################################################################################################
resource "aws_security_group" "mysql_sg" {
  name        = "${local.tag_header}mysql-sg"
  description = "Security Group for MySQL cluster and proxy"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.tag_header}mysql-sg" }
}
