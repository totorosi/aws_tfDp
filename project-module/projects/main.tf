module "network" {
  source = "../modules/network"

  azs                = local.azs
  vpc_cidr_block     = local.vpc_cidr_block
  subnet_map         = local.subnet_map
  route_map          = local.route_map
  subnet_type        = var.subnet_type
  tag_header         = local.tag_header
  create_nat_gateway = var.create_nat_gateway
  key_pair           = var.key_pair
  vpc_options        = local.vpc_options
  ami_type           = var.ami_type
  ami_id             = local.ami_id
  region             = local.region
}

# --------------------------------------------------------------------------------
module "eks" {
  source     = "../modules/eks"

  key_pair   = local.key_pair
  tag_header = local.tag_header
  region     = local.region

  # 모듈에 provider선언을 하게되면 depends_on을 사용할 수 없음.
  # depends_on = [module.network]
}

# --------------------------------------------------------------------------------
module "static_web_site" {
  source = "../modules/s3-website"

  tag_header = local.tag_header
  region     = local.region
}

# --------------------------------------------------------------------------------
module "rds" {
  source      = "../modules/database"
  tag_header  = local.tag_header
  vpc_id      = local.vpc_id
  region      = local.region
  mysql_sg_id = local.mysql_sg_id
}

# --------------------------------------------------------------------------------
# module "compute" {
#   source        = "../modules/compute"
#   ec2_options   = var.options
# }
