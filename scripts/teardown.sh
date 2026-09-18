#!/usr/bin/env bash
#
# 올바른 순서로 인프라를 정리합니다.
#
# terraform destroy 를 바로 실행하면 실패합니다.
# 이 구조에는 리소스를 만드는 주체가 둘이기 때문입니다.
#
#   Terraform                    VPC · 서브넷 · EKS · IAM · Helm 릴리스
#   AWS Load Balancer Controller ALB · 타겟 그룹 · 보안그룹(k8s-*) · ENI
#
# 컨트롤러가 만든 것은 Terraform state 에 없어서 destroy 대상이 아닙니다.
# 그런데 destroy 는 컨트롤러(Helm 릴리스)를 지워버리므로, 그 순간 컨트롤러가
# 만든 리소스가 전부 고아가 되고 VPC 삭제를 막습니다.
#
# 그래서 컨트롤러가 살아 있는 동안 Ingress 를 먼저 지워야 합니다.
# 컨트롤러가 자기가 만든 AWS 리소스를 스스로 정리해 줍니다.
#
# 사용법:
#   ./scripts/teardown.sh            확인 후 진행
#   ./scripts/teardown.sh --yes      확인 없이 진행
#   ./scripts/teardown.sh --check    삭제하지 않고 잔여물만 점검
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../project-module/projects"

AUTO_YES=0
CHECK_ONLY=0
for a in "$@"; do
  case "$a" in
    --yes|-y)  AUTO_YES=1 ;;
    --check)   CHECK_ONLY=1 ;;
    *) echo "알 수 없는 옵션: $a"; exit 2 ;;
  esac
done

step() { echo; echo "── $* ──"; }
die()  { echo "오류: $*" >&2; exit 1; }

command -v terraform >/dev/null || die "terraform 이 필요합니다"
command -v aws       >/dev/null || die "aws CLI 가 필요합니다"
command -v kubectl   >/dev/null || die "kubectl 이 필요합니다"

cd "$TF_DIR" || die "terraform 디렉터리를 찾을 수 없습니다: $TF_DIR"

# ----------------------------------------------------------------------------
# 대상 확인. destroy 후에는 output 을 읽을 수 없으므로 미리 저장해 둡니다.
# ----------------------------------------------------------------------------
step "대상 확인"
# destroy 후에는 state 가 비어 output 을 읽을 수 없으므로 여러 경로로 찾습니다.
REGION="$(terraform output -raw region 2>/dev/null || true)"
[ -n "$REGION" ] || REGION="${AWS_REGION:-}"
[ -n "$REGION" ] || REGION="$(aws configure get region 2>/dev/null || true)"
[ -n "$REGION" ] || die "리전을 알 수 없습니다. AWS_REGION 을 지정하거나 aws configure 로 기본 리전을 설정하세요"

CLUSTER="$(terraform output -raw eks_cluster_name 2>/dev/null || true)"
VPC_ID="$(terraform output -raw vpc_id 2>/dev/null || true)"

echo "  리전    : $REGION"
echo "  클러스터: ${CLUSTER:-(없음)}"
echo "  VPC     : ${VPC_ID:-(없음)}"

leftovers() {
  echo "  타겟 그룹   : $(aws elbv2 describe-target-groups --region "$REGION" --query 'length(TargetGroups)' --output text 2>/dev/null)"
  echo "  ALB/NLB     : $(aws elbv2 describe-load-balancers --region "$REGION" --query 'length(LoadBalancers)' --output text 2>/dev/null)"
  echo "  VPC(비기본) : $(aws ec2 describe-vpcs --region "$REGION" --query 'length(Vpcs[?IsDefault==`false`])' --output text 2>/dev/null)"
  echo "  k8s-* SG    : $(aws ec2 describe-security-groups --region "$REGION" --query "length(SecurityGroups[?starts_with(GroupName,'k8s-')])" --output text 2>/dev/null)"
  echo "  미연결 EIP  : $(aws ec2 describe-addresses --region "$REGION" --query 'length(Addresses[?AssociationId==null])' --output text 2>/dev/null)"
  echo "  EKS         : $(aws eks list-clusters --region "$REGION" --query 'length(clusters)' --output text 2>/dev/null)"
}

if [ "$CHECK_ONLY" = "1" ]; then
  step "잔여물 점검 (삭제하지 않음)"
  leftovers
  exit 0
