# 운영 배포 절차 (W5)

> 기준: PRD 8.5·10.3·10.4, `docs/tech/TECH_STACK.md` 4장. 도메인·인증서 없음 — 브라우저·메일 링크·SNS 웹훅이 모두 **Amplify 기본 주소(HTTPS)** 로 들어와 Next.js rewrites(`/api/*`, `/t/*`, `/files/*`)로 EC2(HTTP)에 전달된다. CORS 는 열지 않는다.
>
> 이 폴더의 파일은 **로컬에서 준비만 끝낸 상태**다(2026-10-08). AWS 리소스는 아직 만들지 않았다.

| 파일 | 용도 |
|---|---|
| `env.prod.example` | EC2 백엔드 환경변수 템플릿 → `/etc/withus/withus-backend.env` (권한 600) |
| `withus-backend.service` | systemd 유닛 (SIGTERM 정상 종료, `TimeoutStopSec=60`) |
| `ec2-setup.sh` | EC2 최초 1회: Java 21, 실행 사용자, 폴더, 유닛 설치 |
| `deploy-backend.sh` | 로컬에서 JAR 빌드 → SSH 로 업로드·재시작·기동 확인 |
| `policies/ec2-role-policy.json` | EC2 IAM 역할: `ses:SendEmail`·`ses:SendRawEmail`, `images/*` 에 `s3:PutObject` |
| `policies/s3-bucket-policy.json` | 버킷 정책: `images/*` 만 공개 읽기(`s3:GetObject`) |

백엔드 운영 설정은 `withus_backend/src/main/resources/application-prod.yml`(값 고정 테스트 `ProdProfileConfigTest`).

## 배포 순서

순서가 한 번 순환한다: Amplify 는 EC2 주소(`BACKEND_URL`)가 필요하고, EC2 는 Amplify 주소(`WITHUS_PUBLIC_BASE_URL`)가 필요하다. **EC2 를 먼저 띄우고 → Amplify 를 만든 뒤 → EC2 환경변수를 채워 재시작**한다.

### 0. 먼저 시작 (메일 확인 대기)
- SES(ap-northeast-2)에서 **발신 주소 1개 + 시연 수신 주소** 이메일 인증. 샌드박스 유지(초당 1건·하루 200건, `ses.max-send-rate=1` 유지). 시연 고객 이메일은 모두 인증된 주소여야 한다.
- DKIM·SPF 가 없어 스팸함으로 갈 수 있다 — 도착을 미리 확인하고, 불안정하면 Mailpit 녹화로 대체(로드맵 리스크표).

### 1. RDS PostgreSQL 17
- 자동 백업 7일, 퍼블릭 액세스 없음, 보안 그룹은 **EC2 보안 그룹에서 5432 만** 허용.
- DB 이름 `withus`. 스키마는 백엔드 기동 시 Flyway 가 `db/migration`(V1·V20·V21·V30)만 적용한다 — 시드는 들어가지 않는다. **운영 DB 를 직접 수정하지 않는다.**

### 2. S3 버킷
- 버킷 생성 → `policies/s3-bucket-policy.json` 의 `<S3_BUCKET>` 을 바꿔 버킷 정책으로 적용.
- 업로드는 ACL 없이 하므로 공개 읽기는 버킷 정책으로만 열린다. 버킷의 **퍼블릭 액세스 차단에서 "버킷 정책" 관련 두 항목(BlockPublicPolicy, RestrictPublicBuckets)만 끈다**(ACL 관련 두 항목은 켜 둔다).

### 3. EC2 (Java 21, systemd)
1. IAM 역할을 만들어 `policies/ec2-role-policy.json`(버킷 이름 치환)을 붙이고 인스턴스에 연결한다. AWS 키는 환경변수에 넣지 않는다.
2. 보안 그룹: 백엔드 포트 8080 인바운드(Amplify SSR 의 송신 IP 는 고정되지 않아 출처를 좁힐 수 없다), SSH 22 는 내 IP 만.
3. `infra/aws/` 를 EC2 로 복사 → `sudo bash ec2-setup.sh`.
4. `/etc/withus/withus-backend.env` 를 `env.prod.example` 기준으로 채운다. 이 시점에는 `WITHUS_PUBLIC_BASE_URL`·`SES_TOPIC_ARN` 을 비워 둬도 된다.
5. 로컬에서 `EC2_HOST=... SSH_KEY=... bash infra/aws/deploy-backend.sh` → `csrf: 200` 확인.

