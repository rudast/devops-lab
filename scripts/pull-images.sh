#!/usr/bin/env bash
# Скачивает образы курса из GitHub Container Registry преподавателя
# и даёт им привычные имена (postgres:17-alpine и т.д.),
# чтобы docker-compose.yml и Dockerfile работали без изменений.
# Запуск:  bash scripts/pull-images.sh
set -euo pipefail

REG="ghcr.io/tenroman1-design/devops-lab"

pull_and_tag() {   # $1 — имя в GHCR, $2 — привычное имя
  echo "==> $2"
  docker pull "$REG/$1"
  docker tag  "$REG/$1" "$2"
}

pull_and_tag postgres:17-alpine  postgres:17-alpine
pull_and_tag redis:7-alpine      redis:7-alpine
pull_and_tag python:3.12-slim    python:3.12-slim
pull_and_tag nginx:1.27-alpine   nginx:1.27-alpine
pull_and_tag hello-world:latest  hello-world:latest
pull_and_tag gitleaks:latest     zricethezav/gitleaks:latest

echo
echo "Проверка:"
missing=0
for img in postgres:17-alpine redis:7-alpine python:3.12-slim nginx:1.27-alpine hello-world:latest zricethezav/gitleaks:latest; do
  if docker image inspect "$img" >/dev/null 2>&1; then echo "  OK   $img"; else echo "  НЕТ  $img"; missing=1; fi
done
docker run --rm hello-world | grep "Hello from Docker"
[ "$missing" = 0 ] && echo "Готово: все образы на месте." || { echo "Часть образов не скачалась — запустите скрипт ещё раз."; exit 1; }