fi

if [ "$AUTO_YES" != "1" ]; then
  echo
  echo "이 리전($REGION)의 실습 인프라를 모두 삭제합니다. 되돌릴 수 없습니다."
  read -r -p "계속하려면 yes 를 입력하세요: " ANS
  [ "$ANS" = "yes" ] || { echo "취소했습니다."; exit 0; }
fi

# ----------------------------------------------------------------------------
# 1. ArgoCD Application 삭제
#    syncPolicy.automated.selfHeal 때문에 Ingress 만 지우면 즉시 되살아납니다.
# ----------------------------------------------------------------------------
if [ -n "$CLUSTER" ] && aws eks describe-cluster --region "$REGION" --name "$CLUSTER" >/dev/null 2>&1; then
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null 2>&1 || true

  step "1. ArgoCD Application 삭제 (selfHeal 로 되살아나는 것 방지)"
  kubectl -n argocd delete application --all --timeout=120s 2>/dev/null || echo "  (없음)"

  # --------------------------------------------------------------------------
  # 2. Ingress 삭제. 컨트롤러가 살아 있어야 ALB·타겟그룹·SG 까지 정리됩니다.
  # --------------------------------------------------------------------------
  step "2. Ingress 삭제 (컨트롤러가 ALB·타겟그룹·보안그룹까지 정리)"
  kubectl get ingress -A --no-headers 2>/dev/null | awk '{print $1, $2}' | while read -r NS NAME; do
    echo "  삭제: $NS/$NAME"
    kubectl -n "$NS" delete ingress "$NAME" --timeout=180s 2>/dev/null || {
      # 컨트롤러가 이미 없으면 웹훅이 모든 Ingress 작업을 막습니다.
      echo "  -> 실패. 웹훅 제거 후 finalizer 를 직접 떼어냅니다"
      kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found 2>/dev/null
      kubectl delete mutatingwebhookconfiguration   aws-load-balancer-webhook --ignore-not-found 2>/dev/null
      kubectl -n "$NS" patch ingress "$NAME" -p '{"metadata":{"finalizers":null}}' --type=merge 2>/dev/null
      kubectl -n "$NS" delete ingress "$NAME" --ignore-not-found 2>/dev/null
    }
  done

  # --------------------------------------------------------------------------
  # 3. ALB 가 실제로 사라질 때까지 대기 (보통 2~3분)
  # --------------------------------------------------------------------------
  step "3. ALB 정리 대기"
  for i in $(seq 1 24); do
    N="$(aws elbv2 describe-load-balancers --region "$REGION" --query 'length(LoadBalancers)' --output text 2>/dev/null)"
    echo "  [$i/24] 남은 ALB: $N"
    [ "$N" = "0" ] && break
    sleep 15
  done
else
  step "1~3. 클러스터가 없어 건너뜁니다"
fi

# ----------------------------------------------------------------------------
# 4. terraform destroy
# ----------------------------------------------------------------------------
step "4. terraform destroy"
terraform destroy -auto-approve -lock-timeout=5m || {
  echo
  echo "destroy 가 실패했습니다. README 의 '이미 실패했다면' 절을 참고하세요."
  echo "자주 겪는 원인:"
  echo "  - Release not loaded : helm list 로 확인 후 terraform state rm"
  echo "  - DependencyViolation: 고아 ALB / 보안그룹 k8s-* 가 남아 있음"
  exit 1
}

# ----------------------------------------------------------------------------
# 5. 잔여물 점검
#    컨트롤러가 만든 것은 Terraform 이 모르므로 마지막에 직접 확인합니다.
# ----------------------------------------------------------------------------
step "5. 잔여물 점검"
leftovers

echo
echo "0 이 아닌 항목이 있으면 아래로 정리하세요."
echo "  타겟 그룹 : aws elbv2 delete-target-group --region $REGION --target-group-arn <ARN>"
echo "  미연결 EIP: aws ec2 release-address --region $REGION --allocation-id <ID>"
echo "  (EIP 는 다른 실습에서 쓰는 것이 아닌지 태그를 먼저 확인하세요)"
echo
echo "external-dns 가 만든 Route53 레코드는 policy=upsert-only 라 남습니다."
echo "필요하면 콘솔에서 직접 지우세요. (A/AAAA 와 짝이 되는 TXT 까지)"
