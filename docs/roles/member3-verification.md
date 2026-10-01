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
- 봇 판정 User-Agent 목록은 W5에 실제 메일(Gmail·Outlook·Naver)로 검증·보강한다 (W3에서 미룸, 2026-10-01 결정)
- Gemini 무료 등급 한도(RPM 15·RPD 500, TECH_STACK 5장) 안에서 시연한다. AI-02 근거 문장은 한도 초과 시 서버 문장으로 대신 나간다
