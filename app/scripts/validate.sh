#!/bin/bash
# 배포가 실제로 동작하는지 확인합니다.
# 여기서 실패하면 CodeDeploy 가 배포를 실패로 처리하고 직전 버전으로 되돌립니다.
set -euo pipefail

for i in $(seq 1 10); do
  CODE="$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ || true)"
  if [ "$CODE" = "200" ]; then
    echo "검증 성공 (HTTP $CODE)"
    exit 0
  fi
  echo "대기 중... ($i/10) HTTP=$CODE"
  sleep 3
done

echo "검증 실패: nginx 가 200 을 돌려주지 않습니다"
exit 1
