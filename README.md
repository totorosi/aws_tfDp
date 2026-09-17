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

## 알아둘 점

**플랫폼별 락 파일** — `.terraform.lock.hcl` 에 `linux_amd64` 와
`windows_amd64` 해시를 모두 기록해 두었습니다. 다른 플랫폼에서 쓰려면:

```bash
terraform providers lock -platform=<플랫폼>
```

**모듈 안의 provider 선언** — `modules/eks` 가 kubernetes·helm 프로바이더를
직접 선언합니다. 이 때문에 해당 모듈에는 `depends_on` 을 쓸 수 없어,
VPC·서브넷을 변수로 전달해 의존 관계를 만듭니다.

**Secrets Manager 이름 예약** — destroy 후 같은 이름으로 다시 만들면
30일간 `already scheduled for deletion` 으로 실패할 수 있습니다.

**RDS Multi-AZ DB Cluster** — `db.c6gd.medium` 을 쓰는 Multi-AZ DB 클러스터는
리전별 지원이 제한적입니다. 배포 리전에서 지원하지 않으면 database 모듈만
실패하므로, 인스턴스 클래스를 바꾸거나 단일 인스턴스로 전환해야 합니다.

**DB 초기화** — `modules/database/init.sql` 은 자동 실행되지 않습니다.
RDS Proxy 가 프라이빗 서브넷에 있어 배스천을 거쳐야 하기 때문입니다.
apply 후 수동으로 실행하세요.
