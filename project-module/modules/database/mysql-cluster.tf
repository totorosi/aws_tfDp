# ################################################################################
# Lambda Function에서 사용할 보안 그룹
# ================================================================================
resource "aws_security_group" "lambda_sg" {
  name        = "${local.tag_header}lambda-sg"
  description = "Security group for private web access"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_header}lambda-sg"
  }
}

# ################################################################################
# 보안 암호 생성
# 아래는 보안 암호 삭제
# aws secretsmanager delete-secret \
#   --secret-id <SECRETS_NAME> \
#   --force-delete-without-recovery
#   --region <REGION>
# ================================================================================
# 1. 시크릿 이름 정의
resource "aws_secretsmanager_secret" "mysql_secrets_manager" {
  description = "RDS 데이터베이스 비밀번호"
  name        = "${local.tag_header}mysql/secrets" # 콘솔에 표시될 이름
}
# 2. JSON형식으로 보안암호 지정
resource "aws_secretsmanager_secret_version" "mysql_secret_version" {
  secret_id = aws_secretsmanager_secret.mysql_secrets_manager.id
  secret_string = jsonencode({
    engine   = "mysql"
    host     = aws_rds_cluster.mysql_cluster.endpoint # DB 생성 완료 후 엔드포인트가 자동 주입됨
    port     = 3306
    username = local.db_username
    password = random_password.random_passwd.result
  })
}

# 16자리 랜덤 문자열 생성: 아래 override_special은 AWS에서 권장하는 형식
resource "random_password" "random_passwd" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ################################################################################
# RDS Secrets Manager Automatic Rotation (30일 주기 자동 변경)
# ================================================================================
# AWS Serverless Application Repository(SAR)에서 제공하는 CloudFormation 스택을 배포하는 리소스 선언
resource "aws_serverlessapplicationrepository_cloudformation_stack" "mysql_rotation" {
  # 생성될 CloudFormation 스택의 이름
  name = "${local.tag_header}mysql-rotation-stack"

  # AWS에서 공식 제공하는 RDS MySQL 단일 사용자 암호 순환(Rotation) Lambda 애플리케이션의 ARN (us-east-1 고정)
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"

  # CloudFormation이 IAM 역할 생성 및 리소스 정책을 정의할 수 있도록 승인하는 권한 설정
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  # Rotation Lambda 함수 동작에 필요한 매개변수(Parameter) 전달
  parameters = {
    # 생성될 Rotation Lambda 함수의 이름
    functionName = "${local.tag_header}rds-mysql-cluster-rotation-fn"

    # Lambda가 비밀번호 변경 후 호출할 해당 지역(Region)의 Secrets Manager API 엔드포인트 URL
    endpoint = "https://secretsmanager.${local.region}.amazonaws.com"

    # Lambda가 VPC 내부의 RDS에 접근할 수 있도록 배치할 Private Subnet ID 목록 (문자열을 쉼표로 연결)
    vpcSubnetIds = local.db_subnets_ids

    # Lambda 함수에 적용할 보안 그룹(Security Group) ID
    vpcSecurityGroupIds = aws_security_group.lambda_sg.id
  }
}

# Secrets Manager에 저장된 암호의 자동 순환(Rotation) 주기 및 Lambda를 연결하는 리소스 선언
resource "aws_secretsmanager_secret_rotation" "mysql_secret_rotation" {
  # 암호를 주기적으로 변경할 대상 Secrets Manager의 ID
  secret_id = aws_secretsmanager_secret.mysql_secrets_manager.id

  # 실제 암호 변경 작업을 수행할 Lambda 함수의 ARN (위의 CloudFormation 스택 출력값 참조)
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.mysql_rotation.outputs.RotationLambdaARN

  # 암호 자동 변경 규칙 설정
  rotation_rules {
    # 비밀번호를 30일마다 자동으로 변경하도록 지정
    automatically_after_days = 30
  }
}


# ################################################################################
# RDS Cluster 구성
# ================================================================================
# 3. Subnet Group 생성
resource "aws_db_subnet_group" "subnet_group" {
  name       = "${local.tag_header}db-subnet-group"
  subnet_ids = split(",", local.db_subnets_ids)

  tags = { Name = "${local.tag_header}-db-subnet-group" }
}

# 3. RDS MySQL Multi-AZ DB Cluster 생성 (Multi-AZ Cluster 전용)
resource "aws_rds_cluster" "mysql_cluster" {
  cluster_identifier = "${local.tag_header}mysql-cluster"
  engine             = "mysql"
  engine_version     = "8.0.46"

  db_cluster_instance_class = "db.c6gd.medium"

  # 필수: storage_type 명시 (gp3 또는 io1)
  storage_type      = "gp3"
  allocated_storage = 100
  # iops 및 throughput 속성은 주석 처리 상태 유지 (400GiB 미만 gp3 사용 시)
  # iops                    = 3000

  database_name   = "testdb"
  master_username = local.db_username
  master_password = random_password.random_passwd.result

  db_subnet_group_name   = aws_db_subnet_group.subnet_group.name
  vpc_security_group_ids = [local.mysql_sg_id]
  skip_final_snapshot    = true # 테스트 환경 시 true 추천

  # ModifyDBCluster 시 storage_type null 에러를 방지하기 위한 변경 무시 설정
  lifecycle {
    ignore_changes = [
      storage_type,
      allocated_storage,
      iops
    ]
  }
}


# ################################################################################
# RDS Proxy 구성
# ================================================================================
# 5. RDS Proxy IAM Role & Policy
resource "aws_iam_role" "proxy_role" {
  name = "${local.tag_header}rds-proxy-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "proxy_policy" {
  name = "${local.tag_header}rds-proxy-secrets-policy"
  role = aws_iam_role.proxy_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [aws_secretsmanager_secret.mysql_secrets_manager.arn]
    }]
  })
}

