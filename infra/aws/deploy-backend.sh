#!/usr/bin/env bash
# 백엔드 JAR 을 빌드해 EC2 로 올리고 재시작한다 (로컬 PC 에서 실행, AWS API 는 호출하지 않는다 — SSH 만 쓴다)
#   EC2_HOST=<퍼블릭 IP 또는 DNS> SSH_KEY=~/.ssh/withus.pem bash infra/aws/deploy-backend.sh
# 선택: EC2_USER(기본 ec2-user, Ubuntu 는 ubuntu), SKIP_BUILD=1(이미 만든 JAR 재사용)
#
# 주의: 재시작은 발송이 끝난 뒤에 한다. 정상 종료(SIGTERM)는 남은 선점분을 PENDING 으로 되돌리지만(backend #92),
# 현재 처리 중인 1건은 마치고 내려가며, 재기동 후 남은 건이 이어서 나간다. 시연 직전 재시작은 피한다.
# 테스트는 이 스크립트가 돌리지 않는다 — 배포 전에 로컬 DB·Mailpit 으로 ./mvnw test 를 먼저 통과시킨다
set -euo pipefail

: "${EC2_HOST:?EC2_HOST 를 지정한다}"
: "${SSH_KEY:?SSH_KEY(EC2 키 파일 경로)를 지정한다}"
EC2_USER="${EC2_USER:-ec2-user}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BACKEND="$ROOT/withus_backend"
SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "$EC2_USER@$EC2_HOST")

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  (cd "$BACKEND" && ./mvnw -q -DskipTests package)
fi
JAR="$(ls "$BACKEND"/target/withus-backend-*.jar | head -1)"
echo "배포할 JAR: $JAR"

scp -i "$SSH_KEY" "$JAR" "$EC2_USER@$EC2_HOST:/tmp/withus-backend.jar"
"${SSH[@]}" 'sudo install -o withus -g withus -m 644 /tmp/withus-backend.jar /opt/withus/withus-backend.jar \
  && sudo systemctl restart withus-backend && sleep 15 && sudo systemctl --no-pager status withus-backend | head -5'

# 기동 확인: CSRF 발급이 200 이면 앱·DB 연결이 살아 있다. EC2 안에서 localhost 로 확인한다
"${SSH[@]}" 'curl -s -o /dev/null -w "csrf: %{http_code}\n" http://localhost:8080/api/v1/auth/csrf'
