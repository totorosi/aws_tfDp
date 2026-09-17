locals {
  tag_header        = var.tag_header
  region            = var.region
  bucket_name       = "${var.tag_header}${var.bucket_name}"
  force_destroy     = var.force_destroy
  enable_versioning = var.enable_versioning
  sse_algorithm     = var.sse_algorithm
  kms_key_id        = var.kms_key_id

  # for_each 로 다루기 위해 리스트를 id 기준 맵으로 변환합니다.
  lifecycle_rules = { for r in var.lifecycle_rules : r.id => r }
}
