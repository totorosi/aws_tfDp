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
# [수정] 예전에는 22 번이 0.0.0.0/0 으로 전 세계에 열려 있었습니다.
# 이제 ssh_allowed_cidrs 를 지정했을 때만, 그 대역에서만 열립니다.
# 비워 두면(기본값) 규칙 자체가 만들어지지 않습니다.
# ####################################################################################################
resource "aws_security_group" "ssh_sg" {
  name        = "${local.tag_header}ssh-sg"
  vpc_id      = aws_vpc.this.id
  description = "Allow SSH from allowed CIDRs only"

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
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

  # 관리자용 SSH. 기본은 닫혀 있고 ssh_allowed_cidrs 를 지정할 때만 열립니다.
  # NAT 기능 자체는 SSH 없이도 동작합니다.
  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  # VPC 내부에서 오는 모든 트래픽. 이게 NAT 의 본체입니다.
  ingress {
    description = "Traffic from inside the VPC to be NATed"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  # 외부(인터넷)로 모든 패킷 내보내기 (필수)
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
    description = "MySQL from inside the VPC"
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
