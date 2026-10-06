# 팀원3 — 전환 구간

- 백엔드 패키지: `tracking`, `coupon`, `ai`
- 기준: PRD 10.1, 5.1(쿠폰·대시보드), 5.3(AI), 8.1(추적) / roadmap 3장
- Flyway 번호 대역: `V30~V39`
- 공통 규칙: 루트 `CLAUDE.md` (이 파일은 규칙을 바꾸지 않고 담당 범위만 정한다)

## 제공하는 인터페이스
- `TrackingLinkService.rewrite(html, sendLogId)` → 팀원2
- `CouponService.issue(couponId, customerId, sendLogId)` → 팀원2, 쿠폰 사용 처리 → 팀원1
- `TrackEventRepository` → 팀원2(워크플로우 CONDITION), 휴면 판정(팀원1)
- AI-01(문구)·AI-02(발송 시간) API → 팀원2 화면
- `PlaceholderRenderer`(`common.render`) → 팀원2 발송 렌더링·미리보기 (팀원2에서 이관)

## 호출하는 인터페이스
- `send_log` 집계 (팀원2 테이블, 직접 SELECT 허용. TEST·NOTICE·봇 제외)

## 건드리지 않는 영역
`customer`, `segment`, `campaign`, `workflow`, `auth`, `common`(단 `common.render` 구현은 담당).

## 체크리스트 (roadmap 항목과 동일)
**W1**
- [ ] 추적 API(`/t/o/{trackingToken}.gif`, `/t/c/{trackingToken}/{linkId}`), 비동기 이벤트 저장
- [ ] Gemini 클라이언트(개인정보 미전송, 한도 초과 처리) — 무료 등급 모델명·호출 한도 확인해 `docs/tech/TECH_STACK.md` 5장에 기록
- [ ] **(W1 최우선)** `TrackingLinkService`·`CouponService`·`TrackEventRepository`·`PlaceholderRenderer` stub 병합 — 팀원2 선개발용

**W2**
- [ ] 치환자 렌더러 `PlaceholderRenderer` 실제 구현 + 단위 테스트 (PRD F-04: 고객 값 → `{{name|고객}}` 기본값 → 시스템 기본값, 빈 문자열 금지)
- [ ] 봇 판정(10초, User-Agent 키워드, 1초 내 전체 클릭)
- [ ] 메인 대시보드(카드, 활성 캠페인, 10초 폴링 이벤트 로그), 캠페인 성과 차트

**W3**
- [ ] 쿠폰 CRUD(정액·정률·상한, 고정 기간), 발급(`CouponService.issue`), `{{couponUrl}}` 연동
- [ ] 고객 쿠폰 페이지 `/c/[token]`(카드형, POST 사용 처리, 모바일 대응), 전환 집계
- [ ] 봇 판정 User-Agent 목록을 실제 메일(Gmail·Outlook·Naver)로 검증·보강

**W4**
- [ ] AI-01 문구 3안, AI-02 발송 시간 추천(08:00~20:00 가드레일은 코드로), AI-03 성과 요약(`ai_report`)
- [ ] 성과 리포트 마무리(단계별 차트, 전환율, 기간 필터, 목록 `/analytics`) — A/B 비교는 범위 제외(PL 결정 2026-10-06)
- [ ] 여유 시 팀원2 워크플로우 안정화 지원(부하 데이터 생성, CONDITION 조회 검증)

**W5**
- [ ] 내 구간 PRD 10.3 완료 기준 운영 재검증, 시연 데이터

## 작업 방식
- 브랜치·PR 절차는 `docs/workflow-git.md`
- 세부 분해는 개인 Shrimp 사용(데이터 커밋 금지). 완료한 roadmap 항목은 PR 설명에 적는다 (체크는 PL이 병합 시)
- 공통 사용법(로그인·응답·오류·Lombok): `withus_backend/README.md` "팀원용 사용법", 프론트(api 호출·쿼리 키·폼·컴포넌트): `withus_frontend/README.md`
- 다른 도메인 테이블은 조회(SELECT)만 직접 가능, 쓰기는 소유 도메인 서비스로 (`docs/workflow-git.md`)
- stub 은 실제 구현을 넣을 때 **삭제**한다 (같은 인터페이스 빈이 2개면 기동 실패)
- 이 구간의 핵심 규칙: 추적 URL은 UUID `tracking_token`만(6장 7번), 봇·TEST·NOTICE 제외(8), 쿠폰 '사용하기'는 POST만(6), LLM에 개인정보 전송 금지(12)
- 팀원2가 W2에 링크 치환을 연결하므로 추적 API(W1)를 먼저 끝낸다
