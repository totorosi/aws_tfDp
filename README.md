# aws_tfDp

AWS 인프라(VPC / EKS / RDS / S3)를 Terraform 모듈로 구성하고,
GitHub Actions 로 plan·apply 하는 실습 저장소입니다.

실행 환경은 **Ubuntu (WSL 포함)** 기준입니다. CI 러너도 `ubuntu-latest` 라
로컬과 동일한 플랫폼에서 동작합니다.

## 구조

```
project-module/
  projects/              루트 모듈 (진입점) - 여기서 terraform 실행
  modules/
    network              VPC · 서브넷 · 라우팅 · NACL · 보안그룹 · NAT
    eks                  EKS 클러스터 · 노드그룹 · IRSA · LB Controller
    database             RDS MySQL 클러스터 · RDS Proxy · Secrets Manager
    s3-website           퍼블릭 정적 웹사이트 버킷
    remote               원격 상태 저장소(S3 + DynamoDB) 모듈
    store                범용 비공개 S3 스토리지 모듈
    compute              (미사용) EC2 모듈 초안
remote-backend/          상태 저장소를 직접 만드는 부트스트랩 코드
.github/workflows/       terraform.yml (메인) · remote-backend.yml
```

리소스 정의는 전부 `modules/` 안에 있습니다.
`projects/main.tf` 는 모듈을 호출만 하므로 `resource` 블록이 없습니다.

## 준비

### 1. 상태 저장소

`remote-backend/` 는 상태 저장용 S3 버킷과 DynamoDB 잠금 테이블을 만드는
코드입니다. **이미 버킷이 있다면 실행하지 마세요.** 중복 버킷이 생깁니다.

없을 때만, 최초 1회 로컬에서:

```bash
cd remote-backend
cp terraform.tfvars.example terraform.tfvars   # 버킷·테이블 이름 입력
cp backend.hcl.example      backend.hcl        # 같은 값 입력

# providers.tf 의 backend "s3" 블록을 주석 처리한 뒤
terraform init && terraform apply

# 주석을 해제하고
terraform init -backend-config=backend.hcl -migrate-state
```

### 2. 로컬 설정 파일

계정 식별 정보는 저장소에 두지 않습니다. `.example` 을 복사해 채우세요.
두 파일 모두 `.gitignore` 에 있습니다.

```bash
cd project-module/projects
cp backend.hcl.example      backend.hcl        # 상태 버킷 · 잠금 테이블
cp secret.auto.tfvars.example secret.auto.tfvars  # owner · key_pair
```

| 파일 | 내용 |
|---|---|
| `backend.hcl` | `bucket`, `dynamodb_table` |
| `secret.auto.tfvars` | `owner` (리소스 이름 접두사), `key_pair` (EC2 키 페어 이름) |

`owner` 와 `env_type`(terraform.tfvars) 이 합쳐져 모든 리소스 이름 앞에 붙습니다.
예: `owner = "dev01"`, `env_type = "ex"` → `dev01-ex-vpc`, `dev01-ex-eks-cluster`

### 3. EC2 키 페어

`secret.auto.tfvars` 에 적은 이름의 키 페어가 배포 리전에 미리 있어야 합니다.

## 실행

```bash
cd project-module/projects

terraform init -backend-config=backend.hcl   # backend.hcl 지정 필수
terraform plan
terraform apply
```

`backend` 블록은 변수를 쓸 수 없어 값을 비워둔 "부분 구성" 상태입니다.
그래서 `terraform init` 만 실행하면 실패합니다.

apply 후 주요 정보는 출력값으로 확인합니다.

```bash
terraform output                      # 전체
terraform output eks_kubeconfig_command
terraform output rds_get_password_command
```

DB 비밀번호는 출력하지 않고 조회용 명령만 노출합니다.

## GitHub Actions

`.github/workflows/terraform.yml` 이 메인 파이프라인입니다.

- **PR / push** → `plan` 만 실행 (인프라 변경 없음)
- **Actions 탭에서 수동 실행** → `plan` / `apply` / `destroy` 선택

