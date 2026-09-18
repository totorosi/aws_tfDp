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
    argocd               ArgoCD · UI Ingress · Application (GitOps 진입점)
    database             RDS MySQL 클러스터 · RDS Proxy · Secrets Manager
    s3-website           퍼블릭 정적 웹사이트 버킷
    store                범용 비공개 S3 스토리지
    compute              범용 EC2 (기본 0대)
    remote               원격 상태 저장소(S3 + DynamoDB)
k8s/app/                 ArgoCD 가 동기화하는 애플리케이션 매니페스트
remote-backend/          상태 저장소를 직접 만드는 부트스트랩 코드
scripts/                 destroy 후 잔여물 점검 스크립트
.github/workflows/       terraform.yml (메인) · remote-backend.yml
```

리소스 정의는 전부 `modules/` 안에 있습니다.
`projects/main.tf` 는 모듈을 호출만 하므로 `resource` 블록이 없습니다.

## 배포 방식

Terraform 이 인프라를, ArgoCD 가 애플리케이션을 담당합니다.

```
terraform apply      VPC · EKS · LB Controller · ArgoCD 설치
     |
git push             k8s/app/ 수정 후 push
     |
ArgoCD sync          Git 을 보고 클러스터를 그 상태로 맞춤
     |
LB Controller        Ingress 를 보고 ALB 생성
```

애플리케이션을 바꿀 때 `terraform apply` 를 다시 돌릴 필요가 없습니다.
`k8s/app/` 을 고쳐서 push 하면 ArgoCD 가 반영합니다.

**도메인(Route53)은 쓰지 않습니다.** ALB 기본 주소로 접속합니다.

```bash
terraform output argocd_url                  # ArgoCD UI
kubectl -n web get ingress nginx             # 애플리케이션 ALB 주소
```

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
terraform apply       # 생성. 이것 하나면 끝입니다
terraform destroy     # 삭제. 이것 하나면 끝입니다
```

`backend` 블록은 변수를 쓸 수 없어 값을 비워둔 "부분 구성" 상태입니다.
그래서 `terraform init` 만 실행하면 실패합니다.

apply 후 주요 정보는 출력값으로 확인합니다.

```bash
terraform output                                 # 전체
terraform output argocd_url                      # ArgoCD UI 주소
terraform output argocd_initial_password_command # admin 비밀번호 조회 명령
terraform output eks_kubeconfig_command
```

DB 비밀번호와 ArgoCD 비밀번호는 출력하지 않고 조회용 명령만 노출합니다.

로컬에서 apply/destroy 하려면 실행 머신에 `aws` 와 `kubectl` 이 있어야 합니다.
`modules/eks/cleanup.tf` 의 안전망이 이 둘을 씁니다.
(GitHub Actions `ubuntu-latest` 러너에는 기본 포함)

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
| `AWS_ROLE_ARN` | OIDC 역할 ARN (등록하면 액세스 키 대신 이걸 씁니다) |

임시 자격 증명(`ASIA...` 로 시작)을 쓰는 경우에만 `AWS_SESSION_TOKEN` 이
추가로 필요합니다. 장기 키(`AKIA...`)는 필요 없습니다.

## destroy 가 한 번에 끝나는 이유

이 부분이 이 저장소에서 가장 신경 쓴 곳입니다.

### 문제

만드는 주체가 셋인데 지우는 주체는 Terraform 하나뿐입니다.

| 주체 | 만드는 것 | Terraform state |
|---|---|---|
| Terraform | VPC · EKS · IAM · Helm 릴리스 · ArgoCD Ingress | 있음 |
| LB Controller | ALB · 타겟그룹 · 보안그룹(`k8s-*`) · ENI | **없음** |
| ArgoCD | nginx Deployment · Service · Ingress · Namespace | **없음** |

`terraform destroy` 는 state 에 있는 것만 지웁니다. 그런데 destroy 가
LB Controller 를 먼저 죽이면, 컨트롤러가 만든 ALB 는 지울 주체가 사라져
고아가 되고 IGW 분리와 VPC 삭제를 막습니다.

### 해결 — 파괴 순서를 그래프에 넣음

Terraform 은 의존 관계의 **역순**으로 파괴합니다. 그 성질을 이용해
아래 순서를 코드로 고정했습니다.

```
Application(finalizer) → ArgoCD Ingress → ArgoCD Helm
  → ingress_cleanup → LB Controller → CRD/ServiceAccount
  → 노드그룹 → 클러스터 → VPC
```

| 어디 | 무엇 | 왜 |
|---|---|---|
| `projects/main.tf` | `module "argocd"` 의 `depends_on = [module.eks]` | ArgoCD 관련 전부가 EKS 전부보다 먼저 파괴 |
| `modules/argocd/application.tf` | Application 에 ArgoCD finalizer | ArgoCD 가 자기가 배포한 nginx 리소스까지 스스로 회수 |
| `modules/eks/eks.tf` | `helm_release` 의 `depends_on` (노드그룹·CRD·SA) | 컨트롤러가 파드 살아 있을 때 uninstall |
| `modules/eks/cleanup.tf` | destroy 프로비저너 | 그래도 남는 Ingress·타겟그룹에 대한 안전망 |

**노드그룹 의존이 왜 필요한가** — LB Controller 차트는 자기를 지키는 웹훅을
함께 설치합니다. 노드가 먼저 사라지면 컨트롤러 파드가 죽고, 이어지는
`helm uninstall` 이 자기 Service 를 지울 때 응답 없는 웹훅을 호출하다 실패합니다.
릴리스가 `uninstalling` 상태로 갇히고 `failed to delete release` 로 멈춥니다.

