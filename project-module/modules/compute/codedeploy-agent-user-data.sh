#!/bin/bash
# ####################################################################################################
# CodeDeploy 에이전트 설치 (Ubuntu 24.04)
# ====================================================================================================
# 이 에이전트가 EC2 안에서 돌면서 CodeDeploy 의 배포 지시를 받아
# S3 에서 번들을 내려받고 appspec.yml 의 훅을 실행합니다.
# 에이전트가 없으면 배포가 "대기"만 하다 타임아웃됩니다.
# ####################################################################################################
set -uo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>&1)

REGION="__REGION__"

echo "=== 1. 필수 패키지 ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
# ruby: 에이전트가 루비로 동작합니다. wget: 설치 스크립트를 받아옵니다.
apt-get install -y ruby-full wget nginx curl

echo "=== 2. CodeDeploy 에이전트 설치 ==="
cd /tmp
wget -q "https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
chmod +x ./install
./install auto

echo "=== 3. 에이전트 기동 ==="
systemctl enable codedeploy-agent
systemctl restart codedeploy-agent
systemctl is-active codedeploy-agent && echo "CodeDeploy 에이전트 동작 중"

echo "=== 4. SSM 에이전트 (키 없이 접속용) ==="
# 우분투 공식 AMI 에는 snap 으로 들어 있지만 꺼져 있는 경우가 있습니다.
# 이게 살아 있어야 aws ssm start-session 으로 들어가 배포 로그를 볼 수 있습니다.
# (ssh_allowed_cidrs 기본값이 빈 목록이라 SSH 는 닫혀 있습니다)
snap install amazon-ssm-agent --classic 2>/dev/null || true
snap start amazon-ssm-agent 2>/dev/null || true
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service 2>/dev/null || true

echo "=== 5. nginx 기본 기동 ==="
# 첫 배포 전에도 80 포트가 응답하도록 켜 둡니다.
systemctl enable nginx
systemctl start nginx

echo "=== 완료 ==="