### 4. Amplify (프론트)
1. `withus_frontend` 저장소 연결, 브랜치 `main`(또는 시연 브랜치). Next.js SSR 로 자동 인식된다.
2. 환경변수 `BACKEND_URL=http://<EC2 퍼블릭 DNS>:8080`. **rewrites 는 빌드할 때 정해지므로** 이 값을 바꾸면 다시 빌드(재배포)해야 한다.
3. 배포된 기본 주소(`https://<branch>.<app-id>.amplifyapp.com`)를 EC2 의 `WITHUS_PUBLIC_BASE_URL` 에 넣고 `sudo systemctl restart withus-backend`.
   EC2 퍼블릭 주소가 바뀌지 않도록 탄력적 IP 를 붙여 두면 2번을 다시 하지 않아도 된다.

### 5. SNS 웹훅
- SES 반송·스팸신고 → SNS 토픽 → HTTPS 구독 `https://<amplify 주소>/api/webhooks/ses`.
- 토픽 ARN 을 `SES_TOPIC_ARN` 에 넣고 재시작한 뒤 구독을 만든다(구독 확인 요청을 백엔드가 처리한다). 실제 SNS 서명 검증은 이때 처음 확인된다.

### 6. 발신자 정보
- `WITHUS_SENDER_NAME`·`WITHUS_SENDER_PHONE` 을 실제 값으로 넣고 재시작(재빌드 불필요). 080 번호는 실제 SMS 연동(O-03) 전까지 가상 번호가 남는다.

## 운영 확인 (PRD 10.3 재검증)

`docs/roles/pl-verification.md` 5장, `docs/demo/member2-10.3-checklist.md` 4장이 원본이다. 시연 데이터는 `docs/demo/prod-demo-data.md` 절차(관리자 화면·공개 API 로만 생성).

| 확인 | 방법 |
|---|---|
| 프로필만으로 동작 (항목 10) | 위 순서대로 코드 변경 없이 기동 |
| 프록시·쿠키·CSRF (항목 6·11·25) | 브라우저: 로그인 → 새로고침 유지, `document.cookie` 에 `XSRF-TOKEN` 만, `/c/[token]`·`/unsubscribe/[token]` 화면, 메일 속 `/t/*` 링크 |
| SES 실제 도착·`(광고)` 제목 (항목 3), 스로틀링 (항목 32) | 인증된 수신 주소로 소규모 캠페인 |
| 이미지 | 에디터 업로드 → S3 `images/` 저장, 공개 URL 접근, 버킷의 다른 경로는 403 |
| 1만 명 적재 (항목 30, 이슈 #73) | EC2 에서 RDS 를 대상으로 `EnqueuePhaseCheck`·`WorkflowSegmentScheduledLoadCheck` 실행, `wal_sync_time` 기록. 로컬 기준값: 10,027명 13.1초(2026-10-08) |
| 봇 UA | Gmail·Outlook·Naver 로 실제 메일 열기·클릭 후 `bot_yn` 확인 (`docs/roles/member3-verification.md` 4장) |
| 운영 시연 제외 | F-12 안내(항목 24, local 시드 99번으로 충족), A/B(항목 19, 범위 제외) |

## 주의

- **재시작은 발송이 끝난 뒤에.** 정상 종료는 남은 선점분을 PENDING 으로 되돌리지만(backend #92), 강제 종료(`kill -9`, 인스턴스 중지)는 선점분이 10분 뒤 `UNKNOWN_RESULT` 로 누락된다(중복보다 누락, CLAUDE.md 6장 5번).
- 광고성 발송은 08:00~20:50 에만 나간다. 시연 시각을 이 안에 잡는다.
- `XSRF-TOKEN` 쿠키는 요청이 HTTPS 인지로 `Secure` 를 정하는데, Amplify → EC2 구간이 HTTP 라 붙지 않는다(2026-10-08 prod 프로필 로컬 기동에서 확인). JS 가 읽는 CSRF 토큰이라 탈취돼도 단독으로는 쓸 수 없고, 인증 쿠키(`ACCESS_TOKEN`·`REFRESH_TOKEN`)는 `Secure; HttpOnly; SameSite=Lax` 로 확인됐다. 운영 브라우저 점검 때 함께 본다.
- 운영에서는 SpringDoc(Swagger UI·`/v3/api-docs`)을 끈다. API 계약 확인은 local 에서 한다.
- Gemini 무료 한도(RPM 15, RPD 500)를 시연 전날 확인한다.
