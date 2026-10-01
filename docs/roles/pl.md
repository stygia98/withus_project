# PL — 공통 기반·통합·배포

- 백엔드 패키지: `auth`, `common`
- 기준: PRD 10.1, 10.2 / roadmap 1·3장
- Flyway 번호 대역: `V1~V9`

## Phase 0 — 시작 기반 (W1 첫 2일)
- [x] 로컬 저장소 3개 `git init` (main)
- [x] 최초 커밋, `dev` 브랜치, 원격 연결(stygia98/withus_project·withus_backend·withus_frontend)
- [x] push (main·dev, 3개 저장소)
- [x] GitHub 설정: 기본 브랜치 `dev`, 브랜치 보호(PR 필수·승인 1, 관리자 우회 허용), 팀원 초대 — 3개 저장소 각각 (기본 브랜치·보호 여부는 API로 확인)
- [x] 메인 저장소: `CLAUDE.md`, `docs/`, `.github/`, `.gitignore`, `infra/docker-compose.yml`(PostgreSQL 17, Mailpit), `infra/.env.example`
- [x] backend 골격(Spring Boot 4.0.8, SpringDoc, 설정·타임존·스케줄러 풀) — 컴파일 확인
- [x] frontend 골격(Next.js 15, shadcn/ui, TanStack Query, sonner, rewrites, `lib/api-client.ts`, `lib/query-keys.ts`) — lint·build 확인
- [x] `V1__init.sql` 초안(18개 테이블, 부분 유니크 인덱스) — 로컬 적용 확인(18개 테이블, 타임존 Asia/Seoul). **확정·동결**
- [x] PRD 10.1 인터페이스 시그니처 초안: `SegmentService`, `ConsentService`, `TrackingLinkService`, `CouponService`, `TrackEventRepository`, `PlaceholderRenderer` — **확정**
- [x] `docs/api/API_SPEC.md`, `docs/db/DB_SCHEMA.md`, `docs/tech/TECH_STACK.md` — TECH_STACK 확정(6장 결정 사항), API_SPEC은 초안(최종 계약은 Swagger)
- [x] Docker 로컬 기동, Flyway V1 적용, Swagger UI, `./mvnw test` 확인

## W1
- [x] 공통 응답 포맷·전역 예외·오류 코드·SpringDoc
- [x] 로그인/로그아웃/재발급(httpOnly 쿠키), CSRF(`GET /api/v1/auth/csrf`), 5회 실패 잠금 — 테스트 6건
- [x] 최초 OWNER 계정, 스케줄러 풀(`spring.task.scheduling.pool.size=5`)
- [x] Next.js 골격: rewrites, 공통 fetch 래퍼, `lib/query-keys.ts`, 로그인 화면
- [x] 레이아웃·GNB·인증 가드 (목업: `docs/design/mockups/`, frontend #8)
- [ ] 사용자 관리 API
- [ ] **M1**: DDL 적용, 로그인 동작, 인터페이스 합의, Mailpit 발송 1통

## W2
- [ ] 일회성 발송 E2E 통합 테스트 (**M2**)

## W3
- [ ] SES 이메일 주소 인증(발신 1개 + 시연 수신 주소), 샌드박스 유지 — 도메인 없음
- [ ] 통합 테스트(워크플로우 + 수신거부 + 쿠폰) (**M3**)

## W4
- [ ] PRD 10.3 전체 점검, 코드 리뷰 (**M4**)
- [ ] `infra/aws/` 배포 스크립트, 배포 리허설(Amplify → EC2 프록시 확인)

## W5
- [ ] EC2(도메인·인증서 없음), RDS, S3, SES(샌드박스), Amplify(기본 주소), 프록시(`/api/*`, `/t/*`)·쿠키·CSRF 확인, SNS 웹훅
- [ ] 발신자 명칭·연락처·080 번호 실제 값 교체 (**M5**)

## PR 리뷰 우선순위 (사고 시 영향 순)
1. 발송 큐(팀원2) — 중복·누락 발송, 야간 광고 발송
2. 워크플로우 엔진(팀원2) — 멱등성, 멈춤 복구
3. 세그먼트 동적 SQL(팀원1) — SQL 인젝션, 잘못된 대상
4. 수신거부 토큰·처리(팀원1) — 법규, GET 상태 변경

## 상시
- PR 리뷰·병합(feature → dev), 병합 시 PR 설명의 roadmap 항목 체크, 마일스톤 때 dev → main
- 스키마 변경은 새 Flyway 파일만, PL 리뷰 후 병합