**provider 를 루트로 올린 이유** — Terraform 은 자체 `provider` 블록을 가진
모듈에 `depends_on` 을 금지합니다. argocd 모듈이 provider 를 갖고 있던 동안에는
위의 `depends_on` 을 쓸 수 없었습니다. 설정을 `projects/provider.tf` 로 옮겨
해결했습니다. (`modules/eks` 는 자기가 클러스터를 만드는 모듈이라 예외)

### 확인

```bash
./scripts/check-leftovers.sh
```

아무것도 지우지 않고 잔여물만 셉니다. 전부 0 이면 정상입니다.

## GitHub Actions 인증 (OIDC)

CI 는 두 가지 방식으로 AWS 에 붙을 수 있고, 워크플로가 자동으로 고릅니다.

| Secret `AWS_ROLE_ARN` | 인증 방식 |
|---|---|
| 없음 | 액세스 키 (구 방식) |
| 있음 | **OIDC** (권장) |

### OIDC 가 나은 이유

액세스 키는 만료가 없습니다. 유출되면 지울 때까지 유효하고, 훔친 사람이
자기 노트북에서도 쓸 수 있습니다.

OIDC 는 GitHub 이 실행할 때마다 `나는 이 저장소의 이 워크플로다` 라는 서명된
토큰을 발급하고, AWS 가 그걸 확인해 1시간짜리 임시 자격 증명을 내줍니다.
보관되는 비밀이 없고, 다른 저장소에서는 가져갈 수 없습니다.

### 전환 순서

순서를 지키면 CI 가 중간에 끊기지 않습니다.

```bash
# 1. 이 계정에 GitHub OIDC 공급자가 이미 있는지 확인
aws iam list-open-id-connect-providers | grep githubusercontent
#    있으면 remote-backend/terraform.tfvars 에
#      create_github_oidc_provider = false

# 2. tfvars 에 값 채우기 (terraform.tfvars.example 참고)
#      github_repository = "<소유자>/<저장소>"
#      tag_header        = "<본인-IAM-사용자명>-"

# 3. 역할 생성
cd remote-backend
terraform init -backend-config=backend.hcl
terraform apply

# 4. 역할 ARN 을 Secret 으로 등록
gh secret set AWS_ROLE_ARN --body "$(terraform output -raw github_actions_role_arn)"

# 5. Actions 에서 plan 을 한 번 돌려 OIDC 로 붙는지 확인
#    (인증 단계 이름이 "AWS 인증 (OIDC - 권장)" 으로 표시되면 성공)

# 6. 확인됐으면 액세스 키 Secret 삭제
gh secret delete AWS_ACCESS_KEY_ID
gh secret delete AWS_SECRET_ACCESS_KEY
```

### 주의: 공유 계정

OIDC 공급자는 **AWS 계정당 하나뿐인 공용 리소스**입니다.
이 계정을 반 전체가 쓴다면:

- 다른 사람이 먼저 만들었으면 `create_github_oidc_provider = false` 로 두세요
- 공급자에 `prevent_destroy` 를 걸어 두었습니다. 지우면 남의 CI 도 깨집니다
- IAM 역할 이름에는 `tag_header` 가 붙어 사람마다 구분됩니다

### 권한 범위는 그대로입니다

역할에는 `AdministratorAccess` 가 붙습니다. 지금 CI 가 쓰는 IAM 사용자와
같은 권한이라 이번 전환으로 넓어지지도 좁아지지도 않습니다.
OIDC 는 **자격 증명 보관 문제**를 고치는 것이지 **권한 범위 문제**를 고치지
않습니다. 좁히려면 `github_actions_policy_arns` 를 바꾸세요.

## 알아둘 점

**플랫폼별 락 파일** — `.terraform.lock.hcl` 에 `linux_amd64` 와
`windows_amd64` 해시를 모두 기록해 두었습니다. 다른 플랫폼에서 쓰려면:

```bash
terraform providers lock -platform=<플랫폼>
```

**ALB 의 소유자는 Terraform 이 아닙니다.** Ingress 를 보고 AWS Load Balancer
Controller 가 만듭니다. `aws_lb` 리소스는 코드 어디에도 없습니다.

**ArgoCD 는 지운 리소스를 되살립니다.** `syncPolicy.automated.selfHeal` 이
켜져 있어, kubectl 로 Ingress 를 지워도 Git 상태로 즉시 되돌립니다.
손으로 정리할 일이 있으면 Application 부터 지워야 합니다.
(destroy 에서는 위 순서가 이미 그렇게 처리합니다)

**Secrets Manager 이름 예약** — `recovery_window_in_days = 0` 으로 두어
destroy 직후 같은 이름으로 다시 apply 할 수 있습니다.

**RDS 는 기본 비활성** — `create_rds = false` 입니다. sa-east-1 의 Multi-AZ DB
클러스터 최소 사양이 `db.m5d.large` 이고 인스턴스를 3대 띄워 비쌉니다.
필요할 때만 켜세요.

**DB 초기화** — `modules/database/init.sql` 은 자동 실행되지 않습니다.
RDS Proxy 가 프라이빗 서브넷에 있어 배스천을 거쳐야 하기 때문입니다.
apply 후 수동으로 실행하세요.
