# ####################################################################################################
# compute 모듈 사용 예시
# ====================================================================================================
# module "compute" {
#   source = "../modules/compute"
#
#   instance_count = 2
#   subnet_ids     = local.public_subnet_ids          # network 모듈 출력값
#   vpc_security_group_ids = [local.ssh_sg_id]
#
#   ami_id     = local.ami_id
#   key_pair   = var.key_pair
#   tag_header = local.tag_header
#
#   associate_public_ip_address = true
#   user_data = file("${path.module}/user-data.sh")
# }
# ####################################################################################################

# ####################################################################################################
# EC2 인스턴스
# ====================================================================================================
resource "aws_instance" "this" {
  count = var.instance_count

  ami           = var.ami_id
  instance_type = var.instance_type

  # 인스턴스 수가 서브넷 수보다 많으면 순환하며 배치합니다.
  # 예: 서브넷 3개에 인스턴스 5대 -> a, b, c, a, b
  subnet_id = var.subnet_ids[count.index % local.subnet_count]

  associate_public_ip_address = var.associate_public_ip_address
  vpc_security_group_ids      = var.vpc_security_group_ids

  # 비어 있으면 null 로 넘겨 생성 실패를 방지합니다.
  key_name  = local.key_name
  user_data = local.user_data

  # CodeDeploy 에이전트가 S3 에서 아티팩트를 받아가려면 필요합니다.
  iam_instance_profile = local.iam_instance_profile

  monitoring = var.enable_detailed_monitoring

  root_block_device {
    volume_size           = var.root_volume.size
    volume_type           = var.root_volume.type
    delete_on_termination = var.root_volume.delete_on_termination
    encrypted             = var.root_volume.encrypted
  }

  # 인스턴스 메타데이터를 IMDSv2 로 강제합니다.
  # v1 은 SSRF 로 자격 증명이 유출될 수 있어 기본값으로 막아 둡니다.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # CodeDeploy 배포 그룹이 태그로 대상을 찾으므로 extra_tags 를 함께 붙입니다.
  tags = merge(var.extra_tags, {
    Name = local.subnet_count > 1 ? "${local.name_prefix}-${count.index + 1}" : local.name_prefix
  })

  lifecycle {
    precondition {
      condition     = var.instance_count == 0 || local.subnet_count > 0
      error_message = "instance_count 가 0보다 크면 subnet_ids 를 반드시 지정해야 합니다."
    }

    precondition {
      condition     = var.instance_count == 0 || var.ami_id != ""
      error_message = "instance_count 가 0보다 크면 ami_id 를 반드시 지정해야 합니다."
    }
  }
}
