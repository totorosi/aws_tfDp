locals {
  bucket_name                   = var.bucket_name
  lock_table_name               = var.lock_table_name
  tag_header                    = var.tag_header
  enable_versioning             = var.enable_versioning
  sse_algorithm                 = var.sse_algorithm
  kms_key_id                    = var.kms_key_id
  billing_mode                  = var.billing_mode
  enable_point_in_time_recovery = var.enable_point_in_time_recovery

  # PAY_PER_REQUEST 모드에서는 용량 지정이 불가하므로 null 로 넘깁니다.
  read_capacity  = var.billing_mode == "PROVISIONED" ? var.read_capacity : null
  write_capacity = var.billing_mode == "PROVISIONED" ? var.write_capacity : null
}
