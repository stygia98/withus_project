# 팀원3 — PRD 10.3 완료 기준 검증 근거

PRD 10.3 시연 시나리오 중 전환 구간(`tracking`, `coupon`, `ai`, `common.render`)이 맡는 항목과, 그 항목을 확인하는 자동 테스트·수동 절차를 모은다.
W5 운영 재검증(roadmap 3장)은 이 표의 "운영 확인" 열을 따라 한다. 테스트 경로는 `withus_backend/src/test/java/com/withus/` 기준.

## 1. 팀원3 단독으로 검증되는 항목

| PRD 10.3 항목 | 자동 테스트 | 운영 확인 (W5) |
|---|---|---|
| 메일로 받은 쿠폰을 `/c/[token]`에서 확인하고, 사용 처리하면 전환율에 반영된다 | `coupon/CouponConversionFlowTest` (발급 → GET → POST 사용 → 전환율) | 실제 메일의 쿠폰 링크 → 사용하기 → `/analytics/[id]` 전환율 |
| 고객 페이지의 '사용하기'는 한 번만 되고, 링크를 열기만 해서는 사용 처리되지 않는다 | `coupon/CouponApiTest` (GET 두 번 후 미사용, POST 두 번째 409), `CouponConversionFlowTest` | 휴대폰에서 링크 열기 → 상태 USABLE 유지 → 사용 확정 → 다시 누르면 "이미 사용" |
| 관리자가 구매를 등록하면 … 전환율에 반영된다 (전환율 부분) | `CouponConversionFlowTest`, `coupon/CouponPurchaseDateTest` (구매일 기준 기간) | 고객 상세에서 쿠폰 선택해 구매 등록 → 전환율 |
| AI 문구 3안, 발송 시간 추천, 성과 요약이 동작한다 | `ai/CopyDraftServiceTest`, `ai/AiCopyDraftApiTest`, `ai/service/SendTimeRecommendationServiceTest`, `ai/AiReportApiTest` (Mock LLM) | `GEMINI_API_KEY`로 세 기능 각 1회 호출 (2026-10-01 로컬에서 실제 Gemini 확인함) |
| AI는 08:00~20:00 시간대만 추천한다 (20:50 가드레일 포함) | `SendTimeRecommendationServiceTest` (허용 시간 밖 제외, 가드레일 경계값, 대상 과다 시 빈 목록) | 대상 수를 크게 넣어 20:50 넘는 후보가 빠지는지 |
| 이름이 없는 고객에게 "안녕하세요 고객님"처럼 기본값으로 발송된다 (렌더러 부분) | `common/render/PlaceholderRendererTest#이름이_없는_고객에게_안녕하세요_고객님으로_발송된다_PRD_10_3` | 이름 없는 시드 고객(25·50·75·100번)에게 발송된 메일 확인 |
| 발송 후 10초 이내 클릭은 봇으로 표시되어 클릭률과 워크플로우 분기에서 빠진다 | `tracking/BotDetectorTest` (10초 경계), `tracking/TrackingEventServiceTest` (`existsHumanEvent` 제외), `tracking/service/DashboardServiceTest#캠페인_KPI는_봇과_TEST를_빼고_고유_고객으로_센다` | 발송 직후 바로 클릭 → `track_event.bot_yn = 'Y'`, 대시보드 클릭 수 그대로 |
| 추적 URL의 토큰을 임의로 바꾸면 이벤트가 저장되지 않는다 | `tracking/TrackingEventServiceTest#없는_토큰이나_형식이_잘못된_토큰은_저장하지_않는다`, `tracking/TrackingControllerTest` (응답은 200/302 유지) | 메일 링크의 UUID 한 글자를 바꿔 열기 → 이벤트 없음 |
| 수신거부 링크와 쿠폰 링크는 추적 주소로 바뀌지 않는다 | `tracking/TrackingHtmlRewriterTest#수신거부_링크는_바꾸지_않는다`, `#쿠폰_링크는_바꾸지_않는다` | 받은 메일 HTML에서 두 링크가 원래 주소인지 |
| 테스트 발송은 대시보드 통계에 잡히지 않는다 | `DashboardServiceTest` (KPI·일별 발송·최근 이벤트 모두 TEST 제외) | 테스트 발송 후 대시보드 숫자 변화 없음 |

## 2. 다른 구간과 함께 검증되는 항목 (팀원3 몫만 표시)

