# 팀원2 — 발송 구간

- 백엔드 패키지: `campaign`(템플릿 포함), `workflow`
- 기준: PRD 10.1, 5.1(템플릿·캠페인), 6장(워크플로우), 8.2·8.4(발송·법규) / roadmap 3장
- Flyway 번호 대역: `V20~V29`
- 공통 규칙: 루트 `CLAUDE.md` (이 파일은 규칙을 바꾸지 않고 담당 범위만 정한다)

## 제공하는 인터페이스
- 공통 발송 큐(`send_log` PENDING 적재) → 팀원1(F-12 안내), 팀원3(쿠폰 메일), 워크플로우
- `send_log` 집계 → 팀원3(대시보드·리포트)
- `provider_message_id` 로 고객 조회 → 팀원1(SES 웹훅)

## 호출하는 인터페이스
- `SegmentService.findTargetCustomers(segmentId)` (팀원1)
- `TrackingLinkService.rewrite(html, sendLogId)`, `CouponService.issue(couponId, customerId, sendLogId)` (팀원3)
- `PlaceholderRenderer.render(template, values)` — 치환자·기본값 처리 (팀원3, 팀원2에서 이관)
- 워크플로우 CONDITION → `TrackEventRepository` 조회 (팀원3)
- 템플릿 에디터 → AI-01 API, 캠페인 생성 화면 → AI-02 API (팀원3)

## 건드리지 않는 영역
`customer`, `segment`, `tracking`, `coupon`, `ai`, `auth`, `common`.

## 체크리스트 (roadmap 항목과 동일)
**W1**
- [ ] 템플릿 CRUD API·화면(**최소 기능**), TinyMCE 연동(자체 설치, `license_key: 'gpl'`), `FileStorage`(로컬) 이미지 업로드
- [ ] `MessageSender` 인터페이스 + SMTP(Mailpit) 구현, SMS Mock
- [ ] **발송 큐 설계 Plan 작성 → PL 리뷰·승인** (W2 착수 전). 팀원1·3의 stub 위에서 개발 시작

**W2**
- [ ] 일회성 캠페인 생성·예약, 20:50 컷오프 검사(PENDING 대기분 포함)
- [ ] **공통 발송 큐**: PENDING 적재 → `SENDING` 선점 → 트랜잭션 밖 발송 → SENT/FAILED, 우선순위, 토큰 버킷 속도 제한
- [ ] 발송 직전 재확인, 재시도(1·5·15분), `SENDING` 10분 초과 처리
- [ ] 발송 시 렌더링: (광고)·발신자·수신거부 삽입, `PlaceholderRenderer`·`TrackingLinkService.rewrite` 연결

**W3**
- [ ] 워크플로우 빌더(폼 기반) + 구조 검증(분기 2단계, 노드 15개, 순환 금지, SEND 노드별 쿠폰)
- [ ] 워크플로우 엔진: 500건 반복 처리, WAIT(`sent_at` 기준), CONDITION(봇 제외), 멈춤 복구, 멱등성
- [ ] 캠페인 상태 전이(DRAFT/SCHEDULED/ACTIVE/PAUSED/COMPLETED), 일시정지 시 PENDING 보류

**W4**
- [ ] 워크플로우 안정화(10만 건 적재 부하, 우선순위 검증)
- [ ] (선택) A/B 테스트, React Flow 캔버스

**W5**
- [ ] 내 구간 PRD 10.3 완료 기준 운영 재검증, 시연 데이터

## 작업 방식
- 브랜치·PR 절차는 `docs/workflow-git.md`
- 세부 분해는 개인 Shrimp 사용(데이터 커밋 금지). 완료한 roadmap 항목은 PR 설명에 적는다 (체크는 PL이 병합 시)
- 공통 사용법(로그인·응답·오류·Lombok): `withus_backend/README.md` "팀원용 사용법", 프론트(api 호출·쿼리 키·폼·컴포넌트): `withus_frontend/README.md`
- 다른 도메인 테이블은 조회(SELECT)만 직접 가능, 쓰기는 소유 도메인 서비스로 (`docs/workflow-git.md`)
- stub 은 실제 구현을 넣을 때 **삭제**한다 (같은 인터페이스 빈이 2개면 기동 실패)
- **발송 큐·워크플로우 엔진은 코드 전에 Plan 제시 후 PL 승인**
- 이 구간의 핵심 규칙: 큐 우회 금지(6장 1번), 발송 직전 재확인(2), 08:00~20:50(3), 렌더링·쿠폰은 발송 직전(4), SENDING 10분 초과는 FAILED(5), 외부 호출은 트랜잭션 밖
- W2 발송 큐가 밀리면 W3 워크플로우가 밀린다. 큐 완성이 최우선
- 난이도 최상 구간(발송 큐·워크플로우 엔진)이라 PL 리뷰 우선순위 1·2위. 막히면 바로 PL에 알린다 (W3 후반 PL 지원, W4 팀원3 지원 예정)
