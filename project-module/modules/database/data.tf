data "aws_region" "current" {}
data "aws_subnets" "db_subnets" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  filter {
    name    = "tag:Type"
    values  = ["private"] 
  }
}
