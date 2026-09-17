# ################################################################################
# [주의] VPC / 서브넷은 data 소스로 "조회"하지 않고 root 모듈에서 "전달" 받습니다.
# --------------------------------------------------------------------------------
# 예전에는 아래처럼 태그로 조회했습니다.
#     data "aws_vpc" "vpc" { filter { name = "tag:Name" values = ["...vpc"] } }
#
# 이 방식은 필터 값이 변수에서 와서 plan 시점에 이미 확정되므로, Terraform 이
# plan 단계에서 곧바로 AWS 에 조회를 날립니다. 그런데 그때는 VPC 가 아직
# 만들어지기 전이라 "no matching EC2 VPC found" 로 중단됩니다.
# (network 를 먼저 apply 한 뒤 eks 를 돌리면 우연히 성공하지만,
#  CI 처럼 한 번에 apply 하면 반드시 실패합니다)
#
# root 에서 module.network 의 출력값을 넘겨주면 의존 관계가 그래프에 명시되어
# Terraform 이 network -> eks 순서를 스스로 보장합니다.
# ################################################################################

data "aws_ami" "eks_al2023_latest" {
  most_recent = true
  owners      = ["602401143452"] # Amazon EKS 공식 계정

  filter {
    name = "name"
    # 'standard'를 명시하는 대신 와일드카드를 써서 1.35 버전의 x86_64 이미지를 찾습니다.
    values = ["amazon-eks-node-al2023-x86_64-standard-${local.k8s_version}-v*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}