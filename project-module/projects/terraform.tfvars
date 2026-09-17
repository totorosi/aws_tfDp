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

# ec2_options = {
#   count                      = 1
#   ami_id                     = "ami-0c7217cdde317cfec" # 예시 AMI ID
#   instance_type              = "t3.micro"
#   subnet_id                  = ""
#   associate_public_ip_address = false
#   volume_size                = 30
#   volume_type                = "gp3"
#   delete_on_termination      = true
#   key_name                   = "<본인-키페어-이름>"
#   vpc_security_group_ids     = []
# }

# ################################################################################
# ArgoCD
# ================================================================================
# ArgoCD 가 이 저장소의 k8s/app 을 보고 클러스터를 맞춥니다.
argocd_repo_url        = "https://github.com/totorosi/aws_tfDp.git"
argocd_target_revision = "main"
argocd_path            = "k8s/app"
argocd_create_ingress  = true

# ArgoCD UI 도메인. host 를 지정하면 LB Controller 가 일치하는 ACM 인증서를
# 자동으로 찾아 HTTPS 를 붙입니다. (*.totorosi.cloud 와일드카드 인증서 사용)
argocd_ingress_host = "argocd.totorosi.cloud"

# [주의] argocd_route53_zone_name 은 비워둡니다.
# 값을 넣으면 Terraform 이 Route53 레코드를 직접 만드는데, 아래 external-dns 도
# 같은 이름(argocd.totorosi.cloud)을 관리하려 해서 소유자가 둘이 됩니다.
# 한쪽이 고치면 다른 쪽이 되돌리는 drift 가 생기므로 external-dns 에 맡깁니다.
# external-dns 를 쓰지 않을 때만 아래 주석을 해제하세요.
# argocd_route53_zone_name = "totorosi.cloud"

# ################################################################################
# external-dns
# --------------------------------------------------------------------------------
# Ingress 의 host 를 보고 Route53 레코드를 자동으로 만듭니다.
# ArgoCD 가 관리하는 Ingress(nginx)도 대상이라, ALB 주소가 바뀌어도 따라갑니다.
# ################################################################################
external_dns_domains = ["totorosi.cloud"]
external_dns_policy  = "upsert-only"
