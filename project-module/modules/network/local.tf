locals {
  azs                = var.azs
  tag_header         = var.tag_header
  create_nat_gateway = var.create_nat_gateway
  subnet_map         = var.subnet_map
  subnet_type        = var.subnet_type
  route_map          = var.route_map
  ami_id             = var.ami_id
  ami_type           = var.ami_type
  key_pair           = var.key_pair
}
