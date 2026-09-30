# PL — 공통 기반·통합·배포

- 백엔드 패키지: `auth`, `common`
- 기준: PRD 10.1, 10.2 / roadmap 1·3장
- Flyway 번호 대역: `V1~V9`

## Phase 0 — 시작 기반 (W1 첫 2일)
- [x] 로컬 저장소 3개 `git init` (main)
- [ ] 최초 커밋 → GitHub 원격 3개 생성·push, `dev` 브랜치, 브랜치 보호(직접 push 금지·PR 필수), 팀원 초대
- [x] 메인 저장소: `CLAUDE.md`, `docs/`, `.github/`, `.gitignore`, `infra/docker-compose.yml`(PostgreSQL 17, Mailpit), `infra/.env.example`
- [x] backend 골격(Spring Boot 4.0.8, SpringDoc, 설정·타임존·스케줄러 풀) — 컴파일 확인
- [x] frontend 골격(Next.js 15, shadcn/ui, TanStack Query, sonner, rewrites, `lib/api.ts`, `lib/query-keys.ts`) — lint·build 확인
- [x] `V1__init.sql` 초안(18개 테이블, 부분 유니크 인덱스) — **Docker 기동 후 적용 확인 필요, 전원 ERD 검토 후 확정**
- [x] PRD 10.1 인터페이스 시그니처 초안: `SegmentService`, `ConsentService`, `TrackingLinkService`, `CouponService`, `TrackEventRepository` — **전원 합의 필요**
- [ ] `docs/api/` 도메인별 API 목록 초안 (W1 전원 작업)

## W1
- [ ] 공통 응답 포맷·전역 예외·오류 코드·SpringDoc
- [ ] 로그인/로그아웃/재발급(httpOnly 쿠키), CSRF(`GET /api/v1/auth/csrf`), 5회 실패 잠금
- [ ] 최초 OWNER 계정, 스케줄러 풀(`spring.task.scheduling.pool.size=5`)
- [ ] Next.js 골격: 레이아웃·GNB, rewrites, 공통 fetch 래퍼, `lib/query-keys.ts`
- [ ] **M1**: DDL 적용, 로그인 동작, 인터페이스 합의, Mailpit 발송 1통

## W2
- [ ] 일회성 발송 E2E 통합 테스트 (**M2**)
- [ ] 도메인 구매·DNS 설정 (SES 인증 전 필수)

## W3
- [ ] SES 도메인 인증·프로덕션 액세스 신청, 승인 후 `ses.max-send-rate` 조정
- [ ] 통합 테스트(워크플로우 + 수신거부 + 쿠폰) (**M3**)

## W4
- [ ] PRD 10.3 전체 점검, 코드 리뷰 (**M4**)
- [ ] `infra/aws/` 배포 스크립트

## W5
- [ ] EC2+Nginx+Let's Encrypt, RDS, S3, SES, Amplify, 프록시·쿠키·CSRF 확인, SNS 웹훅
- [ ] 발신자 명칭·연락처·080 번호 실제 값 교체 (**M5**)

## PR 리뷰 우선순위 (사고 시 영향 순)
1. 발송 큐(팀원2) — 중복·누락 발송, 야간 광고 발송
2. 워크플로우 엔진(팀원2) — 멱등성, 멈춤 복구
3. 세그먼트 동적 SQL(팀원1) — SQL 인젝션, 잘못된 대상
4. 수신거부 토큰·처리(팀원1) — 법규, GET 상태 변경

## 상시
- PR 리뷰·병합(feature → dev), 마일스톤 때 dev → main
- 스키마 변경은 새 Flyway 파일만, PL 리뷰 후 병합
