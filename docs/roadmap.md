# 위드어스 (Withus) 개발 로드맵

> 기준 문서: `docs/prd.md` (PRD v2.3) · 기간 5주(W1~W5) · 인원 4명(PL + 팀원 3명)
>
> 주차(W1~W5)는 **예상 일정**이다. 실제 시작일·소요 시간은 기록하지 않는다. 체크박스는 PL이 PR 병합 시 갱신한다.

일회성 발송을 W2에 먼저 끝까지 연결한 뒤, W3에 워크플로우·수신거부·쿠폰으로 확장하고, W4에 AI와 통합 테스트를 마쳐 기능을 동결한다. W5는 운영 배포와 시연 검증만 한다.

## 1. 팀 구성과 담당

| 담당 | 구간 | 백엔드 패키지 | 핵심 책임 |
|---|---|---|---|
| PL | 공통 기반·통합·배포 | `auth`, `common` | 저장소·인프라·Flyway 초기화, 로그인/JWT/CSRF, 사용자 관리, 공통 응답·예외, SpringDoc, Next.js 골격, 통합 테스트, 도메인·SES·AWS 배포 |
| 팀원1 | 고객 | `customer`, `segment` | 고객 CRUD·CSV 업로드·정규화, 수신동의·동의 이력, 세그먼트 빌더, 수신거부 페이지·`suppression`, SES 반송 웹훅, 휴면 배치, 수신동의 2년 안내(F-12), 구매 등록 |
| 팀원2 | 발송 | `campaign`(템플릿 포함), `workflow` | 템플릿 에디터·이미지, 캠페인, 일회성 발송, **공통 발송 큐**(우선순위·속도 제한·재확인·재시도), `MessageSender`, 워크플로우 엔진·빌더, A/B(선택) |
| 팀원3 | 전환 | `tracking`, `coupon`, `ai` | 오픈/클릭 추적·봇 판정, 쿠폰·고객 페이지(`/c/[token]`), 대시보드·성과 리포트, AI-01~03, Gemini 클라이언트 |

## 2. 마일스톤

| 마일스톤 | 시점 | 완료 조건 |
|---|---|---|
| M1 기반 완성 | W1 금 | DDL(Flyway V1) 전체 적용, 로그인 동작, 도메인 간 인터페이스·API 계약 합의, Mailpit으로 메일 1통 발송 |
| M2 일회성 발송 E2E | W2 금 | CSV 업로드 → 세그먼트 → 템플릿 → 예약 발송 → 오픈·클릭이 대시보드에 반영 |
| M3 핵심 기능 완성 | W3 금 | 워크플로우(6.4 예시) 동작, 수신거부·`suppression`, 쿠폰 발급·사용, SES 신청 완료 |
| M4 기능 동결 | W4 금 | AI 3종·F-12 완료, PRD 10.3 완료 기준 로컬 통과, 이후 버그 수정만 허용 |
| M5 운영 시연 | W5 금 | 프로필 변경만으로 AWS에서 10.3 시나리오 전체 통과 |

## 3. 주차별 계획

### W1 — 기반과 계약

**목표:** 모두가 같은 스키마와 API 계약 위에서 병렬로 개발할 수 있게 한다.

**공통 (첫 2일, 전원)**
- [x] PRD 7장 기준 ERD 확정, Flyway `V1__init.sql` 작성 (18개 테이블, 부분 유니크 인덱스 포함)
- [x] PRD 10.1 구간 간 연결 인터페이스 시그니처 확정 (`SegmentService`, `ConsentService`, `TrackingLinkService`, `TrackEventRepository`, `CouponService`, `PlaceholderRenderer`)
- [x] 도메인별 API 목록 초안을 `docs/api/`에 작성 (`docs/api/API_SPEC.md`)

