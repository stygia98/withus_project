#!/usr/bin/env bash
# EC2 최초 1회 설정 (EC2 안에서 sudo 로 실행). Amazon Linux 2023 기준, Ubuntu 는 패키지 설치 줄만 바꾼다
#   sudo bash ec2-setup.sh
# 하는 일: Java 21 설치, 실행 사용자 withus 생성, /opt/withus·/etc/withus 준비, systemd 유닛 설치.
# 환경변수 파일(/etc/withus/withus-backend.env)은 env.prod.example 을 보고 직접 채운다 — 비밀값이라 스크립트에 넣지 않는다
set -euo pipefail

if command -v dnf >/dev/null 2>&1; then
  dnf install -y java-21-amazon-corretto-headless
else
  apt-get update && apt-get install -y openjdk-21-jre-headless
fi
java -version

id withus >/dev/null 2>&1 || useradd --system --home-dir /opt/withus --shell /sbin/nologin withus
install -d -o withus -g withus -m 755 /opt/withus
install -d -o root -g root -m 755 /etc/withus

if [ ! -f /etc/withus/withus-backend.env ]; then
  install -o root -g root -m 600 /dev/null /etc/withus/withus-backend.env
  echo "빈 /etc/withus/withus-backend.env 를 만들었다 — env.prod.example 을 보고 값을 채운다"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -o root -g root -m 644 "$SCRIPT_DIR/withus-backend.service" /etc/systemd/system/withus-backend.service
systemctl daemon-reload
systemctl enable withus-backend
echo "설치 완료. JAR 을 올린 뒤(deploy-backend.sh) 'sudo systemctl start withus-backend' 로 시작한다"