apply 는 직전 단계에서 저장한 `tfplan` 을 그대로 적용하므로,
미리 본 것과 다른 내용이 반영되지 않습니다.

### 필요한 Secret

Settings → Secrets and variables → Actions

| 이름 | 용도 |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM 사용자 액세스 키 |
| `AWS_SECRET_ACCESS_KEY` | 시크릿 키 |
| `TF_BACKEND_BUCKET` | 상태 저장 S3 버킷 이름 |
| `TF_BACKEND_DYNAMODB_TABLE` | 상태 잠금 DynamoDB 테이블 이름 |
| `TF_VAR_OWNER` | 리소스 이름 접두사 |
| `TF_VAR_KEY_PAIR` | EC2 키 페어 이름 |

임시 자격 증명(`ASIA...` 로 시작)을 쓰는 경우에만 `AWS_SESSION_TOKEN` 이
추가로 필요합니다. 장기 키(`AKIA...`)는 필요 없습니다.

## 정리 (destroy)

**`terraform destroy` 를 바로 실행하면 실패합니다.** 순서 문제가 있습니다.

ALB 는 Terraform 이 만들지 않습니다. Ingress 를 보고 AWS Load Balancer Controller 가
만듭니다. 그런데 destroy 는 그 컨트롤러를 먼저 지우고, 그러면 ALB 를 삭제할 주체가
사라져 아래 세 에러가 연쇄적으로 납니다.

```
Error: Ingress (argocd/argocd-server) still exists
Error: failed to delete release: aws-load-balancer-controller
Error: deleting EC2 Internet Gateway ... DependencyViolation:
       Network vpc-xxx has some mapped public address(es).
```

Ingress 에는 `ingress.k8s.aws/resources` finalizer 가 박혀 있어 컨트롤러 없이는
지워지지 않고, 남은 ALB 의 공인 IP 가 IGW 분리를 막습니다.

### 스크립트로 한 번에

순서를 자동으로 지키는 스크립트가 있습니다. 아래 "올바른 순서"를 그대로 수행하고,
마지막에 잔여물까지 점검합니다.

```bash
./scripts/teardown.sh          # 확인 후 진행
./scripts/teardown.sh --yes    # 확인 없이 진행
./scripts/teardown.sh --check  # 삭제하지 않고 잔여물만 점검
```

Ingress 삭제가 막히면(컨트롤러가 이미 없는 경우) 웹훅을 제거하고 finalizer 를
직접 떼는 처리까지 들어 있습니다.

### 올바른 순서

컨트롤러가 살아 있을 때 Ingress 를 먼저 지웁니다. 컨트롤러가 finalizer 를 처리하며
ALB 까지 정리해 줍니다.

```bash
# 1. ArgoCD 가 Ingress 를 되살리지 못하도록 Application 부터 제거
kubectl -n argocd delete application --all

# 2. Ingress 전부 삭제 (컨트롤러가 ALB 까지 정리)
kubectl delete ingress --all -A

# 3. ALB 가 실제로 사라졌는지 확인 (0 이 될 때까지 2~3분)
aws elbv2 describe-load-balancers --region <리전>   --query 'length(LoadBalancers)' --output text

# 4. 그 다음 destroy
cd project-module/projects
terraform destroy
```

1번을 건너뛰면 `syncPolicy.automated` 때문에 ArgoCD 가 Ingress 를 즉시 되살립니다.

### 이미 실패했다면

컨트롤러가 먼저 지워진 뒤라면 수동으로 정리해야 합니다.
아래 세 가지는 **모두 같은 원인(컨트롤러 부재)에서 나오는 증상**이며, destroy 를
재실행할 때마다 순서대로 하나씩 드러납니다.

