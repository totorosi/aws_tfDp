# 네트워크 구성을 위한 변수 설정
create_nat_gateway = false
cidr_header        = "10.0"
# [보안] owner / key_pair 는 IAM 사용자명 등 계정 식별 정보를 담고 있어 여기에 적지 않습니다.
#        secret.auto.tfvars.example 을 secret.auto.tfvars 로 복사해서 채우세요.
#        (*.auto.tfvars 는 .gitignore 에 등록되어 git 에 올라가지 않습니다)
env_type = "ex" # Name Tag에 사용됨 (prod, dev, test, lab, ex)

# Domain Name
domain_name = "" # 보유한 도메인이 있으면 입력 (Domain 태그에만 사용됨)

subnet_type = ["public", "private", "cluster"]

ami_type = "ubuntu2404"


# ################################################################################
# ArgoCD
# ================================================================================
# ArgoCD 가 이 저장소의 k8s/app 을 보고 클러스터를 맞춥니다.
argocd_repo_url        = "https://github.com/totorosi/aws_tfDp.git"
argocd_target_revision = "main"
argocd_path            = "k8s/app"
argocd_create_ingress  = true


# ################################################################################
# 보안
# ================================================================================
# SSH(22) 는 기본적으로 닫혀 있습니다. NAT 인스턴스나 EC2 에 접속해야 할 때만
# 본인 공인 IP 를 넣으세요. 0.0.0.0/0 은 쓰지 마세요.
#   curl -s https://checkip.amazonaws.com   으로 본인 IP 확인
# ssh_allowed_cidrs = ["203.0.113.4/32"]

# ################################################################################
# CI/CD (CodePipeline + CodeBuild + CodeDeploy -> EC2)
# --------------------------------------------------------------------------------
# [주의] CodeDeploy 는 EKS 를 지원하지 않습니다 (EC2/온프레미스, Lambda, ECS 만).
#        그래서 이 파이프라인은 EC2 로 배포하고, EKS 배포는 ArgoCD 가 맡습니다.
#
# [apply 후 수동 절차 1회]
#   CodeStar Connection 이 PENDING 으로 생성됩니다. 콘솔에서 승인해야 파이프라인이 돕니다.
#     terraform output pipeline_connection_setup
# ################################################################################
create_cicd            = true
cicd_github_repository = "totorosi/aws_tfDp"
cicd_github_branch     = "main"

# CodeDeploy 배포 대상 EC2. 0 이면 배포할 곳이 없습니다.
ec2_instance_count = 2

# 에이전트가 S3(아티팩트)와 CodeDeploy 엔드포인트에 닿아야 합니다.
# 퍼블릭 서브넷에 두면서 퍼블릭 IP 가 없으면 IGW 로 나갈 수 없습니다.
ec2_associate_public_ip = true

# ################################################################################
# CI 의 EKS 접근 권한
# --------------------------------------------------------------------------------
# OIDC 로 전환하면 CI 가 IAM 사용자가 아니라 역할로 붙습니다.
# 클러스터는 "생성한 사용자"에게만 admin 을 주므로, 그 역할에 접근 항목을
# 따로 만들어 줘야 합니다. 없으면 CI 의 plan 이 Unauthorized 로 실패합니다.
#
# [순서] remote-backend 를 먼저 apply 해서 역할이 존재해야 합니다.
# 역할 이름은 owner 에서 유도합니다: <owner>-github-actions-role
# ################################################################################
# EKS 를 주석 처리했으므로 클러스터 접근 항목도 만들지 않습니다.
# EKS 를 다시 켜면 true 로 되돌리세요.
grant_ci_cluster_access = false
