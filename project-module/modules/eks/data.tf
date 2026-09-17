data "aws_vpc" "vpc" {
  filter {
    name   = "tag:Name"
    values = ["${local.tag_header}vpc"] # 찾고자 하는 VPC의 Name 태그 값
  }
}

data "aws_subnets" "cluster_subnets" {
  # 특정 VPC 내부로 한정하고 싶다면 아래 필터를 추가하세요
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  filter {
    name   = "tag:Type"
    values = ["cluster"]
  }
}

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