| PRD 10.3 항목 | 팀원3 몫 | 근거 | 함께 확인할 사람 |
|---|---|---|---|
| 메일을 열고 링크를 누르면 대시보드에 오픈·클릭이 반영된다 | 추적 API·이벤트 저장·대시보드 집계 | `TrackingControllerTest`, `TrackingEventServiceTest`, `DashboardServiceTest#최근_이벤트는_…` | 팀원2 (실제 발송·링크 치환 연결) |
| 쿠폰이 연결된 캠페인 메일에 고객별 쿠폰 링크가 들어간다 | `CouponService.issue` 멱등·발송 1건당 1건 | `coupon/CouponServiceIdempotencyTest` (동시 호출 포함) | 팀원2 (`{{couponUrl}}` = `withus.tracking.base-url` + `/c/` + 토큰) |
| 6.4 예시 워크플로우에서 경로에 따라 VIP 쿠폰과 일반 쿠폰이 각각 발급된다 | SEND 노드별 `couponId`로 발급, 단계별 성과에 쿠폰 표시 | `CouponServiceIdempotencyTest`, `tracking/service/CampaignStepsTest` | 팀원2 (워크플로우 엔진) |
| 관리자가 구매를 등록하면 누적구매액이 늘고 … | `CouponService.markUsed` (미사용만 확인, 기간은 구매일로 호출 쪽 판정) | `CouponPurchaseDateTest` | 팀원1 (구매 등록·누적구매액·`PURCHASE_GTE`) |
| W5에 프로필 변경만으로 운영 환경에서 위 시나리오가 동작한다 | `withus.ai.type`(gemini/mock), `TRACKING_IP_SALT`, `withus.tracking.base-url` | `ai/AiConfigTest` | PL (배포) |

## 3. W5 운영 재검증 점검표

### 3.1 배포 전 설정 (팀원3 구간이 읽는 값)

기준은 `withus_backend/src/main/resources/application.yml`이다. 아래 값은 **비어 있어도 서버가 뜬다.** 그래서 기동이 됐다고 설정이 맞는 것은 아니며, 3.2의 확인으로 잡아야 한다.

| 환경변수 | 운영 값 | 비어 있거나 틀리면 | 확인 (3.2) |
|---|---|---|---|
| `WITHUS_PUBLIC_BASE_URL` | Amplify 주소 (`https://…`, 끝에 `/` 없이) | 기본값 `http://localhost:8080`으로 메일이 나가, 수신자 쪽에서 오픈 픽셀·추적 링크·쿠폰 링크(`/c/…`)가 모두 열리지 않는다 | 2번 |
| `TRACKING_IP_SALT` | 32자 이상 임의 문자열 (비밀값) | 솔트 없이 IP를 해시한다. 판정에는 쓰지 않지만 해시가 쉽게 역산된다 | 배포 전 값 존재 확인 |
| `GEMINI_API_KEY` | AI Studio 키 (비밀값) | 기동은 되고, AI-01·02·03을 호출하면 `AI_UNAVAILABLE`, 로그 `GEMINI_API_KEY 가 설정되지 않아…` | 8번 |

- `withus.ai.type`은 `application.yml`에 `gemini`로 고정되어 있다. `WITHUS_AI_TYPE`은 `application-local.yml`에서만 읽으므로 **운영(prod)에서는 넣어도 효과가 없다.**
- 봇 판정 키워드와 예외 목록은 기본값 그대로 배포한다. 4장 확인 결과로 바꿔야 하면 환경변수 `WITHUS_TRACKING_BOTUSERAGENTKEYWORDS`, `WITHUS_TRACKING_BOTUSERAGENTALLOWLIST`(Spring 완화 바인딩, 쉼표 구분)로 넣거나 `application.yml`을 고치는 PR을 올린다. 키워드는 부분 일치라는 점(4장)을 기준으로 고른다.

### 3.2 운영 확인 순서

운영 SES와 인증된 수신 주소를 쓴다. 3번까지는 다른 구간 발송이 연결된 뒤 바로 하고, 나머지는 시연 전날 다시 한다.

