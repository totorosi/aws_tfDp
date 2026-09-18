#!/usr/bin/env bash
#
# destroy 후 잔여물 점검 (아무것도 삭제하지 않습니다)
#
# 예전에는 이 자리에 teardown.sh 가 있었습니다. terraform destroy 가 순서를
# 못 잡아서 kubectl 로 Ingress 를 먼저 지워 주는 스크립트가 필요했기 때문입니다.
#
# 지금은 그 순서가 Terraform 그래프 안에 들어가 있습니다.
#   projects/main.tf        : module "argocd" 의 depends_on = [module.eks]
#   modules/eks/eks.tf      : helm_release 의 depends_on (노드그룹 / CRD / SA)
#   modules/argocd          : Application 의 ArgoCD finalizer
#   modules/eks/cleanup.tf  : 그래도 남는 것에 대한 안전망
#
# 그래서 이제 정리는 terraform destroy 한 번이면 끝납니다.
# 이 스크립트는 "정말 다 지워졌나"를 사람이 확인하는 용도로만 남깁니다.
#
# 사용법:
#   ./scripts/check-leftovers.sh
#   AWS_REGION=sa-east-1 ./scripts/check-leftovers.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../project-module/projects"

command -v aws >/dev/null || { echo "오류: aws CLI 가 필요합니다" >&2; exit 1; }

# destroy 후에는 state 가 비어 output 을 읽을 수 없으므로 여러 경로로 찾습니다.
REGION=""
[ -d "$TF_DIR" ] && REGION="$(cd "$TF_DIR" && terraform output -raw region 2>/dev/null || true)"
[ -n "$REGION" ] || REGION="${AWS_REGION:-}"
[ -n "$REGION" ] || REGION="$(aws configure get region 2>/dev/null || true)"
[ -n "$REGION" ] || { echo "오류: 리전을 알 수 없습니다. AWS_REGION 을 지정하세요" >&2; exit 1; }

echo "리전: $REGION"
echo

FAIL=0
check() {
  local label="$1" n="$2"
  if [ "$n" = "0" ] || [ -z "$n" ] || [ "$n" = "None" ]; then
    printf "  %-22s %s\n" "$label" "0"
  else
    printf "  %-22s %s  <-- 남아 있음\n" "$label" "$n"
    FAIL=1
  fi
}

echo "-- 이 실습이 만드는 리소스 --"
check "EKS 클러스터"    "$(aws eks list-clusters --region "$REGION" --query 'length(clusters)' --output text 2>/dev/null)"
check "VPC(기본 제외)"  "$(aws ec2 describe-vpcs --region "$REGION" --query 'length(Vpcs[?IsDefault==`false`])' --output text 2>/dev/null)"
check "ALB/NLB"         "$(aws elbv2 describe-load-balancers --region "$REGION" --query 'length(LoadBalancers)' --output text 2>/dev/null)"
check "타겟 그룹"       "$(aws elbv2 describe-target-groups --region "$REGION" --query 'length(TargetGroups)' --output text 2>/dev/null)"
check "k8s-* 보안그룹"  "$(aws ec2 describe-security-groups --region "$REGION" --query "length(SecurityGroups[?starts_with(GroupName,'k8s-')])" --output text 2>/dev/null)"
check "미연결 EIP"      "$(aws ec2 describe-addresses --region "$REGION" --query 'length(Addresses[?AssociationId==null])' --output text 2>/dev/null)"
check "실행 중 EC2"     "$(aws ec2 describe-instances --region "$REGION" --query 'length(Reservations[].Instances[?State.Name!=`terminated`][])' --output text 2>/dev/null)"
check "RDS 클러스터"    "$(aws rds describe-db-clusters --region "$REGION" --query 'length(DBClusters)' --output text 2>/dev/null)"

echo
if [ "$FAIL" = "0" ]; then
  echo "깨끗합니다."
else
  echo "남은 것이 있습니다. 같은 계정의 다른 실습 리소스일 수 있으니"
  echo "지우기 전에 Name 태그로 소유자를 먼저 확인하세요."
  echo
  echo "  미연결 EIP : aws ec2 release-address --region $REGION --allocation-id <ID>"
  echo "  타겟 그룹  : aws elbv2 delete-target-group --region $REGION --target-group-arn <ARN>"
fi
exit "$FAIL"
