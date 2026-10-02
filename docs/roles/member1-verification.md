# 팀원1 — PRD 10.3 완료 기준 검증 근거

PRD 10.3 시연 시나리오 중 고객 구간(`customer`, `segment`)이 맡는 항목과, 그 항목을 확인하는 자동 테스트·수동 절차를 모은다.
W5 운영 재검증(roadmap 3장)은 이 표의 "운영 확인" 열을 따라 한다. 테스트 경로는 `withus_backend/src/test/java/com/withus/` 기준.

## 1. 팀원1 단독으로 검증되는 항목

| PRD 10.3 항목 | 자동 테스트 | 운영 확인 (W5) |
|---|---|---|
| CSV로 고객 100명 업로드 후 성공/실패 건수가 표시된다 | `customer/CustomerUploadApiTest#신규_갱신_수신거부_실패를_행별로_처리하고_성공_행은_저장한다`(신규·갱신·수신거부·행별 실패 사유), `#만_행을_30초_안에_넣고_다시_올리면_모두_갱신한다`(1만 행 2.3초, roadmap W2) | `/customers` 업로드 모달 → 양식 xlsx 받기 → 100행 파일 업로드 → 성공·실패 건수와 행별 사유 표시 |
| "서울·경기, 구매액 10만 원 이상" 세그먼트를 만들고 대상 수가 미리보기된다 | `segment/SegmentApiTest#PRD_10_3_서울_경기_구매액_10만원_이상_미리보기`, `#지역_IN_은_삭제_고객을_빼고_미리보기_4개_숫자를_한번에_센다` | `/segments/new` 에서 조건 입력 → 대상 수 미리보기(local 시드 기준 35명, DB_SCHEMA 9장) |
| 수신거부 링크를 열기만 하면(GET) 처리되지 않고, 버튼을 눌러야 처리된다 | `customer/UnsubscribeApiTest#링크를_열기만_하면_아무것도_바뀌지_않고_연락처를_보여주지_않는다`, `#고른_채널만_거부하고_다시_보내도_이력은_한_번만_남는다` | 받은 메일의 수신거부 링크 열기 → 동의 그대로 → 버튼 → 완료 화면·동의 N |
| 삭제된 고객과 같은 이메일로 다시 등록되고, 과거 수신거부 이력이 있으면 동의 N으로 등록된다 | `customer/CustomerApiTest#삭제한_고객의_이메일로_다시_등록하면_새_고객이다`, `#suppression_에_있는_채널은_동의를_N으로_저장한다`, `customer/UnsubscribeApiTest#삭제된_고객의_링크도_값으로_거부되고_같은_이메일로_다시_등록한_고객도_N` | 수신거부한 고객 삭제 → 같은 이메일로 등록 → 이메일 동의 N, 응답 `suppressedChannels` |
| 수신거부한 고객은 관리자가 증빙과 함께 동의 Y로 바꿀 때만 다시 발송 대상이 된다 | `customer/CustomerConsentApiTest#수신거부된_채널은_증빙_없이_Y로_바꿀_수_없고_증빙이_있으면_해제한다`, `customer/CustomerUploadApiTest#휴대폰_칸을_비워도_기존_번호가_수신거부면_SMS_동의는_N_유지`(업로드로 해제 안 됨) | 고객 상세 동의 변경: 증빙 없이는 변경 불가(화면 버튼 비활성·API 422), 증빙 입력 → Y·이력에 증빙 |
| 대문자 이메일(Foo@A.com)로 업로드해도 기존 고객(foo@a.com)과 같은 사람으로 처리된다 | `customer/CustomerUploadApiTest#신규_갱신_수신거부_실패를_행별로_처리하고_성공_행은_저장한다`(대문자 이메일 행), `customer/CustomerNormalizerTest#이메일은_소문자와_trim` | 기존 고객 이메일을 대문자로 바꾼 CSV 업로드 → 갱신 1건(신규 아님) |
| 하이픈이 있는 휴대폰 번호와 없는 번호가 수신거부 목록과 똑같이 비교된다 | `customer/CustomerApiTest#하이픈_휴대폰도_수신거부_목록의_숫자_번호와_같게_비교한다_PRD_10_3`, `customer/CustomerUploadApiTest#하이픈_휴대폰도_수신거부_목록의_숫자_번호와_같게_비교한다_PRD_10_3` (backend #45), `customer/CustomerNormalizerTest#휴대폰은_숫자만` | 수신거부 목록에 있는 번호를 하이픈 넣어 등록 → SMS 동의 N |
| 기존 고객을 CSV로 다시 올려도 등록된 구매로 쌓인 누적구매액이 줄지 않는다 | `customer/CustomerUploadApiTest#신규_갱신_수신거부_실패를_행별로_처리하고_성공_행은_저장한다`("누적구매액은 파일 값(0)으로 바뀌지 않는다"), `customer/CustomerApiTest#수정은_누적구매액과_수신동의를_바꾸지_않는다` | 구매 등록한 고객을 누적구매액 0으로 다시 업로드 → 금액 그대로 |

## 2. 다른 구간과 함께 검증되는 항목 (팀원1 몫만 표시)

| PRD 10.3 항목 | 팀원1 몫 | 근거 | 함께 확인할 사람 |
|---|---|---|---|
| 수신거부 후 해당 고객에게 더 이상 발송되지 않는다 | 수신거부 처리(suppression + 동의 N), 발송 가능 판정 `ConsentService.isSendable`·`filterSendable` | `customer/UnsubscribeApiTest`(처리), `customer/ConsentServiceTest#수신거부_목록에_있으면_동의_Y_여도_불가_다른_채널은_영향_없음`, `#여러_고객_일괄_판정은_건별_판정과_같다` | 팀원2 (적재·발송 직전 재확인 `campaign/SendDispatcherTest#적재_후_수신거부한_고객은_발송_직전_재확인에서_SKIPPED가_된다`) |
| 적재 후 발송 전에 수신거부한 고객에게는 발송되지 않는다(SKIPPED) | 위와 같음 — 수신거부 즉시 `isSendable` 이 false | 위와 같음 | 팀원2 |
| 관리자가 구매를 등록하면 누적구매액이 늘고, `PURCHASE_GTE` 분기와 전환율에 반영된다 | 구매 등록·누적구매액, 쿠폰 선택 시 `CouponService.markUsed` 호출 | `customer/PurchaseApiTest#구매를_등록하면_누적구매액에_더하고_최신순으로_보여준다`, `#쿠폰은_이_고객_발급분_미사용_구매일이_유효기간_안일_때만_쓸_수_있다` | 팀원2 (`PURCHASE_GTE` 분기), 팀원3 (전환율) |
| 동의 일시를 2년 전으로 바꾼 테스트 고객에게 수신동의 확인 안내가 발송된다 | F-12 배치: 대상 선정·NOTICE 적재·`consent_notified_at` 갱신 | `customer/ConsentNoticeBatchTest` 10건 (backend #40, 리뷰 중) | 팀원2 (NOTICE 본문 렌더링·08:00~20:50 보류, F-04 작업) — 렌더링 병합 전에는 `withus.scheduler.consent-notice.enabled=false` |
| 이름이 없는 고객에게 "안녕하세요 고객님"처럼 기본값으로 발송된다 | 이름을 비워 둘 수 있는 등록·업로드 | `customer/CustomerNormalizerTest#선택_항목의_빈_값은_null`(등록·업로드 공용 정규화) | 팀원3 (렌더러 기본값), 팀원2 (발송) — local 시드 25·50·75·100번은 이름 없음 |
| 발송 큐가 10만 건 처리 중이어도 휴면 배치 등 다른 스케줄 작업이 멈추지 않는다 | 휴면 배치·F-12 배치는 `fixedDelay` 10분, 03시 이후 그날 첫 회차 | `customer/DormantBatchTest#새벽_3시_이후_그날_첫_회차에만_실행한다` | PL (스케줄러 스레드 풀 `spring.task.scheduling.pool.size=5`), 팀원2 (발송 작업) |
| 반송·스팸신고 (PRD 8.2 SES 웹훅, 10.3 운영 시나리오 전제) | 서명 검증, suppression·동의 N, 영구 반송은 send_log BOUNCED | `customer/SesWebhookTest` 7건 | PL (W5 SNS 구독 URL·`SES_TOPIC_ARN`) |

## 3. 로컬 수동 확인 절차

준비: `cd infra && docker compose up -d` → 백엔드 `./mvnw spring-boot:run -Dspring-boot.run.profiles=local`(시드 `R__seed_local.sql` 자동 적용) → 프론트 `npm run dev` → `http://localhost:3000` 에 `infra/.env` 의 `OWNER_EMAIL`/`OWNER_PASSWORD` 로 로그인.

| # | 화면 | 절차 | 기대 결과 |
|---|---|---|---|
| 1 | `/customers` 업로드 | 양식 xlsx 받기 → 100행(정상 95, 이메일 형식 오류·지역 오류 등 5) 업로드 | 성공 95·실패 5, 실패 행 번호와 사유 |
| 2 | `/customers` 업로드 | 1의 고객 중 1명을 대문자 이메일·누적구매액 0으로 다시 업로드 | 갱신 1, 누적구매액 그대로 |
| 3 | `/segments/new` | 지역 IN 서울·경기 AND 구매액 ≥ 100,000 | 미리보기 35명(시드만 있을 때) |
| 4 | `/customers/[id]` | 동의 변경 → 동의 이력 | 변경 1건당 이력 1건, 같은 값이면 이력 없음 |
| 5 | `/customers/[id]` | 수신거부된 채널을 증빙 없이 Y → 증빙 입력 후 Y | "수신거부 이력" 표시, 증빙 없이는 변경 버튼 비활성(API 는 422), 증빙 입력 후 해제·이력에 증빙 |
| 6 | `/customers/[id]` 구매 | 구매 등록(쿠폰 없이 / 이 고객 쿠폰 선택) | 누적구매액 증가, 구매 이력 최신순, 쿠폰 사용 처리 |
| 7 | `/unsubscribe/[token]` | Mailpit(`http://localhost:8025`) 받은 메일의 수신거부 링크 열기 → 채널 선택 → 버튼 | 열기만 해서는 동의 그대로, 버튼 후 완료 화면·처리 일시(서울 시간), 고객 상세 동의 N |
| 8 | 고객 등록 | 7에서 수신거부한 번호를 하이픈 넣어 새 고객으로 등록 | SMS 동의 N, `suppressedChannels` 에 SMS |

7은 캠페인 발송(팀원2 #31) 병합 후 실제 메일로 확인한다. 그 전에는 `UnsubscribeApiTest`(서명된 토큰으로 GET/POST) 결과로 대신한다. 수동 확인 결과는 아래에 날짜와 함께 남긴다(task20).

### 수동 확인 결과

| 날짜 | 확인한 # | 결과 |
|---|---|---|
| 2026-10-02 | 1 | 통과 — 100행 중 신규 95·실패 5, 행 번호(헤더 포함 97~101)와 사유(이메일·지역·날짜·휴대폰·수신동의 값) 표시 |
| 2026-10-02 | 2 | 통과 — 대문자 이메일·누적구매액 0 재업로드: 신규 0·갱신 1, 누적구매액 46,000원 유지, 이메일 동의는 파일 값 N 반영 |
| 2026-10-02 | 3 | 통과 — 37명 = 시드 35명 + 10-01 화면 테스트 업로드 고객 2명(`ui-seoul@`·`ui-gg@upload.local`) |
| 2026-10-02 | 4 | 통과 — 이메일 동의 → 거부, 이력 1건(관리자·메모) |
| 2026-10-02 | 5 | 통과 — 수신거부 기록은 DB 에 직접 넣어 준비(실제 링크는 #31 이후). 증빙 없이 버튼 비활성, 증빙 후 Y·suppression 해제·이력에 증빙 |
| 2026-10-02 | 6 | 통과 — 45,000원 등록 → 누적구매액 1,000 → 46,000원, 구매 이력(서울 시간). 쿠폰 선택은 발급 쿠폰이 없어 자동 테스트로 대신 |
| 2026-10-02 | 7 | 보류 — 캠페인 발송(팀원2 #31) 병합 후 |
| 2026-10-02 | 8 | 통과 — `010-5555-9999` 등록, suppression `01055559999` 와 일치 → SMS 동의 N, "과거 수신거부 이력이 있어 해당 채널은 수신거부로 등록했습니다." 안내, 숫자만 저장 |

리허설 중 화면 콘솔 오류 없음. 고객 구간 버그 없음. 공통 영역 발견 1건: backend 이슈 #46(local 시드가 운영 Flyway 스캔에 포함될 수 있음, PL 담당).

## 4. 운영 재검증 전 준비 (W5)

배포는 PL 이 하고, 고객 구간이 동작하려면 아래가 맞아야 한다.

**환경변수**
- `SES_TOPIC_ARN` — SES 반송·스팸신고 SNS 토픽 ARN. **비우면 웹훅이 모든 요청을 무시**한다(로그 `SES 웹훅: 등록하지 않은 토픽 무시`). `TECH_STACK.md` 의 옛 이름 `SES_SNS_TOPIC_ARN` 은 쓰지 않는다(withus_project #18)
- `HMAC_SECRET` — 수신거부 토큰 서명 키, 32자 이상, 운영 필수. 바꾸면 그 전에 나간 메일의 수신거부 링크가 모두 "유효하지 않은 링크"가 된다
- `WITHUS_SCHEDULER_CONSENT_NOTICE_ENABLED` — F-12 배치. 기본 `false`. 팀원2 NOTICE 렌더링이 병합되고 local Mailpit 확인(task24)이 끝난 뒤 `true`

**SES → SNS → 웹훅 연결 (PL)**
1. SES 인증 발신 주소의 **Feedback notifications** 에서 Bounce·Complaint 를 SNS 토픽으로 보낸다(backend #24 PL 리뷰)
2. 토픽에 HTTPS 구독 `https://<Amplify 주소>/api/webhooks/ses` 추가 — Next.js rewrites `/api/*` 가 백엔드로 넘긴다
3. **Raw message delivery 는 끈다.** 웹훅은 SNS 봉투(`Type`·`Message`·`Signature` …)의 서명을 검증한다
4. 구독 확인: 백엔드 로그 `SES 웹훅: SNS 구독 확인 완료 topic=…` 이 남고 SNS 콘솔 구독 상태가 Confirmed. 실패 로그는 `SNS 가 아닌 SubscribeURL 무시`, `서명 정보가 올바르지 않은 요청 무시`, `서명 불일치 요청 무시`

**데이터**
- local 시드(`R__seed_local.sql`)가 운영 DB 에 들어가지 않았는지 — 운영 `flyway_schema_history` 에 `seed local` 행이 없어야 한다(backend 이슈 #46)
- 운영 DB 는 직접 수정하지 않는다(CLAUDE.md 9장). 시연 고객은 `/customers` 업로드로만 넣는다(task22 파일)
- SES 샌드박스라 메일을 받을 고객은 PL 이 인증한 주소만 쓴다

**확인 순서**: 4장 준비 → 시연 데이터 업로드 → 1장 "운영 확인" 열 → 2장(팀원2 캠페인 발송 후) → 3장 7번 수신거부 링크 → SES 반송·스팸신고 실연동