| 에러 | 막고 있는 것 |
|---|---|
| `Ingress (...) still exists` | finalizer 를 떼줄 컨트롤러가 없음 |
| `DependencyViolation` (IGW 분리 실패) | 고아 ALB 가 물고 있는 공인 IP |
| `DependencyViolation` (VPC 삭제 실패) | 컨트롤러가 만든 `k8s-*` 보안 그룹 |
| (에러 없음. 조용히 남음) | 컨트롤러가 만든 타겟 그룹 |

`<리전>` 과 `<VPC_ID>` 는 본인 값으로 바꾸세요.

**1단계 — 웹훅 제거**

컨트롤러 파드는 없는데 웹훅 등록만 남아 있으면 모든 Ingress 작업이
`no endpoints available` 로 거부됩니다. finalizer 를 떼려는 patch 조차 막히므로
이것부터 지워야 합니다.

```bash
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found
kubectl delete mutatingwebhookconfiguration   aws-load-balancer-webhook --ignore-not-found
```

**2단계 — finalizer 제거 후 Ingress 삭제**

```bash
kubectl get ingress -A     # 대상 확인
kubectl -n <네임스페이스> patch ingress <이름> -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete ingress --all -A
```

**3단계 — 고아 ALB 삭제**

```bash
aws elbv2 describe-load-balancers --region <리전> --query "LoadBalancers[?VpcId=='<VPC_ID>'].LoadBalancerArn" --output text | xargs -n1 -I{} aws elbv2 delete-load-balancer --region <리전> --load-balancer-arn {}

# ELB ENI 가 0 이 될 때까지 기다린 뒤 다음 단계로 (2~3분)
aws ec2 describe-network-interfaces --region <리전> --filters "Name=vpc-id,Values=<VPC_ID>" "Name=description,Values=ELB*" --query 'length(NetworkInterfaces)' --output text
```

**4단계 — 고아 보안 그룹 삭제**

컨트롤러는 ALB 마다 `k8s-` 로 시작하는 보안 그룹을 만듭니다. Terraform 이 만든 게
아니므로 Terraform 은 존재조차 모르고, 이게 남아 있으면 VPC 가 삭제되지 않습니다.
서로 참조하고 있어 규칙부터 비워야 지워집니다.

```bash
SGS=$(aws ec2 describe-security-groups --region <리전> --filters "Name=vpc-id,Values=<VPC_ID>" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)

for SG in $SGS; do
  ING=$(aws ec2 describe-security-groups --region <리전> --group-ids "$SG" --query 'SecurityGroups[0].IpPermissions' --output json)
  EGR=$(aws ec2 describe-security-groups --region <리전> --group-ids "$SG" --query 'SecurityGroups[0].IpPermissionsEgress' --output json)
  [ "$ING" != "[]" ] && aws ec2 revoke-security-group-ingress --region <리전> --group-id "$SG" --ip-permissions "$ING"
  [ "$EGR" != "[]" ] && aws ec2 revoke-security-group-egress  --region <리전> --group-id "$SG" --ip-permissions "$EGR"
done

for SG in $SGS; do aws ec2 delete-security-group --region <리전> --group-id "$SG"; done
```

**5단계 — VPC 의존성 확인 후 destroy 재실행**

아래가 전부 0 이면 VPC 가 지워집니다.

```bash
aws ec2 describe-network-interfaces --region <리전> --filters "Name=vpc-id,Values=<VPC_ID>" --query 'length(NetworkInterfaces)' --output text
aws ec2 describe-subnets            --region <리전> --filters "Name=vpc-id,Values=<VPC_ID>" --query 'length(Subnets)' --output text
aws ec2 describe-security-groups    --region <리전> --filters "Name=vpc-id,Values=<VPC_ID>" --query "length(SecurityGroups[?GroupName!='default'])" --output text

cd project-module/projects && terraform destroy
```

### state 에만 남은 유령 리소스

이미 삭제된 리소스가 state 에만 남으면 destroy 가 계속 실패합니다.

```
Error: uninstall: Release not loaded: aws-load-balancer-controller
```

실제로 없는지 먼저 확인하고, 없다면 state 에서 제거합니다.
(state 에서 빼는 것이므로 실제 리소스에는 영향이 없습니다)

