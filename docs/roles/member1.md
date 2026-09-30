# 팀원1 — 고객 구간

- 백엔드 패키지: `customer`, `segment`
- 기준: PRD 10.1, 5.1(고객·세그먼트·수신거부), 7장, 8.3 / roadmap 3장
- Flyway 번호 대역: `V10~V19`
- 공통 규칙: 루트 `CLAUDE.md` (이 파일은 규칙을 바꾸지 않고 담당 범위만 정한다)

## 제공하는 인터페이스 (다른 구간이 호출)
- `SegmentService.findTargetCustomers(segmentId)` → 팀원2(발송·워크플로우)
- 수신동의·`suppression` 확인 → 팀원2

## 호출하는 인터페이스
- 구매 등록 시 쿠폰 사용 처리 → `CouponService` (팀원3)
- SES 웹훅 → `send_log.provider_message_id` 로 고객 조회 (팀원2)

## 건드리지 않는 영역
`campaign`, `workflow`, `tracking`, `coupon`, `ai`, `auth`, `common`. 필요하면 인터페이스로 호출하거나 먼저 알린다.

## 체크리스트 (roadmap 항목 단위로 체크)
**W1**
- [ ] 고객 CRUD API·화면, 입력값 정규화 유틸(이메일·휴대폰·지역·날짜) + 단위 테스트
- [ ] 수신동의 변경과 `consent_history` 기록
- [ ] **(W1 수 까지)** `SegmentService`·`ConsentService` stub 병합 — 고정값 반환, 팀원2 선개발용. 이후 실제 구현으로 교체

**W2**
- [ ] CSV/xlsx 업로드(10,000행, 500행 배치 insert, 행별 결과, `suppression` 반영)
- [ ] 세그먼트 조건 빌더: 규칙 JSON → MyBatis 동적 SQL(화이트리스트), 대상 수 미리보기 + 단위 테스트

**W3**
- [ ] 수신거부 페이지(GET 확인 / POST 처리), 원클릭 수신거부 API, `suppression` 관리·해제 절차
- [ ] SES 반송·스팸신고 웹훅(SNS 서명 검증, Mock 요청 검증)
- [ ] 휴면 판정 배치(180일 클릭·구매 없음), 구매 등록(`purchase`, 쿠폰 사용 연계)

**W4**
- [ ] 수신동의 2년 확인 안내(F-12, NOTICE 발송·시간 제한)
- [ ] 버그 수정

**W5**
- [ ] 내 구간 PRD 10.3 완료 기준 운영 재검증, 시연 데이터

## 작업 방식
- 브랜치·PR 절차는 `docs/workflow-git.md`
- 세부 분해는 개인 Shrimp 사용(데이터 커밋 금지). roadmap 체크는 항목 단위
- 세그먼트 동적 쿼리는 코드 전에 Plan 제시 후 PL 승인 (PL 리뷰 우선순위 3위)
- 세그먼트 SQL이 W2 중반을 넘기면 M2(일회성 발송 E2E)가 막힌다. 단순 조건부터 먼저 병합하고 확장한다
- 이 구간의 핵심 규칙: 입력 정규화(6장 9번), 수신거부는 POST만(6번), `suppression`은 업로드로 해제 불가(10번)
