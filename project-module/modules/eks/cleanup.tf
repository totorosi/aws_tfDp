# ####################################################################################################
# destroy 순서 보정
# ====================================================================================================
# ALB·타겟그룹·보안그룹(k8s-*)·ENI 는 Terraform 이 아니라 LB Controller 가 만듭니다.
# state 에 없으니 destroy 대상이 아닌데, destroy 는 컨트롤러를 지워버리므로
# 그 순간 전부 고아가 되어 IGW 분리와 VPC 삭제를 막습니다.
#
# 이 리소스는 helm_release 에 의존하므로 destroy 시 "먼저" 파괴됩니다.
# 그때 컨트롤러가 아직 살아 있으므로, Ingress 를 지우면 컨트롤러가
# 자기가 만든 AWS 리소스를 스스로 회수합니다.
#
# ArgoCD 가 만든 Ingress 처럼 Terraform 이 모르는 것까지 함께 정리합니다.
# ####################################################################################################
resource "null_resource" "ingress_cleanup" {
  # when = destroy 프로비저너는 var / local 을 참조할 수 없어
  # 필요한 값을 triggers 에 담아 self 로 꺼내 씁니다.
  triggers = {
    cluster_name = aws_eks_cluster.k8s.name
    region       = local.region
  }

  provisioner "local-exec" {
    when = destroy

    # 실패해도 destroy 를 막지 않도록 내부에서 전부 흡수합니다.
    # 여기서 못 지운 것은 이어지는 terraform destroy 가 에러로 알려줍니다.
    on_failure = continue

    command = <<-EOT
      set +e
      echo "[cleanup] LB Controller 가 살아 있는 동안 Ingress 를 정리합니다"

      aws eks update-kubeconfig --region ${self.triggers.region} --name ${self.triggers.cluster_name} >/dev/null 2>&1
      if ! kubectl version >/dev/null 2>&1; then
        echo "[cleanup] 클러스터에 접근할 수 없어 건너뜁니다"
        exit 0
      fi

      # 1) ArgoCD Application 먼저. selfHeal 이 Ingress 를 즉시 되살립니다.
      kubectl -n argocd delete application --all --timeout=120s >/dev/null 2>&1
      echo "[cleanup] ArgoCD Application 정리"

      # 2) Ingress 삭제. 컨트롤러가 ALB·타겟그룹·보안그룹까지 회수합니다.
      kubectl delete ingress --all -A --timeout=180s >/dev/null 2>&1
      echo "[cleanup] Ingress 정리"

      # 3) 컨트롤러가 이미 없으면 웹훅이 모든 Ingress 작업을 막습니다.
      #    그 경우 웹훅을 지우고 finalizer 를 직접 떼어냅니다.
      if [ -n "$(kubectl get ingress -A --no-headers 2>/dev/null)" ]; then
        echo "[cleanup] Ingress 가 남아 있어 웹훅과 finalizer 를 직접 정리합니다"
        kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found >/dev/null 2>&1
        kubectl delete mutatingwebhookconfiguration   aws-load-balancer-webhook --ignore-not-found >/dev/null 2>&1
        kubectl get ingress -A --no-headers 2>/dev/null | awk '{print $1, $2}' | while read -r NS NAME; do
          kubectl -n "$NS" patch ingress "$NAME" -p '{"metadata":{"finalizers":null}}' --type=merge >/dev/null 2>&1
          kubectl -n "$NS" delete ingress "$NAME" --ignore-not-found >/dev/null 2>&1
        done
      fi

      # 4) 컨트롤러가 ALB 를 실제로 지울 때까지 기다립니다. 보통 2~3분.
      for i in $(seq 1 24); do
        N=$(aws elbv2 describe-load-balancers --region ${self.triggers.region} --query 'length(LoadBalancers)' --output text 2>/dev/null)
        [ "$N" = "0" ] && { echo "[cleanup] ALB 정리 완료"; break; }
        echo "[cleanup] ALB 대기 중... 남은 $N 개 ($i/24)"
        sleep 15
      done

      # 5) 마지막으로 웹훅을 제거합니다.
      #    이 프로비저너 직후 terraform 이 helm uninstall 을 실행하는데,
      #    그때 웹훅이 남아 있으면 컨트롤러가 자기 Service 삭제를 스스로 막아
      #    릴리스가 uninstalling 상태로 갇힙니다.
      kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found >/dev/null 2>&1
      kubectl delete mutatingwebhookconfiguration   aws-load-balancer-webhook --ignore-not-found >/dev/null 2>&1
      echo "[cleanup] LB Controller 웹훅 제거"
    EOT
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}
