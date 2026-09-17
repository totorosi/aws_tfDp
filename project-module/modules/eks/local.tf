locals {
  tag_header               = var.tag_header
  region                   = var.region
  key_pair                 = var.key_pair
  node_instance_type       = var.node_instance_type
  vpc_id                   = data.aws_vpc.vpc.id
  subnet_ids               = data.aws_subnets.cluster_subnets.ids
  node_ami_id              = data.aws_ami.eks_al2023_latest.id
  eks_admin_principal_arns = var.eks_admin_principal_arns
  k8s_version              = var.k8s_version
}
