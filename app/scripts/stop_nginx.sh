#!/bin/bash
# 배포 전에 nginx 를 멈춥니다.
# 첫 배포 때는 이 스크립트가 실행되지 않습니다(직전 버전이 없으므로).
set -uo pipefail

if systemctl is-active --quiet nginx; then
  echo "nginx 를 멈춥니다"
  systemctl stop nginx
else
  echo "nginx 가 실행 중이 아닙니다"
fi
exit 0
