output "pipeline_name" {
  description = "CodePipeline 이름"
  value       = aws_codepipeline.this.name
}

output "pipeline_url" {
  description = "콘솔에서 파이프라인을 여는 주소"
  value       = "https://${var.region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.this.name}/view?region=${var.region}"
}

output "codedeploy_app_name" {
  description = "CodeDeploy 애플리케이션 이름"
  value       = aws_codedeploy_app.this.name
}

output "deployment_group_name" {
  description = "CodeDeploy 배포 그룹 이름"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "artifact_bucket" {
  description = "파이프라인 아티팩트 버킷"
  value       = aws_s3_bucket.artifacts.bucket
}

output "instance_profile_name" {
  description = <<-EOT
    배포 대상 EC2 에 붙여야 하는 인스턴스 프로파일 이름.
    root 에서 compute 모듈의 iam_instance_profile 로 넘깁니다.
  EOT
  value       = aws_iam_instance_profile.ec2.name
}

output "deploy_tags" {
  description = <<-EOT
    배포 대상 EC2 에 붙여야 하는 태그.
    root 에서 compute 모듈의 extra_tags 로 넘깁니다.
    이 태그가 안 맞으면 배포가 "성공"으로 끝나면서 아무 데도 배포되지 않습니다.
  EOT
  value       = { (var.deploy_tag_key) = local.deploy_tag_value }
}

output "connection_arn" {
  description = "GitHub 연결 ARN"
  value       = local.connection_arn
}

output "connection_setup_required" {
  description = <<-EOT
    연결 승인 안내.
    Terraform 이 만든 연결은 PENDING 상태라 사람이 한 번 승인해야 합니다.
    AWS 가 요구하는 OAuth 절차라 자동화할 수 없습니다.
  EOT
  value = local.create_connection ? join("\n", [
    "[필수] GitHub 연결을 콘솔에서 승인하세요. 승인 전에는 파이프라인이 돌지 않습니다.",
    "  1) https://${var.region}.console.aws.amazon.com/codesuite/settings/connections?region=${var.region}",
    "  2) '${local.name}-github' 선택 > Update pending connection > GitHub 로그인 > 저장소 승인",
    "  3) 확인: aws codestar-connections list-connections --region ${var.region} --query \"Connections[].[ConnectionName,ConnectionStatus]\" --output table",
  ]) : "기존 연결(${var.codestar_connection_arn})을 재사용하므로 승인 절차가 필요 없습니다."
}
