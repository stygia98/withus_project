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

## 3. 운영 재검증 전 준비

- 환경변수: `GEMINI_API_KEY`, `TRACKING_IP_SALT`, `WITHUS_AI_TYPE=gemini`(운영 기본값), `withus.tracking.base-url` = 운영 프론트 주소
- 봇 판정 User-Agent 목록은 W5에 실제 메일(Gmail·Outlook·Naver)로 검증·보강한다 (W3에서 미룸, 2026-10-01 결정). 사전 조사와 확인 절차는 4장
- Gemini 무료 등급 한도(RPM 15·RPD 500, TECH_STACK 5장) 안에서 시연한다. AI-02 근거 문장은 한도 초과 시 서버 문장으로 대신 나간다

## 4. 봇 판정 User-Agent 사전 조사 (2026-10-01)

W3 "봇 판정 User-Agent 목록을 실제 메일로 검증·보강"은 W5로 미뤘고, 그 전에 공식 문서·공개 자료로 확인한 내용이다.
**확인된 근거만으로는 키워드(`bot,crawler,spider,scanner,preview`)에 추가할 것이 없다.** 추측으로 넣으면 사람의 열람을 지울 위험이 있다.
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
