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