# 6. RDS Proxy 생성
resource "aws_db_proxy" "proxy" {
  # RDS Proxy 리소스의 식별 이름을 지정합니다. (AWS 콘솔에 표시되는 이름)
  name = "${local.tag_header}mysql-proxy"

  # 프록시가 연결할 데이터베이스 엔진 종류를 설정합니다. (MYSQL 또는 POSTGRESQL)
  engine_family = "MYSQL"

  # 유휴(Idle) 클라이언트 연결 유지 시간을 초 단위로 설정합니다. (1800초 = 30분 동안 트래픽이 없으면 연결 종료)
  idle_client_timeout = 1800

  # 클라이언트와 RDS Proxy 간의 통신 시 TLS/SSL 암호화 연결을 강제할지 여부입니다. (true: 암호화 통신 필수)
  require_tls = true

  # RDS Proxy가 Secrets Manager에서 DB 인증 정보를 읽어오기 위해 사용할 IAM Role의 ARN을 지정합니다.
  role_arn = aws_iam_role.proxy_role.arn

  # RDS Proxy의 ENI(네트워크 인터페이스)가 배치될 VPC 서브넷 ID 목록입니다. 
  # (콤마로 구분된 서브넷 ID 문자열을 split 함수로 분할하여 List(String) 형태로 변환)
  vpc_subnet_ids = split(",", local.db_subnets_ids)

  # RDS Proxy 네트워크 인터페이스에 적용할 보안 그룹(Security Group) ID 목록입니다.
  vpc_security_group_ids = [local.mysql_sg_id]

  # RDS Proxy가 데이터베이스 사용자 인증을 처리하는 방식을 정의하는 블록입니다.
  auth {
    # 사용자 인증에 사용할 자격 증명 관리 방식을 지정합니다. (SECRETS: AWS Secrets Manager 사용)
    auth_scheme = "SECRETS"

    # 인증 설정에 대한 설명(Description)을 입력합니다.
    description = "Master database credentials"

    # RDS Proxy 접속 시 IAM 자격 증명 기반 인증 사용 여부를 설정합니다. (DISABLED: 일반 DB 계정/비밀번호 인증 사용)
    iam_auth = "DISABLED"

    # DB 접속 비밀번호가 저장되어 있는 AWS Secrets Manager 시크릿의 ARN을 지정합니다.
    secret_arn = aws_secretsmanager_secret.mysql_secrets_manager.arn
  }
}

# 7. RDS Proxy Target Group 연결 (DB Cluster 연결)
# RDS Proxy의 커넥션 풀(Connection Pool) 동작 방식을 설정하는 기본 타겟 그룹 리소스입니다.
resource "aws_db_proxy_default_target_group" "proxy_target" {
  # 커넥션 풀 설정을 적용할 RDS Proxy의 이름을 지정합니다.
  db_proxy_name = aws_db_proxy.proxy.name

  # RDS Proxy와 실제 DB 간의 커넥션 풀 세부 옵션을 정의합니다.
  connection_pool_config {
    # 클라이언트가 커넥션 풀에서 DB 연결을 빌리기 위해 대기하는 최대 시간(초)입니다.
    # (120초 동안 커넥션을 얻지 못하면 클라이언트 요청이 타임아웃 오류를 반환함)
    connection_borrow_timeout = 120

    # RDS Proxy가 DB 인스턴스의 최대 연결 수(max_connections) 중 사용할 수 있는 최대 비율(%)입니다.
    # (100: DB가 허용하는 전체 커넥션 수까지 Proxy가 사용 가능)
    max_connections_percent = 100

    # 유휴(Idle) 상태로 풀에 유지할 수 있는 최대 커넥션 비율(%)입니다.
    # (50: 클라이언트 요청이 없어도 최대 커넥션의 50%까지는 DB와의 연결을 끊지 않고 유지)
    max_idle_connections_percent = 50
  }
}

# RDS Proxy와 실제 백엔드 데이터베이스(Aurora Cluster)를 상호 연결
resource "aws_db_proxy_target" "proxy_target_cluster" {
  # 대상 DB를 연결할 RDS Proxy의 이름을 지정합니다.
  db_proxy_name = aws_db_proxy.proxy.name

  # 위에서 정의한 기본 타겟 그룹의 이름을 지정하여 연결합니다.
  target_group_name = aws_db_proxy_default_target_group.proxy_target.name

  # RDS Proxy가 트래픽을 전달할 실제 백엔드 Aurora DB Cluster의 식별자(ID)를 지정합니다.
  db_cluster_identifier = aws_rds_cluster.mysql_cluster.id
}



# ################################################################################
# [참고] DB 초기화(init.sql 실행)는 테라폼에 넣지 않았습니다.
# --------------------------------------------------------------------------------
# RDS Proxy 는 프라이빗 서브넷에 있어 외부에서 직접 붙을 수 없고, VPC 안의
# 배스천(NAT/Bastion) 인스턴스를 거쳐야 합니다. 또 ssh / jq / mysql-client 가
# 실행 머신에 있어야 해서 GitHub Actions 러너에서는 동작하지 않습니다.
#
# 초기화가 필요하면 apply 완료 후 배스천에 접속해 수동으로 실행하세요.
#   1) terraform output rds_get_password_command  로 비밀번호 조회 명령을 확인
#   2) 배스천 접속 후 mysql-client 설치
#   3) mysql -h <proxy_endpoint> -P 3306 -u <username> -p < init.sql
# ################################################################################