| # | 확인 | 기대 결과 | 관련 1·2장 항목 |
|---|---|---|---|
| 1 | Amplify 주소로 `/t/o/{임의 UUID}.gif`, `/t/c/{임의 UUID}/1` 열기 | 각각 200 gif, 302 리다이렉트. `track_event`에 새 행 없음. Amplify → EC2 `/t/*` 프록시와 위조 토큰 규칙이 함께 확인된다 | 토큰을 바꾸면 이벤트 없음 |
| 2 | 테스트 발송 1통 → 받은 메일 원문(HTML) 보기 | 픽셀·링크가 `WITHUS_PUBLIC_BASE_URL/t/…`로 시작한다. 수신거부·쿠폰 링크는 추적 주소로 바뀌지 않는다. 대시보드 숫자 변화 없음 | 링크 치환 제외, TEST 제외 |
| 3 | 4장 실제 메일 확인 절차 (Gmail·Outlook·네이버) | 자동 요청의 UA·`bot_yn`·경과 시간 기록. 사람 열람·클릭은 `bot_yn = 'N'` | 봇 판정 |
| 4 | 캠페인 메일을 열고 링크 클릭 | 10초 폴링 안에 대시보드 오픈·클릭과 최근 이벤트에 반영 | 오픈·클릭 반영 |
| 5 | 발송 직후 10초 안에 링크 클릭 | `bot_yn = 'Y'`, 클릭 수는 그대로 | 10초 봇 |
| 6 | 휴대폰에서 쿠폰 링크 열기 → 사용하기 → 다시 누르기 | 열기만 하면 사용 가능 상태 유지, 사용 확정 후 다시 누르면 "이미 사용". `/analytics/[id]` 전환율 반영 | 쿠폰 1회 사용·전환율 |
| 7 | 고객 상세에서 쿠폰을 골라 구매 등록 (팀원1과) | 전환율 반영, 기간 밖 구매일이면 거절 | 구매 등록 전환 |
| 8 | AI-01·02·03 각 1회 | 문구 3안, 추천 시간, 성과 요약. 호출 전 AI Studio에서 남은 일일 한도 확인 | AI 3기능 |
| 9 | AI-02에 대상 수를 크게 넣기 | 끝나는 시각이 20:50을 넘는 후보가 빠짐 | 시간 가드레일 |
| 10 | 이름 없는 시드 고객에게 발송 | "안녕하세요 고객님" | 렌더러 기본값 |
| 11 | 서로 다른 기기 두 대로 같은 메일 열기 | `track_event.ip_hash`가 서로 다르다. 같으면 서버가 Amplify 프록시 IP를 보고 있다는 뜻이다 | 아래 참고 |

- 11번 참고: 추적 API는 `request.getRemoteAddr()`로 IP를 읽는다. `ip_hash`는 저장만 하고 봇 판정·지표에는 쓰지 않으므로, 프록시 IP가 찍혀도 1~10번 결과에는 영향이 없다. 같은 값이 나오면 결과만 PL에게 공유하고, 프록시 헤더 처리 방식(배포 설정)은 PL이 정한다.
- Gemini 무료 등급 한도(RPM 15·RPD 500, TECH_STACK 5장) 안에서 시연한다. 한도는 태평양 시간 자정에 초기화된다. AI-02 근거 문장은 한도를 넘으면 서버 문장으로 대신 나간다.
- 확인 결과(날짜, 통과 여부, 3번의 UA 기록)는 이 문서 4장 아래에 덧붙이고, 키워드를 바꿔야 하면 PL에게 GitHub로 올린다.

## 4. 봇 판정 User-Agent 사전 조사 (2026-10-01)