**PL**
- [x] 메인 저장소·`infra/docker-compose.yml`(PostgreSQL 17, Mailpit), 백엔드·프론트 저장소 골격
- [x] 공통 응답 포맷, 전역 예외 처리, 오류 코드 체계, SpringDoc 설정
- [x] 로그인/로그아웃/토큰 재발급(httpOnly 쿠키), CSRF(`GET /api/v1/auth/csrf`), 로그인 5회 실패 잠금
- [x] 최초 OWNER 계정 생성, 스케줄러 스레드 풀 설정
- [x] Next.js 골격: rewrites(`/api/*`), 공통 fetch 래퍼, `lib/query-keys.ts`, 로그인 화면
- [x] 레이아웃·GNB·인증 가드 (목업: `docs/design/mockups/`) (frontend #8 — 디자인 토큰, 30분 후 로그아웃 버그 수정 포함)
- [x] 사용자 관리 API(`/api/v1/members`)·화면(`/settings/users`) (backend #26, frontend #9)

**팀원1**
- [x] 고객 CRUD API·화면, 입력값 정규화 유틸(이메일·휴대폰·지역·날짜) + 단위 테스트 (backend #2, frontend #1 — 레이아웃은 PL 작업 후 자동 적용)
- [x] 수신동의 변경과 `consent_history` 기록 (backend #2)
- [x] **(W1 최우선)** `SegmentService`·`ConsentService` 임시 구현(stub) 먼저 병합 — 팀원2가 기다리지 않게 → stub 대신 실제 구현으로 대체: `ConsentService`(backend #5), `SegmentService` 1차(backend #3)

**팀원2**
- [x] 템플릿 CRUD API·화면(최소 기능), TinyMCE 연동, `FileStorage`(로컬) 이미지 업로드 — API·이미지 업로드(backend #7), 화면·TinyMCE(frontend #11), 렌더링 미리보기 API(backend #47), 광고 문구 직접 입력 금지 검증(backend #57). 후속(frontend #11 🔵7~10, `copy-tinymce` 정리)은 W5 배포 전
- [x] `MessageSender` 인터페이스 + SMTP(Mailpit) 구현, SMS Mock (backend #7)
- [x] **발송 큐 설계 Plan 작성 → PL 리뷰** (W2 착수 전 승인) — 승인 완료(backend #4, 승인 결과 #6)

**팀원3**
- [x] 추적 API(`/t/o/{trackingToken}.gif`, `/t/c/{trackingToken}/{linkId}`), 비동기 이벤트 저장 (backend #12)
- [x] Gemini 클라이언트(개인정보 미전송, 한도 초과 처리), 무료 등급 모델명·한도 확인 (backend #12, 메인 #3)
- [x] **(W1 최우선)** `TrackingLinkService`·`CouponService`·`TrackEventRepository`·`PlaceholderRenderer` stub 먼저 병합 (backend #10)

### W2 — 일회성 발송 끝까지 연결

**목표:** M2. 가장 단순한 경로로 발송·추적 전체 흐름을 검증한다.

**PL**
- [ ] 일회성 발송 E2E 통합 테스트

**팀원1**
- [x] CSV/xlsx 업로드(10,000행, 500행 배치 insert, 행별 결과, `suppression` 반영) (backend #9, frontend #2 — 1만 행 2.3초)
- [x] 세그먼트 조건 빌더: 규칙 JSON → MyBatis 동적 SQL(화이트리스트), 대상 수 미리보기 + 단위 테스트 (backend #3·#8, frontend #2 — 10만 명 미리보기 최대 37ms)

**팀원2**
- [x] 일회성 캠페인 생성·예약, 20:50 컷오프 검사(PENDING 대기분 포함) (backend #31, 시작 경합 #54·재시작 경로 #55 보강, 화면 frontend #15). 후속: 10만 건 시작이 요청 안에서 동기 적재라 DB 왕복이 느린 환경에서 61~64초(이슈 #73, W5 리허설 전 확인)
- [x] 템플릿 테스트 발송 API(F-04, `kind = TEST`, 통계 제외) (backend #69 — 실제 서버로 EMAIL·SMS 발송 후 대시보드 통계 불변 확인, PRD 10.3 "테스트 발송은 대시보드 통계에 잡히지 않는다")
- [x] **공통 발송 큐**: PENDING 적재 → `SENDING` 선점 → 트랜잭션 밖 발송 → SENT/FAILED, 우선순위, 토큰 버킷 속도 제한 (backend #21 — 우선순위는 kind 로 결정, 반송 BOUNCED 는 backend #32·#33, 적재 일괄 동의 판정 `filterSendable` 은 backend #42. SMS 수신처 NPE·테스트 4건은 이슈 #43)
- [x] 발송 직전 재확인, 재시도(1·5·15분), `SENDING` 10분 초과 처리 (backend #21 — 결과 기록 UPDATE 상태 가드, 발송 성공 후 재시도 금지, 건별 실패 격리)
- [x] 발송 시 렌더링: (광고)·발신자·수신거부 삽입, `PlaceholderRenderer`·`TrackingLinkService.rewrite` 연결 (backend #21 — 캠페인 발송 기준. TEST·NOTICE 렌더링은 `send_log.template_id` 추가 후 F-04·F-12 작업에서(#21 PL 결정 B), `{{region}}` 표시명은 backend #41 `Region.displayName()` 적용 대기)

**팀원3**
- [x] 치환자 렌더러 `PlaceholderRenderer`(`{{name|고객}}` 기본값, 시스템 기본값, 미리보기용 기본값 적용 수) + 단위 테스트 — 팀원2에서 이관 (backend #12, HTML 본문용 `renderHtml` 포함)
- [x] 봇 판정(10초, User-Agent 키워드, 1초 내 전체 클릭) (backend #12)
- [x] 메인 대시보드(카드, 활성 캠페인, 10초 폴링 이벤트 로그), 캠페인 성과 차트 (backend #12, frontend #3 — 활성 캠페인 카드는 팀원2 `GET /campaigns` 대기, 기간 필터·쿠폰 발급 현황 backend #30·frontend #10)

### W3 — 워크플로우·수신거부·쿠폰

**목표:** M3. 가장 어려운 워크플로우 엔진을 완성하고 법규 관련 기능을 모두 갖춘다.

**PL**
- [ ] SES 이메일 주소 인증(발신 1개 + 시연 수신 주소), 샌드박스 유지 — 도메인 없음(PRD 10.4)
- [ ] W3 통합 테스트(워크플로우 + 수신거부 + 쿠폰)

**팀원1**
- [x] 수신거부 페이지(GET 확인 / POST 처리), 원클릭 수신거부 API, `suppression` 관리·해제 절차 (backend #22, frontend #7, 메인 #8 — 토큰은 PL 공용 `UnsubscribeTokens`)
- [x] SES 반송·스팸신고 웹훅(SNS 서명 검증, Mock 요청으로 검증) (backend #24, 메인 #9 — 실제 SNS 서명은 W5 배포 후 확인, `send_log` BOUNCED 반영은 backend #33(팀원2 #32 인터페이스), 스팸신고는 send_log 를 SENT 로 유지)
- [x] 휴면 판정 배치(180일 클릭·구매 없음), 구매 등록(`purchase`, 쿠폰 사용 연계) (휴면 배치 backend #15, 구매 등록 backend #14·메인 #4)

**팀원2**
- [x] 워크플로우 엔진 설계 Plan → PL 승인 (backend #20, 승인 결과는 `docs/plans/workflow-plan.md` 11장)
- [x] 워크플로우 빌더(폼 기반) + 구조 검증(분기 2단계, 노드 15개, 순환 금지, SEND 노드별 쿠폰) (구조 검증 API backend #34·#56, 빌더 화면 frontend #15). 후속: 화면에서 생성 → 저장 → 시작 → 인스턴스 현황 흐름 확인(작성자), `InstancesPanel` 시각 표시 1곳 서울 고정
- [x] 워크플로우 엔진: 500건 반복 처리, WAIT(`sent_at` 기준), CONDITION(봇 제외), 멈춤 복구, 멱등성 (backend #35 — PL 환경 전체 테스트 628건 통과). 후속: 단계 캐시(backend #72), CONDITION 대량 판정 dev 재검증(이슈 #51, 메인 #28)
- [x] 캠페인 상태 전이(DRAFT/SCHEDULED/ACTIVE/PAUSED/COMPLETED), 일시정지 시 PENDING 보류 (backend #31·#35, 화면 frontend #15)
- [x] 캠페인 복제 API(PRD 6.7 "일시정지 후 복제") — 구현 backend #35, 통합 테스트 7건 backend #75(복제 연결을 원본 ID로 두는 결함을 넣으면 실패함을 PL 이 확인), API 규칙·오류 코드 메인 #31, 이슈 #62 종료

**팀원3**
- [x] 쿠폰 CRUD(정액·정률·상한, 고정 기간), 발급(`CouponService.issue`), `{{couponUrl}}` 연동 (backend #16, frontend #4 — 발급 멱등·원자적 사용 처리)
- [x] 고객 쿠폰 페이지 `/c/[token]`(카드형, POST 사용 처리, 모바일 대응), 전환 집계 (backend #16, frontend #4)
- [ ] 봇 판정 User-Agent 목록을 실제 메일로 검증·보강 — 공식 문서 사전 조사와 정상 UA 회귀 테스트 완료(메인 #10, backend #30), 판정 규칙을 부분 일치 + 사람 기기 예외 목록(`bot-user-agent-allow-list`)으로 정리(backend #38, 메인 #13), 실제 메일(Gmail·Outlook·Naver) 확인은 W5로 미룸(`docs/roles/member3-verification.md` 4장)

### W4 — AI·통합·기능 동결

**목표:** M4. 남은 기능을 마치고 10.3 완료 기준을 로컬에서 모두 통과시킨다.

**PL**
- [ ] PRD 10.3 완료 기준 전체 점검, 통합 테스트, 코드 리뷰
- [ ] 운영 배포 스크립트 준비(`infra/aws/`), 배포 리허설(Amplify → EC2 프록시 확인)

**팀원1**
- [x] 수신동의 2년 확인 안내(F-12, NOTICE 발송·시간 제한) (backend #40·#49 — 쿨다운 30일 PL 확정)
- [ ] 버그 수정

**팀원2**
- [ ] 워크플로우 안정화(10만 건 적재 부하 확인, 우선순위 검증) — 부하 1/3·2/3 완료(backend #70·#71): 10만 건 대기 중에도 priority 2 가 먼저 나가고(PL 환경 앞질러 나간 priority 3 이 17건 이하) 복구·자동 완료가 멈추지 않음. CONDITION 단계 캐시로 5,000건 판정 DB 왕복 감소(backend #72). 적재 시간(이슈 #73)은 DB 왕복이 아니라 커밋의 WAL fsync 가 좌우함을 PL 환경에서 확인(총 73.7초 중 fsync 53.2초, 디스크 동기 쓰기 150~330ms) — 운영(RDS) 재현 여부는 W5 에서 `EnqueuePhaseCheck`(backend #77)로 확인. 부하 3/3 대기
- [ ] (선택) React Flow 캔버스 — A/B 테스트는 범위에서 제외(PL 결정 2026-10-06, 메인 #12)

**팀원3**
- [x] AI-01 문구 초안 3안, AI-02 발송 시간 추천(08:00~20:00 가드레일은 코드로), AI-03 성과 요약(`ai_report` 저장) (backend #16, frontend #4 — W4 항목 선행 완료)
- [x] 성과 리포트 마무리(단계별 차트, 전환율, 기간 필터, 성과 리포트 목록 `/analytics`) — 단계별·전환율 완료(backend #16, frontend #4), 기간 필터 완료(backend #30·#38, frontend #10·#13, 메인 #10·#13 — 366일 상한·서울 날짜 기준), 목록 `/analytics`는 frontend #16. A/B 비교는 A/B 기능 제외로 뺌(PL 결정 2026-10-06, 메인 #12)
- [x] 여유 시 팀원2 워크플로우 안정화 지원(부하 데이터 생성, CONDITION 조회 검증) (backend #30, 메인 #10 — send_log 10만 건 기준 1건 판정 0.066ms, 인덱스 추가 불필요)

### W5 — 운영 배포와 시연

**목표:** M5. 코드 변경 없이 프로필만 바꿔 운영에서 동작하게 한다.

**PL**
- [ ] EC2(백엔드, 도메인·인증서 없음), RDS PostgreSQL(자동 백업 7일), S3, SES(샌드박스), Amplify(프론트, 기본 주소)
- [ ] rewrites 프록시(`/api/*`, `/t/*`)·쿠키·CSRF 운영 확인, 메일 링크·SNS 웹훅이 Amplify 주소로 동작하는지 확인
- [ ] 발신자 명칭·연락처·080 번호를 실제 값으로 교체

**팀원1·2·3**
- [ ] 각자 구간의 10.3 완료 기준을 운영 환경에서 재검증
- [ ] 시연 데이터 준비(local 시드에 발송·이벤트 예시 추가는 완료 — `db/seed/local/R__seed_local_demo.sql`, backend #65·메인 #25, 메인 #12 결정), 발견된 버그 수정

## 4. 주요 의존 관계

| 선행 작업 | 후행 작업 | 비고 |
|---|---|---|
| Flyway V1·인터페이스 합의 (W1 전원) | 모든 도메인 개발 | W1 첫 2일 안에 끝내야 병렬 작업 가능 |
| 세그먼트 대상 조회 (팀원1, W2) | 일회성 발송·워크플로우 (팀원2) | `SegmentService.findTargetCustomers` |
| 공통 발송 큐 (팀원2, W2) | 워크플로우 SEND, F-12 안내, 쿠폰 발급 | 모든 발송이 큐를 거침 |
| 추적 API·봇 판정 (팀원3, W1~W2) | 워크플로우 CONDITION, 대시보드, 휴면 판정 | `TrackEventRepository` |
| 쿠폰 발급 (팀원3, W3) | 워크플로우 SEND 노드별 쿠폰, 구매 등록 | `CouponService` |
| 인터페이스 stub (팀원1·3, W1 최우선) | 발송 큐 선개발 (팀원2) | 고정값 반환 구현을 먼저 병합하고 실제 구현으로 교체 |
| 치환자 렌더러 (팀원3, W2) | 발송 시 렌더링 (팀원2, W2) | `PlaceholderRenderer` |

## 5. 리스크와 대응

| 리스크 | 대응 |
|---|---|
| 워크플로우 엔진이 W3 안에 끝나지 않음 | W2까지 발송 큐를 완성해 엔진은 노드 실행 로직에만 집중. 치환자 렌더러는 팀원3으로 이관, 선행 인터페이스는 W1 stub. 막히면 PL이 W3 후반 지원, 팀원3이 W4 지원, React Flow는 포기 |
| 도메인 없는 SES 발송이 스팸 처리됨 | W3에 시연 수신 주소를 인증하고 실제 도착을 미리 확인. 불안정하면 Mailpit 녹화로 대체 |
| Amplify → EC2(HTTP) 프록시가 운영에서 동작하지 않음 | W4에 배포 리허설로 `/api/*`·`/t/*` 프록시를 미리 확인 |
| 스키마 변경이 잦아 충돌 | 변경은 새 Flyway 파일로만, PL 리뷰 후 병합 |
| Gemini 무료 한도 초과 | 오류 안내·재시도, 시연 전날 호출량 확인 |
| 봇 판정 오탐으로 지표 왜곡 | W3에 실제 메일(Gmail·Outlook·Naver)로 검증 후 기준 조정 |

## 6. 결정값 교체 일정

| 항목 | 현재(시연용) | 교체 시점 | 담당 |
|---|---|---|---|
| `ses.max-send-rate` | `1` | 유지 (SES 샌드박스 한도) | PL |
| 봇 판정 User-Agent | bot·crawler·spider·scanner·preview | W3 검증 후 | 팀원3 |
| 발신자 명칭·연락처 | 위드어스 / 02-000-0000 | W5 배포 전 | PL |
| SMS 080 번호 | 080-000-0000 | 실제 SMS 연동(O-03) 시 | PL |

## 7. Claude Code 활용 팁

- 작업을 시작할 때 "`docs/prd.md`의 F-03과 7장을 읽고 세그먼트 규칙 JSON → SQL 변환을 구현해줘"처럼 **PRD 섹션 번호를 짚어서** 요청한다.
- 워크플로우 엔진·발송 큐·인증은 Plan 모드로 설계부터 받고, 승인 후 구현한다.
- 기능마다 PRD 10.3의 해당 완료 기준을 테스트로 먼저 만들게 하면 회귀를 막을 수 있다.
- 주차가 끝나면 이 문서의 체크박스를 갱신하고, 바뀐 결정은 PRD에도 반영한다.
