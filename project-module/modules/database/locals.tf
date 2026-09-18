locals {
  region        = var.region
  vpc_id        = var.vpc_id
  tag_header    = var.tag_header
  db_subnet_ids = var.db_subnet_ids
  mysql_sg_id   = var.mysql_sg_id
  db_username   = var.db_username
}