```bash
helm list -A                    # 실제 릴리스 목록
terraform state list | grep helm  # state 가 알고 있는 것

# 실제로 없는데 state 에만 있다면
terraform state rm module.eks.helm_release.aws_load_balancer_controller
```

`connection reset by peer` 나 `Please retry` 가 섞여 있으면 일시적 네트워크 오류일
수 있습니다. 클러스터가 살아 있는지(`kubectl get ns`) 먼저 확인하고,
살아 있으면 그냥 재시도하세요. state rm 은 실제로 없을 때만 씁니다.

### destroy 후 확인

```bash
# 연결되지 않은 Elastic IP 는 시간당 과금됩니다
aws ec2 describe-addresses --region <리전>   --query 'Addresses[?AssociationId==null].[PublicIp,AllocationId]' --output text

# 남아 있으면 (다른 실습에서 쓰지 않는지 확인 후)
aws ec2 release-address --region <리전> --allocation-id <ID>

# 타겟 그룹은 VPC 대시보드에 나오지 않습니다. EC2 콘솔 > 로드 밸런싱 > 대상 그룹
# 에서 확인하거나 아래 명령으로 봅니다. 과금은 없지만 고아로 남습니다.
aws elbv2 describe-target-groups --region <리전> --query 'TargetGroups[].[TargetGroupName,VpcId]' --output text
aws elbv2 delete-target-group --region <리전> --target-group-arn <ARN>

# external-dns 가 만든 Route53 레코드는 policy 가 upsert-only 라 남습니다.
# 필요하면 콘솔에서 직접 지우세요. (A/AAAA 와 짝이 되는 TXT 레코드까지)
```

## 알아둘 점

**플랫폼별 락 파일** — `.terraform.lock.hcl` 에 `linux_amd64` 와
`windows_amd64` 해시를 모두 기록해 두었습니다. 다른 플랫폼에서 쓰려면:

```bash
terraform providers lock -platform=<플랫폼>
```

**모듈 안의 provider 선언** — `modules/eks` 가 kubernetes·helm 프로바이더를
직접 선언합니다. 이 때문에 해당 모듈에는 `depends_on` 을 쓸 수 없어,
VPC·서브넷을 변수로 전달해 의존 관계를 만듭니다.

**ALB 의 소유자는 Terraform 이 아닙니다.** Ingress 를 보고 AWS Load Balancer
Controller 가 만듭니다. 그래서 Terraform 은 ALB 의 존재를 모르고, destroy 순서를
스스로 잡지 못합니다. 위 "정리 (destroy)" 절차를 반드시 따르세요.

**ArgoCD 는 지운 리소스를 되살립니다.** Application 의 `syncPolicy.automated.selfHeal`
이 켜져 있어, kubectl 로 Ingress 를 지워도 즉시 다시 만듭니다. 정리할 때는 Application
부터 지워야 합니다.

**external-dns 와 Terraform 이 같은 DNS 를 관리하면 충돌합니다.** 둘 다 같은 레코드를
소유하려 해서 한쪽이 고치면 다른 쪽이 되돌립니다. 이 저장소는 external-dns 에
일원화했고, 그래서 `argocd_route53_zone_name` 을 비워 두었습니다.

**Secrets Manager 이름 예약** — destroy 후 같은 이름으로 다시 만들면
30일간 `already scheduled for deletion` 으로 실패할 수 있습니다.

**RDS Multi-AZ DB Cluster** — `db.c6gd.medium` 을 쓰는 Multi-AZ DB 클러스터는
리전별 지원이 제한적입니다. 배포 리전에서 지원하지 않으면 database 모듈만
실패하므로, 인스턴스 클래스를 바꾸거나 단일 인스턴스로 전환해야 합니다.

**DB 초기화** — `modules/database/init.sql` 은 자동 실행되지 않습니다.
RDS Proxy 가 프라이빗 서브넷에 있어 배스천을 거쳐야 하기 때문입니다.
apply 후 수동으로 실행하세요.
