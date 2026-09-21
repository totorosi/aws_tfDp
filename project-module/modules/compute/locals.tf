locals {
  name_prefix = "${var.tag_header}${var.name_suffix}"

  # 키 페어 이름이 비어 있으면 null 로 넘겨 생성 실패를 방지합니다.
  key_name = var.key_pair != "" ? var.key_pair : null

  # user_data 가 비어 있으면 null 로 넘겨 빈 스크립트가 들어가지 않게 합니다.
  user_data = var.user_data != "" ? var.user_data : null

  # 인스턴스 프로파일도 같은 이유로 빈 문자열이면 null 입니다.
  iam_instance_profile = var.iam_instance_profile != "" ? var.iam_instance_profile : null

  # 인스턴스 수가 서브넷 수보다 많으면 순환 배치합니다.
  subnet_count = length(var.subnet_ids)
}
