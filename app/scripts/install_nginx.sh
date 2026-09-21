#!/bin/bash
# nginx 가 없으면 설치합니다. 이미 있으면 아무것도 하지 않습니다.
set -euo pipefail

if command -v nginx >/dev/null 2>&1; then
  echo "nginx 가 이미 설치되어 있습니다"
else
  echo "nginx 를 설치합니다"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y nginx
fi

# 배포 대상 디렉터리를 비워 둡니다.
# 이게 없으면 이전 배포에서 남은 파일과 섞입니다.
rm -rf /var/www/html/*
mkdir -p /var/www/html
