#!/bin/bash
# 파일 복사가 끝난 뒤 nginx 를 켭니다.
set -euo pipefail

chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

systemctl enable nginx
systemctl restart nginx
echo "nginx 를 시작했습니다"