W3 "봇 판정 User-Agent 목록을 실제 메일로 검증·보강"은 W5로 미뤘고, 그 전에 공식 문서·공개 자료로 확인한 내용이다.
**확인된 근거만으로는 키워드(`bot,crawler,spider,scanner,preview`)에 추가할 것이 없다.** 판정 규칙(backend #38, `BotDetector`·`BotUserAgentConfigTest`):
- 키워드는 대소문자를 무시한 **부분 일치**다. `Googlebot`·`GOOGLEBOT`·`AhrefsBot`·`acme-crawlers`·`SecurityScanner` 모두 봇이다.
- 키워드를 우연히 포함하는 **사람 기기명은 예외 목록**(`withus.tracking.bot-user-agent-allow-list`, 기본 `cubot`)에 두고, 판정 전에 UA에서 지운다. `Android 10; CUBOT X30`·`Cubot_KingKong`은 사람이다. 대소문자 모양으로 사람·봇을 추측하지 않는다.
- 한계: 예외 목록에 없는 기기명은 키워드를 포함하면 봇으로 판정된다(예: `Talbot`). 실메일 확인(아래 절차)이나 운영 중 사람 UA가 봇으로 잡히면 그 기기명을 예외 목록에 추가한다.
- 운영에서 키워드를 환경변수로 바꿀 때는 **부분 일치**라는 점을 기준으로 고른다. 너무 짧거나 흔한 문자열(예: `google`, `proxy`)은 사람 열람까지 지운다. 추측으로 넣으면 사람의 열람을 지울 위험이 있다.
현재 목록이 아래 정상 요청을 봇으로 판정하지 않는다는 것은 `tracking/BotUserAgentConfigTest`(실제 설정 사용)로 고정했다.

| 대상 | 동작 | User-Agent | 판정 방침 |
|---|---|---|---|
| Gmail 이미지 프록시 | 메일이 표시될 때 Google이 대신 이미지를 가져와 `googleusercontent.com`에서 보여 준다 | 끝이 `(via ggpht.com GoogleImageProxy)` | **사람의 열람으로 센다.** `proxy`·`google` 같은 키워드를 넣지 않는다 (넣으면 Gmail 오픈이 모두 사라진다) |
| Apple Mail 개인정보 보호(MPP) | 메일이 **도착할 때** 열지 않아도 원격 콘텐츠(픽셀 포함)를 미리 가져온다 | `Mozilla/5.0`만 보낸다 | UA로 구별할 수 없다. 오픈율이 부풀려지는 한계는 리포트 안내 문구(PRD 8.1)로 알린다. 클릭 추적에는 영향 없음 |
| Microsoft Defender Safe Links | 배달 전에 URL을 검사하고, 평판이 없는 URL은 백그라운드에서 따로 열어 본다. 링크는 `*.safelinks.protection.outlook.com`으로 감싸진다 | **공식 문서에 없음** | UA가 아니라 "발송 후 10초 이내 클릭", "1초 안에 모든 링크 클릭" 규칙으로 대응한다. 사용자가 감싼 링크를 누르면 최종 요청은 사용자 브라우저에서 온다(사람 클릭) |
| 네이버 메일 | 링크 검사·이미지 프록시 동작에 대한 공개 자료를 찾지 못함 | 확인 불가 | W5 실제 메일로 확인 |

**W5 실제 메일 확인 절차** (운영 SES, 인증된 수신 주소)
1. Gmail·Outlook(가능하면 회사 Microsoft 365 계정)·네이버 계정에 추적 링크가 있는 캠페인을 1통씩 보낸다.
2. 메일을 **열지 않은 채** 5분 기다린 뒤 `track_event`를 본다 — 여기서 생긴 OPEN·CLICK은 자동 요청이다. `user_agent`, `bot_yn`, 발송 후 경과 시간을 기록한다.
3. 메일을 열고(이미지 표시) 링크 1개를 누른다 — 새로 생긴 이벤트의 `user_agent`와 `bot_yn = 'N'`을 확인한다.
4. 2에서 `bot_yn = 'N'`으로 남은 자동 요청이 있으면, 그 UA 중 사람 요청과 겹치지 않는 고유 문자열만 키워드 후보로 PL에게 올린다(설정 변경은 `application.yml` 공용 파일).

출처: [Microsoft Learn — Safe Links overview](https://learn.microsoft.com/en-us/defender-office-365/safe-links-about), [Postmark — Open Tracking and Apple Mail](https://postmarkapp.com/support/article/1257-open-tracking-and-apple-mail), [AWS Messaging Blog — Apple Mail iOS 15 Privacy Protection](https://aws.amazon.com/blogs/messaging-and-targeting/apple-mails-ios15-privacy-protection-impact-to-senders-2), [Suped — Google Image Proxy opens](https://www.suped.com/learn/email-deliverability/why-are-emails-showing-as-opened-with-google-image-proxy-ip-when-the-recipient-hasnt-opened-them), [ScientiaMobile — What is Google Image Proxy](https://scientiamobile.com/what-is-google-image-proxy/)

## 5. 워크플로우 CONDITION 조회 검증 (W4 팀원2 지원, 2026-10-02)

`docs/plans/workflow-plan.md` 3.2의 CONDITION(EMAIL_OPENED·EMAIL_CLICKED)은 직전 EMAIL `send_log` 1건을 골라 `TrackEventRepository.existsHumanEvent(sendLogId, "OPEN"|"CLICK")`로 판정한다. 시그니처는 Plan과 같다.

**판정 규칙 (자동 테스트 `tracking/TrackEventRepositoryConditionTest`, `TrackingEventServiceTest`)**

| 경우 | 결과 |
|---|---|
| SKIPPED·FAILED 건(이벤트 없음) | NO — PRD 6.5-4를 별도 분기 없이 만족 |
| OPEN만 있음 | OPEN은 YES, CLICK은 NO |
| 봇 이벤트만 있음 | NO |
| 봇 이벤트 뒤에 사람 이벤트 | YES |
| 앞 단계 메일의 클릭 | 직전 메일 판정에 섞이지 않음 (sendLogId 단위) |
| TEST·NOTICE 발송의 사람 이벤트 | NO |

**부하 확인 (로컬 PostgreSQL 17, 트랜잭션 안에서 생성 후 롤백)**

- 데이터: `send_log` 10만 건, `track_event` 15만 건(OPEN 10만, CLICK 5만, 봇 섞음)
- 1건 판정: `ix_track_event_send_log (send_log_id, event_type)` Index Scan + `send_log_pkey`, 실행 0.066ms
- 엔진 한 번 처리분 500건 연속 판정: 1.9ms
- 결론: CONDITION 조회에는 인덱스를 추가할 필요가 없다. 엔진 쪽 `findLatestSendLogId(instanceId, Channel.EMAIL)`도 `uq_send_log_step (instance_id, step_id)` 유니크 인덱스의 선두 컬럼으로 인스턴스 단위 조회가 된다(인스턴스당 send_log는 SEND 노드 수 이하)

**엔진 단위 대량 판정 (backend #35 헤드 `4e4c3f3` + dev, 로컬, 롤백 트랜잭션, 2026-10-02)**

인스턴스 N개가 CONDITION 앞에서 한꺼번에 실행 시각이 된 상황을 만들고 `WorkflowScheduler.dispatch()`를 그대로 돌렸다. 구조는 `CONDITION(EMAIL_OPENED | EMAIL_CLICKED)` → yes: `WAIT(1일)` → END / no: END. 시나리오 9종(사람·봇, 오픈만, FAILED, 예전 메일에만 반응, 메일 뒤 SMS, SMS만)을 두 조건에 나눠 넣었다. 결과는 backend #35 코멘트에 올렸다.

| N | 오판정 | `dispatch()` | 인스턴스당 |
|---|---|---|---|
| 2,000 | 0 | 8.2초 | 4.1ms |
| 5,000 | 0 | 19.0초 | 3.8ms |
| 20,000 | 0 | 100.7초 | 5.0ms |

- RUNNING으로 남은 인스턴스는 없다. 두 조회는 모두 인덱스를 탄다(약 0.04ms).
- 시간은 대부분 DB 왕복(인스턴스당 약 5회)이다. 스케줄러가 `fixedDelay`라 처리가 길어도 주기가 겹치지 않고, 500건 단위로 선점해 RUNNING 10분 복구에도 걸리지 않는다. 몰린 건의 뒤쪽이 늦게 처리될 뿐 판정은 바뀌지 않는다.

**dev 재검증 (#35 병합본 `f14d3bc`, 2026-10-06, backend #51)**

같은 검증 코드·조건으로 병합된 dev 에서 다시 돌렸다. 다른 캠페인 실행 대기 0건.

| N | 오판정 | `dispatch()` | 인스턴스당 |
|---|---|---|---|
| 2,000 | 0 | 8.4초 | 4.18ms |
| 5,000 | 0 | 23.4초 | 4.68ms |
| 20,000 | 0 | 95.0초 | 4.75ms |

- 시나리오 9종 × 조건 2개, 18칸 모두 기대 경로와 같고 RUNNING 으로 남은 인스턴스는 없다. 리뷰 중 브랜치 결과와 같은 수준이다.
- 실행 계획: `findLatestSendLogId` 는 `uq_send_log_step` Index Scan(0.038ms), `existsHumanEvent` 는 `ix_track_event_send_log` + `send_log_pkey`(0.042ms).

## 6. 3.2 점검표 로컬 리허설 (2026-10-06)

W5 전에 3.2를 운영 SES 대신 Mailpit으로 미리 돌렸다. 운영에서만 달라지는 것(Amplify 주소·프록시, SES, 실제 메일 서비스)을 빼면 발송 → 렌더링 → 쿠폰 발급 → 추적 치환 → 집계 경로가 운영과 같은 코드로 동작한다.

- 환경: backend dev `a4e23fe`(#54까지), frontend dev, local 프로필, `WITHUS_AI_TYPE=gemini`, `ses.max-send-rate=1`(1통 약 5초)
- 데이터: 세그먼트 `[리허설] 경기 5만원 동의`(region EQ GYEONGGI, totalPurchase EQ 50000, emailConsent EQ Y → 5명, 이름 없는 고객 3100 포함), 템플릿 484(쿠폰 안내 메일) + 쿠폰 323으로 일회성 캠페인 2개(1510, 1511)를 API로 만들어 시작

| # | 결과 | 확인 내용 |
|---|---|---|
| 1 | 통과 | 임의 UUID 오픈 200 `image/gif`, 클릭 302(`base-url`로 이동), 형식 오류 토큰 200, 실제 토큰 한 글자 변경 200. `track_event` 132 → 132 |
| 2 | 부분 통과 | 캠페인 메일 HTML: 일반 링크는 `/t/c/{그 발송의 tracking_token}/{linkId}`, 오픈 픽셀 삽입, 쿠폰 `/c/…`·수신거부 `/unsubscribe/…` 링크는 원래 주소 그대로. **테스트 발송 API(`POST /templates/{id}/test-send`)가 아직 없어(팀원2) TEST 제외는 확인 못 함** — 자동 테스트 `DashboardServiceTest`로만 근거 |
| 3 | 해당 없음 | 실제 메일 서비스 필요 (W5) |
| 4 | 통과 | 발송 37초 뒤 오픈·클릭(데스크톱 Chrome UA) → `bot_yn = 'N'`, 캠페인 KPI 오픈·클릭 각 2/5, 대시보드 최근 이벤트에 표시 |
| 5 | 통과 | 첫 건이 SENT가 되는 순간 클릭(발송 0.5초 뒤, iPhone Safari UA) → `bot_yn = 'Y'`, 캠페인 1511 클릭 0, 최근 이벤트에 없음 |
| 6 | 통과 | 390px 화면에서 `/c/[token]` 열기만 함 → `used_at` NULL 유지. 사용하기 → 확인 → 사용 확정 → "사용 완료" 표시, `used_at` 저장. 같은 토큰으로 다시 POST → 409 `COUPON_ALREADY_USED`. 캠페인 전환율 0 → 0.2(1/5) |
| 7 | 해당 없음 | 팀원1과 함께 (구매 등록) |
| 8 | 통과 | 실제 Gemini: AI-01 3안(본문 치환자는 `{{name|고객}}`만), AI-02 추천 3건과 근거 문장, AI-03 캠페인 1510 요약(KPI 수치가 실제 값과 같음) |
| 9 | 통과 | AI-02 `targetCount=20000`(약 5.5시간) → 추천 3건 모두 20:50 전에 끝남(최대 18:34). `targetCount=50000`(약 14시간) → 빈 목록 |
| 10 | 통과 | 이름 없는 고객 3100: 제목 `(광고) 고객님께 드리는 할인 쿠폰`, 본문 `고객님, 감사의 마음을…` |
| 11 | 해당 없음 | 기기 두 대·Amplify 프록시 필요 (W5) |

**로컬에서만 다른 점**

- `withus.tracking.base-url` 기본값이 `http://localhost:8080`(백엔드)이라 Mailpit에서 쿠폰·수신거부 링크를 누르면 백엔드로 가서 401이 난다(`/c/…`, `/unsubscribe/…`는 프론트 화면). 프론트(3000)는 `/t/*`를 백엔드로 프록시하므로, 로컬에서 메일 링크까지 눌러 보려면 **`WITHUS_PUBLIC_BASE_URL=http://localhost:3000`**으로 띄우면 운영(Amplify)과 같은 구조가 된다. 이번 리허설은 쿠폰 화면을 3000 주소로 직접 열었다.
- 사람 클릭에는 OPEN 이벤트가 함께 저장된다(이미지 차단으로 픽셀이 안 불린 경우 보정). 봇 클릭에는 붙지 않는다.

**W5에 남은 것**: 3·7·11번, 2번의 TEST 제외(테스트 발송 API 병합 후), 1번의 Amplify → EC2 `/t/*` 프록시.
