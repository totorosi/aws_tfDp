locals {
  tag_header               = var.tag_header
  region                   = var.region
  key_pair                 = var.key_pair
  vpc_id                   = var.vpc_id
  subnet_ids               = var.cluster_subnet_ids
  eks_admin_principal_arns = var.eks_admin_principal_arns
  k8s_version              = var.k8s_version
}
