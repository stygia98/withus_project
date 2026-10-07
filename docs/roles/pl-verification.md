# PL — PRD 10.3 완료 기준 통합 점검 기록

PRD 10.3 완료 기준 40개를 `dev`(`b71e806`, 2026-10-07)에서 PL이 통합 점검한 결과다. 팀원별 검증 문서(`member1-verification.md`, `member3-verification.md`)의 자동 테스트 근거를 출발점으로 삼되, 가능한 항목은 **스케줄러를 켠 실제 앱에서 직접 실행**해 다시 확인했다.
W5 운영 재검증(roadmap 3장)은 이 문서의 "W5에 남은 확인"을 따른다. 테스트 경로는 `withus_backend/src/test/java/com/withus/` 기준.

## 1. 결론

| 판정 | 개수 | 항목 번호 |
|---|---|---|
| ✅ 충족 | 31 | 1, 2, 4, 5, 6, 7, 11, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 26, 27, 28, 31, 33, 34, 35, 36, 37, 38, 39, 40 |
| 🟡 충족(일부는 W5 또는 직접 재현 불가) | 6 | 3, 8, 9, 25, 29, 32 |
| ⏳ 조건부·대기 | 2 | 10(배포 보류), 30(환경 의존, 아래 3장) |
| ❌ 미충족 | 0 | 항목 24는 2026-10-07 backend #87 머지로 해소(아래 2장 24번) |
| ➖ 범위 제외 | 1 | 19(A/B, PL 결정 2026-10-06) |

- 현재 `dev` 전체 테스트: **656건 통과, 실패 0건**(Docker PostgreSQL 17 + Mailpit).
- 이 점검에서 앱 결함은 발견하지 못했다. 다만 **정상 종료 때도 발송 중이던 선점분이 누락될 수 있는 설계 보강 사안**을 후속 점검에서 찾아 backend 이슈 #92로 올렸다(3.1). 주의할 점은 3장에, 후속 요청은 backend 이슈 #90·#92에 적었다.

## 2. 항목별 판정

범례: **직접** = PL이 실제 앱(스크래치 DB·Mailpit)에서 실행해 확인. **자동** = 자동 테스트. **실측** = 별도 측정 PR의 결과.

