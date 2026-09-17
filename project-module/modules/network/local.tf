locals {
  region             = var.region
  azs                = var.azs
  tag_header         = var.tag_header
  create_nat_gateway = var.create_nat_gateway
  subnet_map         = var.subnet_map
  route_map          = var.route_map
  subnet_type        = var.subnet_type
  ami_id             = var.ami_id
  ami_type           = var.ami_type
  key_pair           = var.key_pair
  inbound_ports = [
    { from = 80, to = 80 },
    { from = 443, to = 443 },
    { from = 8000, to = 8000 }
  ]
}
