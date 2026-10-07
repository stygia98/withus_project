# 발송 구간 PRD 10.3 완료 기준 체크리스트 — 근거 대조와 운영 재검증 절차

> 기준: PRD v2.3 10.3(완료 기준)·8.2·8.4, roadmap W4·W5, 발송 큐 Plan 13장(`withus_backend/docs/plans/send-queue-plan.md`)·워크플로우 Plan 9장.
> 담당: 팀원2(발송 구간: `campaign`·`workflow`). 작성일 2026-10-07(백엔드 `dev` b71e806 + PR #87·#88·#89 기준).
> 이 문서는 **PRD 10.3 의 체크박스를 대신 체크하지 않는다.** 체크박스는 PL 이 병합 때 갱신한다(roadmap 머리말). 여기서는 "각 시나리오가 무엇으로 검증되는지"와 "운영(W5)에서 다시 돌릴 절차"를 정리한다.

## 0. 이 문서의 한계 (먼저 읽을 것)

- **근거 대조는 테스트 메서드 이름 기준**이다. 이름이 맞아도 단언이 약할 수 있어, 근거가 약해 보인 곳(시간창 보류·서버 재시작·링크 추적 제외·워크플로우 복구)만 테스트 코드를 직접 열어 확인했다. "충분" 판정도 이름과 일부 코드 확인에 근거한다.
- PL 이 한 **일회성 발송 E2E 점검**은 roadmap(메인 #38) 기록을 따랐고 직접 확인하지 않았다.
- 표의 "local 근거"는 자동 테스트나 측정이다. **운영(EC2·RDS·SES·S3·Amplify) 확인은 아직 하나도 하지 않았다**(W5, 배포 대기).
- 아래 시나리오는 이 구간이 책임지는 21개다. 고객·추적·쿠폰·AI·인증 시나리오(CSV 업로드, 오픈·클릭 반영, 쿠폰 사용 처리, 로그인 등)는 팀원1·3 구간이라 다루지 않는다.

## 1. 요약

| 근거 수준 | 개수 | 항목 번호 |
|---|---|---|
| **충분** — 자동 테스트가 직접 검증 | 17 | 1·2·3·4·5·6·7·8·9·10·12·14·15·17·18·19·20 |
| **부분** — 로직은 검증, 일부가 비어 있음(갭) | 1 | 16(1만 명 소요 시간) |
| **측정** — 자동 테스트가 아니라 수동 측정 도구 | 2 | 13·21 (`LoadQueueCheck`) |
| **대기** — PR 병합 대기 | 1 | 11(NOTICE, 백엔드 #87) |

대조에서 찾은 갭 3개 중 2개는 테스트로 메웠다(병합 전이므로 표에는 "PR 병합 시 충분"으로 적는다). 항목 4(야간 보류)는 판정 로직만 검증되고 `SendDispatcher` 와의 연결(배선)이 비어 있었으나 **백엔드 PR #88 의 `SendDispatcherSendWindowHoldTest`** 로, 항목 7(서버 재시작)은 Plan 13장이 약속한 시뮬레이션 테스트가 없었으나 **백엔드 PR #89 의 `SendDispatcherRestartResumeTest`** 로 보강했다.

## 2. 항목별 근거와 운영 재실행 절차

> 공통 전제(운영 재실행): prod 배포 완료, SES 샌드박스에 시연 수신 주소 인증, `docs/demo/prod-demo-data.md` 절차로 시연 데이터 준비. 광고성 발송은 08:00~20:50 에만 나가므로 시각을 확인한다.

| # | PRD 10.3 시나리오 | local 근거 | 판정 | 운영 재실행 절차 |
|---|---|---|---|---|
| 1 | 일회성 캠페인을 예약하면 지정 시각에 메일이 도착하고 제목에 (광고)가 붙는다 | `CampaignScheduleJobTest`(예약 시각이 지나면 활성화·대상 적재), `AdCopyInserterTest.광고_메일은_제목_앞에_광고_표기가_붙는다`, `MessageComposerTest`(렌더링 조립). PL 의 일회성 발송 E2E 점검(roadmap) | 충분 | 광고 템플릿으로 일회성 캠페인을 가까운 시각에 예약 → 인증된 수신함에서 도착과 `(광고)` 제목 확인 |
| 2 | 6.4 예시 구조 워크플로우가 클릭/미클릭 고객에 따라 다른 메시지를 보낸다 | `Workflow64ExampleIntegrationTest`(클릭 고객은 구매액에 따라 VIP·일반 쿠폰 메일, 미클릭 고객은 SMS 리마인드), `TrackEventRepositoryConditionTest`(봇 제외 판정) | 충분 | 시연 워크플로우(`prod-demo-data.md` 4장) 시작 → 한 고객은 링크를 눌러 클릭, 다른 고객은 두고 대기(WAIT 후) 분기 결과 확인 |
| 3 | 수신거부 후 해당 고객에게 더 이상 발송되지 않는다 | `SendDispatcherTest.적재_후_수신거부한_고객은_발송_직전_재확인에서_SKIPPED가_된다`, `ConsentServiceTest`(수신거부 목록에 있으면 동의 Y 여도 불가) | 충분 | 수신거부 링크 → 확인 화면에서 버튼으로 거부 → 같은 고객 대상 캠페인에서 SKIPPED 확인 |
| 4 | 21시에 광고 메일 예약은 막히고 가능한 시각이 안내되며, 야간에 도달한 워크플로우 광고 발송은 다음 날 08시에 나간다 | 예약 차단: `SendWindowTest.저녁_21시_예약은_막히고_다음날_08시가_안내된다`, `CampaignScheduleApiTest`. 야간 보류 판정: `SendWindowTest.창_종료_후면_다음날_08시로_보류한다` 외. **보류 배선: `SendDispatcherSendWindowHoldTest`(PR #88, 돌연변이 확인)** | PR #88 병합 시 충분 | 20:50 이후 시각에 예약 시도 → 거절과 안내 시각 확인. 야간 보류는 시각 제약 때문에 시연 시점이 허락할 때만 확인(local 테스트로 대체 가능) |
| 5 | 이름이 없는 고객에게 "안녕하세요 고객님"처럼 기본값으로 발송된다 | `MessageComposerTest.이름_없는_고객은_기본값_고객으로_치환된다`, `TemplatePreviewServiceTest`(기본값 표시·인원 집계) | 충분 | 이름 없는 시연 고객 1명 포함 → 받은 메일의 인사말 확인 |
| 6 | 20:50 을 넘겨 끝날 대량 예약은 막힌다(AI 시간대는 팀원3) | `SendWindowTest.evaluateBulk_종료_시각이_정확히_20시50분이면_통과하고_1초_넘기면_막는다` 외 evaluateBulk 시리즈, `CampaignScheduleApiTest` | 충분 | 대상 수를 늘려 예상 종료가 20:50 을 넘는 예약을 시도 → `CAMPAIGN_SEND_WINDOW_EXCEEDED`와 안내 확인(운영 시연에서는 대량 데이터가 없어 local 테스트로 대체 가능) |
| 7 | 발송 도중 서버를 재시작해도 남은 건부터 이어서 발송된다 | 구조: 선점이 즉시 커밋되어 `PENDING`/`SENDING` 이 DB 에 남음(Plan 3.1). 기존: `SendDispatcherTest.dispatch를_다시_불러도_이미_보낸_건은_건드리지_않는다`, `SendRecoveryJobTest`. **`SendDispatcherRestartResumeTest`(PR #89)**: 120건 중 50건 선점·20건 발송 후 강제 종료한 상태를 만들고 재기동 첫 주기를 돌려 ① 보낸 20건 불변 ② SENDING 30건은 재발송 없이 FAILED(UNKNOWN_RESULT) ③ 선점된 적 없던 70건은 이어서 모두 발송을 확인(SMTP 로 수신자 90명 중복 없음 교차 확인, 복구 쿼리를 PENDING 복귀로 바꾸는 돌연변이에서 실패). **한계: 프로세스를 실제로 죽이지는 않고 죽는 순간의 DB 상태를 재현** | PR #89 병합 시 충분 | 대량 캠페인 발송 중 백엔드를 재시작 → 재기동 후 남은 건이 이어서 나가고 이미 보낸 건은 다시 나가지 않음을 `send_log` 상태와 수신함으로 확인 |
| 8 | 같은 일회성 캠페인을 두 번 실행해도 고객당 한 번만 발송된다 | `CampaignScheduleApiTest.같은_캠페인을_두_번_시작해도_고객당_한_건만_적재된다`(부분 유니크 인덱스 `uq_send_log_one_time`) | 충분 | 같은 캠페인에 시작을 두 번 요청(두 번째는 거절 또는 무시) → 고객당 수신 1통 확인 |
| 9 | 쿠폰이 연결된 캠페인 메일에 고객별 쿠폰 링크가 들어간다 | `MessageComposerTest.쿠폰_발급_치환_광고문구_추적_헤더_순서로_조립한다`, `Workflow64ExampleIntegrationTest`(고객별 쿠폰 발급) | 충분 | 쿠폰 연결 캠페인 수신 메일의 `/c/{token}` 링크가 고객마다 다른지 확인(수신 2명) |
| 10 | 광고 SMS 앞에 (광고), 끝에 무료 수신거부 문구가 붙는다 | `AdCopyInserterTest.광고_SMS는_앞뒤에_광고_표기와_무료수신거부_번호가_붙는다`, `TemplatePreviewServiceTest`(바이트 포함) | 충분 | SMS 는 운영에서도 Mock 발송이라 로그(`SmsMockSender`)의 본문으로 확인 |
| 11 | 동의 일시를 2년 전으로 바꾼 테스트 고객에게 수신동의 확인 안내가 발송된다 | `ConsentNoticeCopyTest`, `MessageComposerNoticeTest`, `SendDispatcherNoticeTest`(적재 → 발송 큐 → SENT, 동의 일시 없음 → SKIPPED) — **백엔드 PR #87** | **대기**(PR #87 병합) | **운영 시연에서 제외**(PL 결정 2026-10-07, 이슈 #81): 운영 DB 직접 수정 금지라 동의 일시를 2년 전으로 만들 수 없다. local 시드 99번 + Mailpit 으로 충족하며, `consent-notice.enabled` 는 렌더링 병합과 local 확인 뒤에 켠다 |
| 12 | 6.4 예시 워크플로우에서 경로에 따라 VIP 쿠폰과 일반 쿠폰이 각각 발급된다 | `Workflow64ExampleIntegrationTest.클릭한_고객은_구매액에_따라_VIP_또는_일반_쿠폰_메일을_받는다` | 충분 | 구매액이 다른 시연 고객 2명으로 분기 → 쿠폰 종류 확인 |
| 13 | 10만 건 대량 발송이 쌓여 있어도 신규 가입 환영 메일이 먼저 나간다 | `SendDispatcherTest.priority_1이_3보다_먼저_나간다`, `SendLogMapperTest.선점은_우선순위가_높은_것부터_가져온다`, **`LoadQueueCheck`**(10만 건 규모, 백엔드 #71, PL 환경에서 재현) | 측정 | 운영 규모(10만 건)는 만들지 않는다. `LoadQueueCheck` 결과를 근거로 하고, 운영에서는 대기 건이 있는 상태에서 신규 가입 환영 메일이 먼저 나가는지만 소규모로 확인 |
| 14 | 적재 후 발송 전에 수신거부한 고객에게는 발송되지 않는다(SKIPPED) | 3번과 같은 `SendDispatcherTest.적재_후_수신거부한_고객은_발송_직전_재확인에서_SKIPPED가_된다` | 충분 | 3번 절차와 동일(적재 후 거부 → SKIPPED) |
| 15 | 야간 보류된 메일 뒤의 WAIT 는 실제 발송 시각부터 계산되어 클릭 분기가 정상 동작한다 | `WorkflowWakeupServiceTest.SENT이면_실제_발송_시각_sent_at에_대기시간을_더한다`, `…SKIPPED이면_지금부터_센다`, `WorkflowWakeRecoveryTest`(보정·복구 깨우기) | 충분 | 시각 제약상 운영 확인이 어렵다(야간 보류 필요). local 테스트로 대체 가능 |
| 16 | 1만 명 대상 SEGMENT_SCHEDULED 워크플로우가 한 번의 스케줄 주기 안에서 모두 큐에 적재된다 | `WorkflowTriggerServiceTest.천이백명을_오백건씩_세번에_나눠_TRIGGER_다음_노드로_만든다`, **`WorkflowSegmentScheduledLoadCheck`**(PR #88): local 에서 대상 10,027명, 인스턴스 생성 0.7초 + 엔진 `dispatch()` 1회 17.7초, 전원 COMPLETED, PENDING send_log 10,027건 | **부분** — 건수는 충족, **소요 시간은 환경 민감** | 운영(RDS)에서 이 도구를 한 번 돌려 시간을 확인한다. 엔진이 인스턴스마다 커밋하므로 fsync 가 느린 환경(PL Docker: 회당 150~330ms)에서는 같은 규모가 수십 분일 수 있다(이슈 #73 과 같은 원인). W5 RDS 측정 때 `wal_sync_time` 과 함께 기록 |
| 17 | 처리 도중 서버를 강제 종료해도 RUNNING 인스턴스는 10분 뒤 복구되고, SENDING 건은 다시 나가지 않는다 | `SendRecoveryJobTest.SENDING이_10분_넘게_남으면_FAILED_UNKNOWN_RESULT로_바뀌고_재발송되지_않는다`, `WorkflowInstanceMapperTest.RUNNING으로_10분_넘게_남은_인스턴스는_WAITING으로_복구된다`, `WorkflowWakeRecoveryTest` | 충분 | 운영 확인은 10분을 기다려야 해 시연에서는 local 테스트로 대체 가능 |
| 18 | SES 스로틀링 오류를 흉내 내면 1분·5분·15분 간격으로 재시도된다 | `SendDispatcherRetryTest.일시_오류는_1_5_15분_뒤_재시도하고_네번째는_FAILED`, SES 오류 분류 `SesMessageSenderTest`, **SDK 자체 재시도 없음 `SesMessageSenderRetryTest`**(백엔드 #85: SDK 가 같은 메일을 4번 보내던 경로를 막음) | 충분 | 운영에서 스로틀링을 흉내 내기 어렵다. local 테스트로 대체하고, 실제 SES 응답 분류는 샌드박스 발송으로 확인 |
| 19 | 수신거부 링크와 쿠폰 링크는 추적 주소로 바뀌지 않는다 | `TrackingHtmlRewriterTest.수신거부_링크는_바꾸지_않는다`, `…쿠폰_링크는_바꾸지_않는다`, `…mailto_tel_해시_상대경로_javascript는_바꾸지_않는다`(팀원3 도메인), `MessageComposerNoticeTest`(NOTICE 의 링크 미치환) | 충분 | 받은 메일의 수신거부·쿠폰 링크가 `/unsubscribe/`·`/c/` 원래 주소인지, 일반 링크만 `/t/` 인지 확인 |
| 20 | 테스트 발송은 대시보드 통계에 잡히지 않는다 | `DashboardServiceTest.캠페인_KPI는_봇과_TEST를_빼고_고유_고객으로_센다`, `DashboardServiceTest`(일별 발송에서 TEST 제외), `TrackingEventServiceTest.TEST_발송의_이벤트는_저장되지만_사람_이벤트_조회에서는_제외된다`, 적재 형태는 백엔드 #69 | 충분 | 템플릿 테스트 발송 후 대시보드 수치가 늘지 않는지 확인 |
| 21 | 발송 큐가 10만 건 처리 중이어도 휴면 배치 등 다른 스케줄 작업이 멈추지 않는다 | **`LoadQueueCheck`**(복구·자동 완료 스케줄이 45~47초 안에 정상, 백엔드 #71, PL 환경 재현). 자동 테스트 아님 | 측정 | 운영 규모 부하는 만들지 않는다. `LoadQueueCheck` 결과를 근거로 한다 |

## 3. 갭과 후속

| 갭 | 내용 | 상태 |
|---|---|---|
| 서버 재시작 후 이어서 발송(7) | Plan 13장이 약속한 재시작 시뮬레이션 통합 테스트가 없었다 | **백엔드 PR #89 로 메움**(죽는 순간의 DB 상태를 재현해 재기동 첫 주기를 검증, 실제 프로세스 강제 종료는 아님). 병합 대기 |
| 1만 명 소요 시간(16) | 건수는 충족하나 시간은 환경(fsync)에 크게 좌우됨. 로컬 측정은 1회뿐 | W5 RDS 측정(이슈 #73) 때 `WorkflowSegmentScheduledLoadCheck` 를 함께 실행 |
| NOTICE(11) | 렌더링 PR #87 병합 대기. 병합 뒤 `consent-notice.enabled` 를 켜기 전에 local Mailpit·시드 99번으로 실제 흐름 확인 필요 | PR #87 PL 리뷰 대기 |
| 운영에서 재현이 어려운 항목(4·6·15·17·18) | 야간 보류·10분 복구·스로틀링·대량 예약은 운영에서 시각·대기·규모 때문에 확인이 어렵다 | local 자동 테스트로 대체하자는 **작성자 제안**이며 PL 확인이 필요하다 |

## 4. 운영 재검증 순서 제안 (W5)

1. 배포·SES 인증·시연 데이터 준비(`prod-demo-data.md`) — PL 배포 일정 이후.
2. `application-prod.yml`(`withus.mail.type=ses`, `withus.storage.type=s3`)은 W5 배포 직전에 PL 이 정리한 값 목록으로 반영(이슈 #78).
3. 위 표의 항목 1·2·3·5·8·9·12·19·20 을 운영에서 실행(시각 제약이 없고 소규모로 가능).
4. 4·6·13·15·17·18·21 은 local 자동 테스트와 측정 결과를 근거로 하고, 운영에서는 가능한 것만 소규모 확인.
5. 7 은 운영에서 대량 캠페인 발송 중 백엔드를 재시작해 한 번 더 확인하고(local 은 PR #89 로 충족), 16 은 RDS 시간 측정(이슈 #73)을 한 뒤 결과를 기록.
6. 실제 SES 발송·S3 업로드·공개 URL 접근, 버킷 정책(`images/*` 만 공개 읽기)은 이 체크리스트와 별개로 PL 이 이슈 #78·메인 #26 에서 정리한다.
