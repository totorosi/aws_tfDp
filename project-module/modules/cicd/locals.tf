locals {
  name             = "${var.tag_header}nginx"
  deploy_tag_value = var.deploy_tag_value != "" ? var.deploy_tag_value : local.name

  # 연결을 직접 만들었으면 그 ARN 을, 값을 받았으면 그 값을 씁니다.
  connection_arn = var.codestar_connection_arn != "" ? var.codestar_connection_arn : aws_codestarconnections_connection.github[0].arn

  create_connection = var.codestar_connection_arn == ""
}
