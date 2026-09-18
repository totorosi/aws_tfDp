# ####################################################################################################
# 상태 저장용 S3 Bucket + 상태 잠금용 DynamoDB Table
# ====================================================================================================
# 리소스를 직접 선언하지 않고 modules/remote 를 호출합니다.
# 모듈 쪽에는 원본에 없던 보강이 들어가 있습니다.
#   - 서버 측 기본 암호화(SSE): 상태 파일에는 DB 비밀번호가 평문으로 담길 수 있습니다
#   - 퍼블릭 접근 전면 차단
#   - DynamoDB PITR 옵션, PAY_PER_REQUEST 요금제 선택
# ####################################################################################################
module "remote" {
  source = "../project-module/modules/remote"

  bucket_name     = var.bucket_name
  lock_table_name = var.lock_table_name

  tag_header = var.tag_header

  # 잠금 테이블은 트래픽이 거의 없어 쓴 만큼 내는 편이 저렴합니다.
  # 교재의 PROVISIONED(20/20) 방식을 쓰려면 아래를 바꾸세요.
  billing_mode = var.billing_mode
}