| # | PRD 10.3 항목 | 판정 | 근거 |
|---|---|---|---|
| 1 | CSV로 고객 100명 업로드 후 성공/실패 건수 표시 | ✅ | 직접(`customers-demo.csv` 40행: 성공 36·실패 4), `customer/CustomerUploadApiTest` |
| 2 | "서울·경기, 구매액 10만 원 이상" 세그먼트 미리보기 | ✅ | 직접, `segment/SegmentApiTest` |
| 3 | 일회성 예약 → 지정 시각 도착, 제목 (광고) | 🟡 | 직접(예약 → 스케줄러 자동 시작 → 발송 → 완료 → Mailpit). 운영 SES 도착은 W5 |
| 4 | 메일 열고 링크 누르면 대시보드에 오픈·클릭 반영 | ✅ | 직접(대시보드 숫자를 DB 직접 집계와 대조해 일치), `tracking/` 테스트 |
| 5 | 6.4 워크플로우가 클릭/미클릭별 다른 메시지 | ✅ | 직접(가입 트리거 5명), `workflow/Workflow64ExampleIntegrationTest` |
| 6 | 쿠폰을 `/c/[token]`에서 확인·사용, 전환율 반영 | ✅ | 직접(공개 API), `coupon/CouponConversionFlowTest`. 프론트 화면은 W5 |
| 7 | 수신거부 후 더 이상 발송되지 않음 | ✅ | 직접(일회성·워크플로우 모두) |
| 8 | 21시 광고 예약 차단과 가능 시각 안내, 야간 워크플로우는 다음 날 08시 | 🟡 | 21시 차단은 직접(`CAMPAIGN_SEND_WINDOW_EXCEEDED`, `nextAvailableAt`=다음 날 08:00). 야간 보류는 자동 `campaign/SendWindowTest` 12건 |
| 9 | AI 문구 3안·시간 추천·성과 요약 | 🟡 | 자동(`ai/` Mock LLM), 팀원3이 2026-10-01 실제 Gemini 확인(`member3-verification.md`). 이 점검에서는 재실행 안 함 |
| 10 | W5에 프로필 변경만으로 운영 동작 | ⏳ | 배포 보류(메인 #26) |
| 11 | 수신거부 링크 GET은 처리 안 함, POST만 처리 | ✅ | 직접(GET 후 동의 Y 유지, POST로 동의 N·`suppression`·이력 1건, 재요청 멱등) |
| 12 | 이름 없는 고객에게 기본값 "고객님" | ✅ | 직접(이름 없는 시드 25번으로 미리보기), `common/render/PlaceholderRendererTest` |
| 13 | 삭제 고객 이메일 재등록, 수신거부 이력이면 동의 N | ✅ | 자동 `customer/CustomerApiTest` |
| 14 | 발송 후 10초 이내 클릭은 봇, 지표·분기 제외 | ✅ | 직접(봇 UA 클릭 `bot_yn=Y`가 미클릭 분기로 감, 대시보드 제외), 자동 `tracking/BotDetectorTest` |
| 15 | 20:50 넘겨 끝날 예약 차단, AI는 08~20시만 | ✅ | 직접(예약 차단), 자동 `SendTimeRecommendationServiceTest` |
| 16 | 발송 도중 재시작해도 남은 건부터 이어서 발송 | ✅ | 직접(3장 1번), 자동 `campaign/SendDispatcherRestartResumeTest`(backend #89) |
| 17 | 같은 일회성 캠페인을 두 번 실행해도 고객당 1회 | ✅ | 직접(완료 캠페인 재시작 `CAMPAIGN_INVALID_STATUS`, 중복 0), 자동 `campaign/SendQueueServiceTest` |
| 18 | 추적 URL 토큰 변조 시 이벤트 저장 안 됨 | ✅ | 직접(변조·없는 토큰은 200을 주되 저장 0건) |
| 19 | (A/B) 승자 발송 다음 날 08시 | ➖ | 범위 제외(PL 결정 2026-10-06, 메인 #12) |
| 20 | 쿠폰 연결 메일에 고객별 쿠폰 링크 | ✅ | 직접(고객별 UUID 토큰, 발급 건수 = 발송 건수) |
| 21 | 광고 SMS 앞 (광고), 끝 무료 수신거부 | ✅ | 직접(SMS Mock 본문: `(광고)위드어스 …` + 줄바꿈 + `무료수신거부 080-000-0000`) |
| 22 | 구매 등록 → 누적구매액·`PURCHASE_GTE`·전환율 | ✅ | 직접(구매 등록 후 VIP/일반 분기), 자동 `CouponConversionFlowTest` |
| 23 | '사용하기'는 1회, 열기만 하면 사용 처리 안 됨 | ✅ | 직접(GET 후 `USABLE`, POST 1회 성공, 재사용 `COUPON_ALREADY_USED`) |
| 24 | 동의 일시 2년 전 고객에게 안내 발송 | ✅ | NOTICE 본문 렌더링 backend #87 머지(2026-10-07). PL 이 `consent-notice.enabled=true`로 실제 앱을 띄워 시드 99번(동의 2024-10-06)이 6초 만에 `SENT`가 되고 Mailpit 에 도착함을 확인: 제목 `[위드어스] 수신동의 확인 안내`, 서울 기준 동의 날짜·동의 사실·수신거부 링크, `(광고)`·추적 치환·오픈 픽셀 없음, `List-Unsubscribe` 원클릭 헤더, 수신거부 GET/POST 동작, 대시보드 지표에서 제외. 자동 `ConsentNoticeCopyTest`·`MessageComposerNoticeTest`·`SendDispatcherNoticeTest`. 운영 시연은 제외로 결정(local 에서 충족) |
| 25 | 새로고침 로그인 유지, 토큰 JS 비노출, CSRF 거부 | 🟡 | 직접(`ACCESS_TOKEN`·`REFRESH_TOKEN` 모두 `HttpOnly; SameSite=Lax`, refresh 200, CSRF 없는 변경 요청 403). 브라우저의 `document.cookie` 확인은 W5 |
| 26 | VIP·일반 쿠폰 각각 발급 | ✅ | 직접(VIP 경로 10%, 일반 경로 5,000원), 자동 `tracking/service/CampaignStepsTest` |
| 27 | 10만 건이 쌓여 있어도 환영 메일 먼저 | ✅ | 실측 backend #71(`LoadQueueCheck`) |
| 28 | 적재 후 발송 전 수신거부 → SKIPPED | ✅ | 직접(`NOT_SENDABLE`, 쿠폰 발급 없음), 자동 `campaign/SendDispatcherTest` |
| 29 | 야간 보류 뒤 WAIT는 실제 발송 시각부터 | 🟡 | 직접(WAIT 다음 실행 시각 = `sent_at` + 정확히 60.0초), 야간 보류는 자동 `workflow/WorkflowWakeupServiceTest` |
| 30 | 1만 명 `SEGMENT_SCHEDULED`가 한 번의 스케줄 주기 안에 큐에 적재 | ⏳ | 3장 2번 |
| 31 | 강제 종료 후 RUNNING은 10분 뒤 복구, SENDING은 재발송 안 됨 | ✅ | 직접(3장 1번, RUNNING 11분 방치 → 약 25초 만에 WAITING, `send_log` 중복 없음) |
| 32 | SES 스로틀링 시 1·5·15분 재시도 | 🟡 | 자동 `campaign/SendDispatcherRetryTest`. SES 클라이언트의 자체 재시도는 꺼 두었다(backend #85, `SesMessageSenderRetryTest`). 실제 SES 스로틀링은 W5 |
| 33 | 수신거부·쿠폰 링크는 추적 주소로 바뀌지 않음 | ✅ | 직접(메일 HTML), 자동 `tracking/TrackingHtmlRewriterTest` |
| 34 | 테스트 발송은 대시보드 통계에서 제외 | ✅ | 실측 backend #69, 자동 `DashboardServiceTest` |
| 35 | 수신거부 고객은 증빙 동의 Y일 때만 복귀 | ✅ | 자동 `customer/CustomerConsentApiTest` |
| 36 | 10만 건 처리 중에도 다른 스케줄 작업 정상 | ✅ | 실측 backend #71 |
| 37 | 대문자 이메일 업로드는 동일인 | ✅ | 자동 `customer/CustomerUploadApiTest` |
| 38 | 하이픈 휴대폰도 수신거부 목록과 동일 비교 | ✅ | 자동 `customer/CustomerApiTest`, `CustomerUploadApiTest` |
| 39 | CSV 재업로드해도 누적구매액 유지 | ✅ | 자동 `customer/CustomerUploadApiTest`, `CustomerApiTest` |
| 40 | 로그인 5회 연속 실패 후 잠금 | ✅ | 직접(6번째 시도부터 `AUTH_ACCOUNT_LOCKED`, 잠금 중에는 올바른 비밀번호도 거부), 자동 `auth/AuthFlowTest` |

## 3. 주의할 점

### 3.1 강제 종료·정상 종료 시 선점분 누락 (항목 16, 31)
`SendDispatcher`는 우선순위 순으로 최대 50건을 `SENDING`으로 선점한 뒤 속도 제한에 맞춰 한 건씩 보낸다. 120명 캠페인을 보내다 프로세스를 강제 종료하고 재시작한 결과:

| 상태 | 건수 | 이후 |
|---|---|---|
| `SENT` | 16 | 유지 |
| `PENDING` | 70 | 재시작 후 **모두 이어서 발송**(SENT 86까지) |
| `SENDING`(선점만 되고 못 보냄) | 34 | 재발송 안 됨, 10분 뒤 `FAILED(UNKNOWN_RESULT)` |

중복 수신은 0건이다. 이는 PRD 8.2 5번("중복 발송보다 누락이 낫다")대로의 동작이지만, 초당 1건인 SES 샌드박스에서는 선점 50건이 약 50초치라 한 번의 강제 종료로 그만큼 누락될 수 있다. 이 동작은 backend #89(`SendDispatcherRestartResumeTest`)가 "죽는 순간의 DB 상태"를 재현하는 자동 테스트로 고정했다(PL 이 실제 프로세스를 강제 종료해 본 결과와 같은 모양).

**정상 종료도 안전하지 않다(후속 점검, 2026-10-07).** `SendDispatcher`에는 인터럽트를 받으면 미처리 선점분을 `PENDING`으로 되돌리는 코드(`revertUnprocessed`)가 있고, backend #91이 이 경로를 인터럽트를 직접 걸어 테스트로 보장한다. 그러나 실제 컨텍스트 종료(`close()`)를 재현하는 탐침으로 확인한 결과는 다르다.

| 시나리오 | `close()` 소요 | 종료 후 상태 |
|---|---|---|
| 8건 적재(진행 중 묶음이 30초 안에 끝남) | 7초 | `SENT` 8 — 인터럽트 없이 **끝까지 보내고** 닫힘 |
| 60건 적재(선점 50건, 1건/초라 50초치) | **30초** | `SENT` 28 / **`SENDING` 22** / `PENDING` 10 |

60건 쪽 로그는 `Shutdown phase ... ends with 1 bean still running after timeout of 30000ms: [taskScheduler]` 직후 `HikariPool-1 - Shutdown initiated`였다. Spring 종료 단계 기본 제한(30초) 안에 스케줄러가 끝나지 않으면 **스케줄러가 도는 채로 DB 풀이 먼저 닫혀**, 이후 `revertUnprocessed`의 DB 호출이 실패하고 선점분이 `SENDING`으로 남아 10분 뒤 `UNKNOWN_RESULT`가 된다. 즉 #91의 복귀 경로는 이 조건의 실제 정상 종료에서는 도달하지 못한다. 영향은 발송 중에 재시작할 때 최대 약 20건 누락(중복 없음)이며, 해결 방향은 backend 이슈 #92에 적었다(종료 신호를 먼저 받아 DB가 살아 있는 동안 선점분을 `PENDING`으로 복귀). 따라서 **재시작은 발송이 끝난 뒤에 한다.**

또 #91의 통합 테스트(`SendDispatcherInterruptRevertTest`)는 건당 처리가 1초를 넘는 환경(PL 환경)에서 `TokenBucket` 대기가 생기지 않아 결정적으로 실패해 변경을 요청했고, 느린 버킷을 끼우는 수정안을 검증해 전달했다.

### 3.2 1만 명 SEGMENT_SCHEDULED 적재 시간 (항목 30)
- 10,027명 대상 워크플로우 시작: 인스턴스 10,027개 생성은 요청 안에서 2.6초, 이후 엔진이 500건 묶음을 한 번의 스케줄러 호출 안에서 끊김 없이 이어 처리해 **전원 `send_log` 적재, 고객당 1건, 중복 0**.
- 다만 이 컴퓨터(Docker 볼륨의 디스크 fsync가 건당 약 150~330ms)에서는 **1,025초(초당 10.5건)** 가 걸렸다. 인스턴스마다 트랜잭션을 따로 커밋하는 구조라 backend 이슈 #73에서 확인한 fsync 병목의 영향을 그대로 받는다.
- PRD의 "한 번의 스케줄 주기 안"이 60초 이내인지, 한 번의 스케줄러 호출 안에서 모두 처리되면 되는지가 모호하다. PL 해석은 후자(한 번의 호출 안에서 중단 없이 전원 처리)이고, 소요 시간 목표는 W5 RDS 측정값을 본 뒤 정한다. 이 규모의 측정 도구는 backend #88(`WorkflowSegmentScheduledLoadCheck`)로 추가됐고, 작성자 환경에서는 17.7초(초당 568건)였으나 PL 환경에서는 같은 규모가 1,025초(초당 10.5건)로 디스크 fsync 에 좌우된다. W5 RDS 에서 같은 도구로 비교한다.

### 3.3 프론트 화면은 API까지만 (항목 6, 25)
공개 페이지(`/c/[token]`, `/unsubscribe/[token]`) 렌더링과 브라우저의 `document.cookie`·`localStorage` 비노출은 이 점검에서 API·쿠키 속성까지만 확인했다. 쿠키 `Secure`는 기본 true이고 `local` 프로필에서만 꺼져 있다. 브라우저 확인은 W5 운영 재검증에서 한다.

## 4. 점검 방법과 재현

- 스케줄러가 켜진 실제 앱(`local` 프로필)을 **스크래치 DB**(`CREATE DATABASE`로 새로 만들어 Flyway 적용)에서 별도 포트로 띄우고 API로 실행했다. 사용자 DB·Mailpit의 기존 메일은 건드리지 않았고, 테스트 수신자 도메인(`*.withus.test`)의 메일만 검색 삭제했다.
- 시드 `[시연] 신규 고객 환영 여정`(가입 트리거)은 대상 외 발송을 막으려고 먼저 일시정지했다.
- 한글이 든 JSON을 Windows에서 `curl` 인자로 직접 넘기면 코드페이지 때문에 깨지므로 파일로 넘긴다.
- 강제 종료 점검은 스크래치 DB의 `send_log.updated_at`을 11분 전으로 조작해 "10분 경과"를 흉내 냈다(운영 DB에는 하지 않는다).

## 5. W5에 남은 확인

- 운영 SES 실제 도착, SES 주소 인증, 실제 스로틀링(항목 3, 32)
- S3 업로드와 `images/*` 공개 읽기 정책(backend #86)
- 프론트 공개 페이지와 브라우저 쿠키 확인(항목 6, 25)
- 발송 중 재시작 시 선점분 누락(3.1, backend 이슈 #92): 해결 전에는 배포·재시작을 발송이 끝난 뒤에 한다
- 프로필 전환만으로 운영 동작(항목 10)
- RDS에서 1만 명 적재 시간과 커밋 시간(`EnqueuePhaseCheck`, 항목 30)
- 항목 24는 운영 시연에서 제외하고 local(시드 99번, Mailpit)에서 확인한다
