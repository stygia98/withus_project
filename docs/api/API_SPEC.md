# API_SPEC.md — 위드어스 (Withus) API 명세

> 기준: `docs/prd.md` (PRD v2.3) · 스키마: `docs/db/DB_SCHEMA.md` · 최종 계약은 SpringDoc(Swagger UI)이며 이 문서는 도메인별 API 목록 초안이다. 각 담당이 구현하면서 확정하고, 요청·응답 형식을 바꾸면 이 문서도 함께 고친다. 인증(2장)은 구현 완료.

## 1. 공통 규칙

### 1.1 경로

| 구분 | 경로 | 인증 |
|---|---|---|
| 관리자 API | `/api/v1/**` | 필요 (httpOnly 쿠키 + CSRF) |
| 고객 공개 API | `/api/v1/public/**` | 불필요 (토큰으로 검증, CSRF 제외) |
| 원클릭 수신거부 | `/api/v1/unsubscribe/one-click/{token}` | 불필요 (메일 헤더용, CSRF 제외) |
| 추적 | `/t/**` | 불필요 |
| 웹훅 | `/api/webhooks/**` | 불필요 (SNS 서명 검증) |

- 브라우저는 프론트 도메인의 `/api/*`만 호출하고, Next.js rewrites가 백엔드로 넘긴다. 메일에 들어가는 추적(`/t/**`)·수신거부 링크와 SES 웹훅도 같은 프론트 주소로 들어와 프록시된다 (도메인 미구매, PRD 10.4). 링크 기준 주소는 `withus.tracking.base-url`.
- 본문은 JSON(`application/json`), 파일 업로드는 `multipart/form-data`.

### 1.2 응답 형식

```json
// 성공
{ "success": true, "data": { ... }, "error": null }

// 실패
{ "success": false, "data": null, "error": { "code": "SEGMENT_INVALID_RULE", "message": "조건은 최대 10개까지 추가할 수 있습니다." } }
```

**페이징 응답의 `data`**

```json
{ "content": [ ... ], "page": 0, "size": 20, "totalElements": 12480, "totalPages": 624 }
```

- 페이징 파라미터: `page`(0부터), `size`(기본 20, 최대 100), `sort`(허용 필드만, 예: `createdAt,desc`).
- 날짜/시간: ISO-8601 문자열 (`2026-10-05T09:00:00+09:00`), 날짜만: `2026-10-05`.
- 금액: 원 단위 정수.

### 1.3 HTTP 상태 코드

| 상태 | 사용 |
|---|---|
| 200 | 조회·수정 성공 |
| 201 | 생성 성공 |
| 204 | 삭제 성공 (본문 없음) |
| 400 | 입력값 오류 (`*_INVALID_*`) |
| 401 | 미인증, 토큰 만료 (`AUTH_*`) |
| 403 | 권한 없음, CSRF 실패 (`AUTH_FORBIDDEN`, `AUTH_CSRF_INVALID`) |
| 404 | 대상 없음 (`*_NOT_FOUND`) |
| 409 | 상태 충돌 (`*_INVALID_STATUS`, `*_IN_USE`, `*_DUPLICATE`) |
| 422 | 업무 규칙 위반 (`CAMPAIGN_SEND_WINDOW_EXCEEDED` 등) |
| 429 | 외부 한도 초과 (`AI_RATE_LIMITED`) |

### 1.4 인증·CSRF

1. 앱 시작 시 `GET /api/v1/auth/csrf` → `XSRF-TOKEN` 쿠키 발급.
2. 모든 상태 변경 요청(POST/PUT/PATCH/DELETE)에 헤더 `X-XSRF-TOKEN: <쿠키 값>`.
3. 로그인 성공 시 `ACCESS_TOKEN`(30분, Path=/), `REFRESH_TOKEN`(7일, Path=/api/v1/auth) httpOnly·Secure·SameSite=Lax 쿠키 발급.
4. 401 `AUTH_TOKEN_EXPIRED`를 받으면 프론트는 `POST /api/v1/auth/refresh` 후 원래 요청을 한 번 재시도한다.

### 1.5 권한 표기

`O` OWNER, `M` MANAGER, `S` STAFF, `R` 조회만 허용. 예: `O M S(R)`.

## 2. 인증·사용자 (PL · `auth`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/auth/csrf` | 공개 | CSRF 쿠키 발급 |
| POST | `/api/v1/auth/login` | 공개 | 로그인, 토큰 쿠키 발급 |
| POST | `/api/v1/auth/refresh` | 공개(쿠키) | Access 재발급, Refresh 교체 |
| POST | `/api/v1/auth/logout` | 로그인 | Refresh 무효화, 쿠키 만료 |
| GET | `/api/v1/auth/me` | 로그인 | 내 정보 |
| GET | `/api/v1/members` | O | 사용자 목록 (미구현, PL) |
| POST | `/api/v1/members` | O | 사용자 생성 |
| PATCH | `/api/v1/members/{memberId}` | O | 역할·활성 여부 변경 |

**POST /auth/login**

```json
// 요청
{ "email": "manager@withus.kr", "password": "********" }
// 응답 data
{ "memberId": 2, "email": "manager@withus.kr", "name": "김마케팅", "role": "MANAGER" }
```

오류: `AUTH_INVALID_CREDENTIALS`(401), `AUTH_ACCOUNT_LOCKED`(401, `error.details.lockedUntil` 포함, 5회 실패 시 5분), `AUTH_ACCOUNT_INACTIVE`(401).

## 3. 고객 (팀원1 · `customer`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/customers` | O M | 목록 (검색·필터·페이징, 이메일·휴대폰 마스킹) |
| GET | `/api/v1/customers/{customerId}` | O M | 상세 (마스킹 없음) |
| POST | `/api/v1/customers` | O M | 개별 등록 (`CUSTOMER_REGISTERED` 트리거 발생) |
| PATCH | `/api/v1/customers/{customerId}` | O M | 수정 (누적구매액은 수정 불가) |
| DELETE | `/api/v1/customers/{customerId}` | O M | 논리 삭제, 진행 중 인스턴스 CANCELLED |
| PATCH | `/api/v1/customers/{customerId}/consent` | O M | 수신동의 변경 (suppression 해제 포함) |
| GET | `/api/v1/customers/{customerId}/consent-history` | O M | 동의 이력 |
| GET | `/api/v1/customers/{customerId}/activity` | O M | 발송·이벤트·쿠폰 이력 |
| GET | `/api/v1/customers/upload-template` | O M | 업로드 양식 xlsx 다운로드 |
| POST | `/api/v1/customers/uploads` | O M | CSV/xlsx 업로드 (최대 10MB, 10,000행) |
| GET | `/api/v1/customers/{customerId}/purchases` | O M | 구매 목록 |
| POST | `/api/v1/customers/{customerId}/purchases` | O M | 구매 등록 (쿠폰 선택 시 사용 처리) |

**GET /customers 쿼리**: `keyword`(이름·이메일·휴대폰), `region`, `emailConsent`(Y/N), `smsConsent`(Y/N), `dormant`(Y/N), `page`, `size`, `sort`.

**POST /customers**

```json
{
  "name": "김민지", "email": "Kim.Minji@Naver.com ", "phone": "010-1234-5678",
  "region": "서울", "birthDate": "1998-04-12", "joinedAt": "2026-09-30",
  "emailConsent": "Y", "smsConsent": "N"
}
```

- 저장 전 정규화: 이메일 소문자·trim, 휴대폰 숫자만, 지역명 → 코드.
- `suppression`에 있는 값은 해당 채널 동의를 N으로 저장하고 응답에 `suppressedChannels: ["EMAIL"]`를 담는다.
- 오류: `CUSTOMER_DUPLICATE_EMAIL`(409), `CUSTOMER_INVALID_REGION`(400), `CUSTOMER_INVALID_PHONE`(400).

**PATCH /customers/{id}** — 수정 화면의 값(이름·이메일·휴대폰·지역·생년월일·가입일)을 **통째로 교체**한다(빈 값은 지움). 누적구매액은 구매 등록으로만, 수신동의는 `PATCH /consent`로만 바뀐다.

**PATCH /customers/{id}/consent**

```json
{ "channel": "EMAIL", "consent": "Y", "evidenceNote": "2026-09-30 매장 방문 시 서면 재동의" }
```

- suppression에 있는 값을 Y로 바꿀 때는 `evidenceNote` 필수 → suppression 삭제, `consent_history`(source=ADMIN, note) 기록.
- 오류: `CUSTOMER_CONSENT_EVIDENCE_REQUIRED`(422).

**GET /customers/{id}/activity** — 고객 상세의 발송·이벤트·쿠폰 이력

```json
// 응답 data
{
  "sends": [
    { "sendLogId": 5012, "campaignId": 12, "campaignName": "10월 프로모션", "channel": "EMAIL", "kind": "CAMPAIGN",
      "status": "SENT", "errorMessage": null, "createdAt": "2026-10-05T09:00:00+09:00", "sentAt": "2026-10-05T09:00:03+09:00",
      "openedAt": "2026-10-05T10:12:00+09:00", "clickedAt": null }
  ],
  "coupons": [
    { "issueId": 318, "couponId": 7, "couponName": "10월 재구매 쿠폰", "status": "USABLE",
      "validFrom": "2026-10-01", "validTo": "2026-10-31", "issuedAt": "2026-10-05T09:00:03+09:00", "usedAt": null }
  ]
}
```

- `sends`: 최근 100건, 최신순. NOTICE도 포함(`campaignName` null). `openedAt`·`clickedAt`은 봇 제외 첫 이벤트 시각.
- `coupons`: 발급 전체, 최신 발급순. `status`는 오늘 기준 `USABLE`·`USED`·`EXPIRED`·`NOT_STARTED`. 구매 등록 화면의 쿠폰 선택 목록은 선택한 구매일이 유효기간 안인 미사용 쿠폰이다 (`status`는 오늘 기준이라 구매일 판정에 쓰지 않는다, backend #14).
- 삭제된 고객: `COMMON_NOT_FOUND`(404).

**POST /customers/uploads** (multipart, `file`)

```json
// 응답 data
{
  "total": 100, "created": 80, "updated": 16, "failed": 4, "suppressed": 2,
  "failures": [ { "row": 12, "reason": "CUSTOMER_INVALID_PHONE" }, { "row": 57, "reason": "CUSTOMER_INVALID_DATE" } ]
}
```

- 기존 고객 업데이트 시 누적구매액은 바꾸지 않는다. 업로드 고객은 워크플로우 트리거를 발생시키지 않는다.
- 오류: `UPLOAD_FILE_TOO_LARGE`(400), `UPLOAD_TOO_MANY_ROWS`(400), `UPLOAD_INVALID_HEADER`(400), `UPLOAD_INVALID_FILE`(400).
- 행별 실패 `reason` 은 12장 `CUSTOMER_INVALID_*`·`CUSTOMER_DUPLICATE_EMAIL`. `row` 는 파일에서 보이는 행 번호(헤더 = 1).

**POST /customers/{id}/purchases**

```json
{ "amount": 45000, "couponIssueId": 318, "purchasedAt": "2026-10-02T14:10:00+09:00" }
```

- `total_purchase` 가산. `couponIssueId`는 이 고객에게 발급됐고, 미사용이며, 유효기간 안이어야 한다.
- `amount`는 1 이상 필수. `couponIssueId`·`purchasedAt`은 선택(`purchasedAt` 생략 시 지금). `purchasedAt`이 미래면 `COMMON_INVALID_INPUT`(400).
- 쿠폰 유효기간은 **구매일**(`purchasedAt`의 KST 날짜) 기준으로 본다.
- 오류: `COUPON_NOT_USABLE`(422, 다른 고객 발급분·없는 발급 건·기간 밖), `COUPON_ALREADY_USED`(409).

```json
// 응답 data (GET 목록은 이 형식의 배열, 최신 구매순). 쿠폰 미사용이면 couponIssueId·couponName 은 null
{ "purchaseId": 91, "amount": 45000, "couponIssueId": 318, "couponName": "10월 재구매 쿠폰",
  "purchasedAt": "2026-10-02T14:10:00+09:00" }
```

## 4. 세그먼트 (팀원1 · `segment`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/segments` | O M S(R) | 목록 (현재 대상 수 포함) |
| GET | `/api/v1/segments/{segmentId}` | O M S(R) | 상세 (rule 포함) |
| POST | `/api/v1/segments` | O M | 생성 |
| PUT | `/api/v1/segments/{segmentId}` | O M | 수정 |
| DELETE | `/api/v1/segments/{segmentId}` | O M | 삭제 (캠페인이 참조 중이면 409) |
| POST | `/api/v1/segments/preview` | O M | 조건으로 대상 수 미리보기 (저장 안 함) |
| GET | `/api/v1/segments/fields` | O M S | 사용 가능한 필드·연산자 목록 |

**POST /segments**

```json
{ "name": "수도권 우수 고객 · 20~34세", "description": null, "rule": { "operator": "AND", "groups": [ ... ] } }
```

rule 형식은 `docs/db/DB_SCHEMA.md` 5.1.

**POST /segments/preview**

```json
// 요청
{ "rule": { ... } }
// 응답 data
{ "total": 12480, "emailConsent": 10932, "smsConsent": 8210, "dormant": 1044 }
```

오류: `SEGMENT_INVALID_RULE`(400), `SEGMENT_TOO_MANY_CONDITIONS`(400), `SEGMENT_IN_USE`(409). 목표 응답 2초 이내(고객 10만 명).

## 5. 템플릿·파일 (팀원2 · `campaign`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/templates` | O M S | 목록 (`channel` 필터) |
| GET | `/api/v1/templates/{templateId}` | O M S | 상세 (`inUse` 여부 포함) |
| POST | `/api/v1/templates` | O M S | 생성 |
| PUT | `/api/v1/templates/{templateId}` | O M S | 수정 (사용 중이면 409) |
| DELETE | `/api/v1/templates/{templateId}` | O M S | 삭제 (참조 중이면 409) |
| POST | `/api/v1/templates/{templateId}/duplicate` | O M S | 복제 |
| POST | `/api/v1/templates/{templateId}/preview` | O M S | 렌더링 미리보기 |
| POST | `/api/v1/templates/{templateId}/test-send` | O M S | 테스트 발송 1건 |
| POST | `/api/v1/files/images` | O M S | 이미지 업로드 (5MB, jpg/png/gif) |

**POST /templates**

```json
{
  "channel": "EMAIL", "name": "가을 감사 쿠폰 안내", "adYn": "Y",
  "subject": "{{name|고객}}님께 드리는 가을 선물",
  "body": "<p>안녕하세요, {{name|고객}}님!</p> ... <a href=\"{{couponUrl}}\">쿠폰 받기</a>"
}
```

- 치환자: `{{name}}`, `{{email}}`, `{{region}}`, `{{totalPurchase}}`, `{{couponUrl}}`. 기본값 문법 `{{name|고객}}`.
- `(광고)`, 발신자 정보, 수신거부 링크는 저장 본문에 넣지 않는다. 발송 시 시스템이 삽입한다.
- 오류: `TEMPLATE_IN_USE`(409), `TEMPLATE_INVALID_PLACEHOLDER`(400), `TEMPLATE_SUBJECT_REQUIRED`(400).

**POST /templates/{id}/preview**

```json
// 요청 (segmentId가 있으면 기본값으로 나갈 인원도 계산)
{ "sampleCustomerId": 1024, "segmentId": 7 }
// 응답 data
{ "subject": "(광고) 김민지님께 드리는 가을 선물", "html": "...", "smsBytes": null, "defaultValueCount": { "total": 12480, "usingDefault": 312 } }
```

**POST /templates/{id}/test-send**

```json
{ "recipient": "me@withus.kr" }
```

send_log에 kind=TEST, priority=1로 적재. 샘플 값 치환, 추적·쿠폰 발급 없음, 시간 제한 없음, 통계 제외.

## 6. 캠페인·워크플로우 (팀원2 · `campaign`, `workflow`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/campaigns` | O M S(R) | 목록 (`type`, `status` 필터) |
| GET | `/api/v1/campaigns/{campaignId}` | O M S(R) | 상세 |
| POST | `/api/v1/campaigns` | O M | 생성 (DRAFT) |
| PUT | `/api/v1/campaigns/{campaignId}` | O M | 수정 (DRAFT만) |
| GET | `/api/v1/campaigns/{campaignId}/estimate` | O M | 예상 소요 시간·발송 가능 여부 |
| POST | `/api/v1/campaigns/{campaignId}/schedule` | O M | 예약 (DRAFT → SCHEDULED) |
| POST | `/api/v1/campaigns/{campaignId}/start` | O M | 즉시 시작·워크플로우 활성화 (→ ACTIVE) |
| POST | `/api/v1/campaigns/{campaignId}/cancel-schedule` | O M | 예약 취소 (SCHEDULED → DRAFT) |
| POST | `/api/v1/campaigns/{campaignId}/pause` | O M | 일시정지 (ACTIVE → PAUSED) |
| POST | `/api/v1/campaigns/{campaignId}/resume` | O M | 재개 (PAUSED → ACTIVE) |
| POST | `/api/v1/campaigns/{campaignId}/complete` | O M | 종료 (→ COMPLETED, 인스턴스 CANCELLED) |
| POST | `/api/v1/campaigns/{campaignId}/duplicate` | O M | 복제 (새 DRAFT) |
| PUT | `/api/v1/campaigns/{campaignId}/ab-test` | O M | A/B 설정 (일회성, DRAFT만) |
| GET | `/api/v1/campaigns/{campaignId}/workflow` | O M S(R) | 워크플로우 노드 조회 |
| PUT | `/api/v1/campaigns/{campaignId}/workflow` | O M | 워크플로우 저장 (DRAFT만, 저장 시 검증) |
| POST | `/api/v1/campaigns/{campaignId}/workflow/validate` | O M | 구조 검사만 수행 |
| GET | `/api/v1/campaigns/{campaignId}/instances` | O M | 인스턴스 목록 (`status` 필터) |

**POST /campaigns**

```json
// 일회성
{ "type": "ONE_TIME", "name": "가을 감사 쿠폰 발송", "segmentId": 7, "templateId": 12, "couponId": 3 }
// 워크플로우
{ "type": "WORKFLOW", "name": "신규 가입 환영 여정", "segmentId": 1, "triggerType": "CUSTOMER_REGISTERED" }
```

**GET /campaigns/{id}/estimate?startAt=2026-10-05T19:30:00+09:00**

```json
{
  "targetCount": 10000, "pendingBacklog": 4210, "ratePerSecond": 14,
  "expectedEndAt": "2026-10-05T19:47:45+09:00", "adYn": "Y",
  "allowed": true, "reason": null, "nextAvailableAt": null
}
```

- 예상 소요 시간 = (PENDING 대기 건수 + 대상 수) ÷ 초당 한도. A/B면 "표본 발송 + 대기 + 나머지 발송" 전체로 계산.
- 광고성인데 20:50을 넘기면 `allowed: false`, `reason: "SEND_WINDOW_EXCEEDED"`, `nextAvailableAt`에 가능한 가장 빠른 시각.

**POST /campaigns/{id}/schedule**

```json
{ "scheduledAt": "2026-10-05T10:00:00+09:00" }
```

오류: `CAMPAIGN_SEND_WINDOW_EXCEEDED`(422, `nextAvailableAt` 포함), `CAMPAIGN_INVALID_STATUS`(409), `CAMPAIGN_COUPON_REQUIRED`(422, `{{couponUrl}}` 템플릿에 쿠폰 없음), `COUPON_OUT_OF_PERIOD`(422).

**PUT /campaigns/{id}/workflow**

```json
{
  "steps": [
    { "key": "t",  "nodeType": "TRIGGER",    "config": { "triggerType": "CUSTOMER_REGISTERED" }, "next": "s1" },
    { "key": "s1", "nodeType": "SEND_EMAIL", "config": { "templateId": 21 }, "next": "w1" },
    { "key": "w1", "nodeType": "WAIT",       "config": { "amount": 2, "unit": "DAY" }, "next": "c1" },
    { "key": "c1", "nodeType": "CONDITION",  "config": { "condition": "EMAIL_CLICKED" }, "yes": "c2", "no": "s4" },
    { "key": "c2", "nodeType": "CONDITION",  "config": { "condition": "PURCHASE_GTE", "amount": 100000 }, "yes": "s2", "no": "s3" },
    { "key": "s2", "nodeType": "SEND_EMAIL", "config": { "templateId": 22, "couponId": 5 }, "next": "e1" },
    { "key": "s3", "nodeType": "SEND_EMAIL", "config": { "templateId": 23, "couponId": 6 }, "next": "e2" },
    { "key": "s4", "nodeType": "SEND_SMS",   "config": { "templateId": 30 }, "next": "e3" },
    { "key": "e1", "nodeType": "END" }, { "key": "e2", "nodeType": "END" }, { "key": "e3", "nodeType": "END" }
  ]
}
```

- `key`는 요청 안에서만 쓰는 임시 식별자. 서버가 step_id로 바꿔 저장한다.
- 저장 시 검증(실패 시 `WORKFLOW_INVALID_STRUCTURE` 400, `details`에 위반 목록): TRIGGER 1개, CONDITION 중첩 2단계 이내, 노드 15개 이하, 모든 경로 END, 순환 없음, 메일 이벤트 조건 앞에 SEND_EMAIL→WAIT, `{{couponUrl}}` 템플릿에 쿠폰 연결, 쿠폰 유효기간.

**POST /campaigns/{id}/workflow/validate 응답 data**

```json
{
  "valid": true,
  "checks": [
    { "code": "DEPTH_WITHIN_LIMIT", "passed": true, "message": "분기 중첩 2단계 이내" },
    { "code": "NODE_COUNT", "passed": true, "message": "노드 11 / 15개" }
  ],
  "warnings": [ { "code": "EMAIL_OPENED_UNRELIABLE", "message": "열람 조건 대신 클릭 조건 사용을 권장합니다." } ]
}
```

## 7. 쿠폰 (팀원3 · `coupon`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/coupons` | O M S(R) | 목록 (발급·사용 수 포함) |
| GET | `/api/v1/coupons/{couponId}` | O M S(R) | 상세 |
| POST | `/api/v1/coupons` | O M | 생성 |
| PUT | `/api/v1/coupons/{couponId}` | O M | 수정 (발급 이력이 있으면 기간 연장만 허용) |
| GET | `/api/v1/coupons/{couponId}/issues` | O M | 발급 목록 |
| GET | `/api/v1/customers/{customerId}/coupon-issues?usable=true` | O M | 구매 등록 화면용 사용 가능 쿠폰 |

**POST /coupons**

```json
{ "name": "VIP 감사 쿠폰", "discountType": "RATE", "discountValue": 15, "maxDiscountAmount": 30000, "validFrom": "2026-10-01", "validTo": "2026-10-31" }
```

오류: `COUPON_INVALID_PERIOD`(400), `COUPON_RATE_CAP_REQUIRED`(400), `COUPON_ALREADY_ISSUED`(409).

- 정률(`RATE`)은 `discountValue` 1~100, `maxDiscountAmount` 필수. 정액(`AMOUNT`)의 `maxDiscountAmount`는 무시하고 `null`로 저장한다.
- `PUT /coupons/{couponId}`는 POST와 같은 본문 전체를 받는다. 발급 이력이 있으면 다른 값은 그대로 두고 `validTo`를 같거나 늦게 바꾸는 것만 허용하며, 그 외 변경은 `COUPON_ALREADY_ISSUED`(409).
- 날짜는 `YYYY-MM-DD`, 유효기간은 시작일·종료일 당일을 포함한다(Asia/Seoul 기준).

**GET /coupons 응답 data** (페이징, 최근 생성순. 상세·생성·수정 응답은 `content[0]`과 같은 형식)

```json
{ "content": [ { "couponId": 3, "name": "VIP 감사 쿠폰", "discountType": "RATE", "discountValue": 15, "maxDiscountAmount": 30000,
    "validFrom": "2026-10-01", "validTo": "2026-10-31", "issuedCount": 120, "usedCount": 18,
    "createdAt": "2026-09-28T10:00:00+09:00", "updatedAt": "2026-09-28T10:00:00+09:00" } ],
  "page": 0, "size": 20, "totalElements": 1, "totalPages": 1 }
```

**GET /coupons/{couponId}/issues 응답 data** (페이징, 최근 발급순. 토큰은 고객 페이지 접근 수단이라 넣지 않는다)

```json
{ "content": [ { "issueId": 318, "customerId": 501, "customerName": "김민지", "sendLogId": 9001,
    "issuedAt": "2026-10-02T09:00:03+09:00", "usedAt": null, "status": "USABLE" } ],
  "page": 0, "size": 20, "totalElements": 1, "totalPages": 1 }
```

**GET /customers/{customerId}/coupon-issues 응답 data** (페이징 없음, 최근 발급순. `usable=true`면 미사용이고 오늘이 유효기간 안인 것만)

```json
[ { "issueId": 318, "couponId": 3, "couponName": "VIP 감사 쿠폰", "discountType": "RATE", "discountValue": 15,
    "maxDiscountAmount": 30000, "validFrom": "2026-10-01", "validTo": "2026-10-31",
    "issuedAt": "2026-10-02T09:00:03+09:00", "usedAt": null, "status": "USABLE" } ]
```

발급 상태 `status`는 저장하지 않고 매번 계산한다: 사용했으면 `USED`(기간보다 우선), 시작 전 `NOT_STARTED`, 종료 후 `EXPIRED`, 그 외 `USABLE`.

## 8. 고객 공개 API (팀원1·팀원3)

| 메서드 | 경로 | 담당 | 설명 |
|---|---|---|---|
| GET | `/api/v1/public/coupons/{token}` | 팀원3 | 쿠폰 카드 정보 조회 (상태 변경 없음) |
| POST | `/api/v1/public/coupons/{token}/use` | 팀원3 | 쿠폰 사용 처리 (1회, 유효기간 안) |
| GET | `/api/v1/public/unsubscribe/{token}` | 팀원1 | 수신거부 확인 화면 정보 (상태 변경 없음) |
| POST | `/api/v1/public/unsubscribe/{token}` | 팀원1 | 수신거부 처리 |
| POST | `/api/v1/unsubscribe/one-click/{token}` | 팀원1 | 메일 헤더 원클릭 수신거부 (이메일 채널만) |

- GET은 절대 상태를 바꾸지 않는다(링크 스캐너 대응).
- 응답에 이메일·휴대폰 원문을 넣지 않는다. 이름은 성+마스킹(예: `김**`) 또는 이름만.

**GET /public/coupons/{token} 응답 data**

```json
{ "customerName": "김민지", "couponName": "가을 감사 쿠폰", "discountType": "AMOUNT", "discountValue": 5000, "maxDiscountAmount": null, "validFrom": "2026-10-01", "validTo": "2026-10-31", "status": "USABLE" }
```

`status`: `USABLE`, `USED`, `EXPIRED`, `NOT_STARTED`. 없는 토큰(UUID 형식이 아닌 값 포함): `COUPON_NOT_FOUND`(404).
`customerName`은 첫 글자만 남기고 마스킹한다(`김**`). 이름이 없는 고객이면 `null`이고 화면에서 "고객"으로 표시한다.

**POST /public/coupons/{token}/use**: 요청 본문 없음. 성공하면 위와 같은 카드(`status: "USED"`)를 돌려준다. `coupon_issue.used_at`만 기록하고 `purchase`는 만들지 않는다(PRD F-10 ②). 오류: `COUPON_ALREADY_USED`(409), 기간 밖 `COUPON_NOT_USABLE`(422), `COUPON_NOT_FOUND`(404).

**POST /public/unsubscribe/{token}**

```json
// 요청
{ "channel": "EMAIL" }   // EMAIL | SMS | ALL
// 응답 data
{ "channels": ["EMAIL"], "processedAt": "2026-09-30T18:20:51+09:00" }
```

- 토큰 = Base64URL(`send_log_id:customer_id:HMAC-SHA256`). 검증 실패: `UNSUBSCRIBE_INVALID_TOKEN`(400), 화면에는 "유효하지 않은 링크"만 표시.
- 처리: 동의 N, `suppression` 추가, `consent_history`(source=UNSUBSCRIBE).

## 9. 추적·웹훅 (팀원3 · 팀원1)

| 메서드 | 경로 | 담당 | 응답 |
|---|---|---|---|
| GET | `/t/o/{trackingToken}.gif` | 팀원3 | 항상 200, 1x1 투명 GIF, `Cache-Control: no-store` |
| GET | `/t/c/{trackingToken}/{linkId}` | 팀원3 | 항상 302 → `track_link.original_url` (없는 링크면 서비스 홈) |
| POST | `/api/webhooks/ses` | 팀원1 | 200 (SNS 서명 검증 실패 시 무시하고 200, 로그만) |

- 이벤트 저장은 비동기. 없는 토큰은 응답은 정상, 저장만 하지 않는다.
- 봇 판정(발송 후 10초 이내, 스캐너 User-Agent, 1초 안 전체 링크 클릭)은 저장 시 `bot_yn`으로 기록한다.
- SES 웹훅: `SubscriptionConfirmation` 처리, `Bounce(Permanent)`·`Complaint` → `provider_message_id`로 send_log 조회 → BOUNCED, suppression 추가, 동의 N.

## 10. 대시보드·성과 리포트 (팀원3 · `tracking`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| GET | `/api/v1/dashboard/summary` | O M S | 총 발송·오픈율·클릭률·전환율 (`from`, `to`) |
| GET | `/api/v1/dashboard/daily-sends` | O M S | 일별 발송 건수 (`days`, 기본 14) |
| GET | `/api/v1/dashboard/queue` | O M S | 발송 큐 상태 |
| GET | `/api/v1/dashboard/events` | O M S | 최근 이벤트 (`after` 이벤트 ID, 10초 폴링) |
| GET | `/api/v1/analytics/campaigns/{campaignId}` | O M S | 캠페인 KPI·전환 흐름 |
| GET | `/api/v1/analytics/campaigns/{campaignId}/steps` | O M S | 워크플로우 단계별 집계 |
| GET | `/api/v1/analytics/campaigns/{campaignId}/ab-test` | O M S | A/B 비교 |

모든 지표는 `bot_yn = 'N'`, `kind = 'CAMPAIGN'`만 집계한다.

**지표 정의 (PRD F-09)**
- 발송 시도 `attempted` = `SENT` + `BOUNCED` + `FAILED` (`SKIPPED`·`PENDING`·`SENDING`은 제외), 발송 성공 `sent` = `SENT`
- `uniqueOpens`·`uniqueClicks` = 성공 발송 중 사람 이벤트가 있는 **고유 고객 수**, `couponUsed` = 성공 발송으로 받은 쿠폰을 사용한 고유 고객 수
- 성공률 = sent / attempted, 오픈율·클릭률·전환율 = 고유 고객 수 / sent. 비율은 0~1, 소수 넷째 자리 반올림, 분모가 0이면 0
- 기간은 발송 시각(`sent_at`, 실패 건은 마지막 처리 시각) 기준, 한국 시간 날짜. 오픈·클릭은 발생 시각과 관계없이 해당 발송 건에 귀속

**GET /analytics/campaigns/{campaignId}/steps 응답 data**

```json
{ "campaignId": 51, "name": "가입 환영 여정", "type": "WORKFLOW",
  "steps": [ { "stepId": 301, "nodeType": "SEND_EMAIL", "templateId": 22, "templateName": "VIP 쿠폰 메일", "couponId": 5,
               "kpi": { "attempted": 120, "sent": 118, "successRate": 0.9833, "uniqueOpens": 40, "openRate": 0.339, "uniqueClicks": 12, "clickRate": 0.1017, "couponUsed": 6, "conversionRate": 0.0508 } } ] }
```

- `SEND_EMAIL`·`SEND_SMS` 단계만, `step_id` 순(워크플로우 저장 시 노드 순서). `kpi`는 캠페인 KPI와 같은 정의를 그 단계(`send_log.step_id`) 발송에만 적용한 값.
- 일회성 캠페인은 `steps: []`. `templateId`가 숫자가 아니거나 템플릿이 지워졌으면 `templateId`·`templateName`은 `null`. 없는 캠페인: `COMMON_NOT_FOUND`(404).

**GET /dashboard/summary?from=2026-09-25&to=2026-10-01 응답 data**

`from`·`to`는 `YYYY-MM-DD`, 양 끝 포함, 최대 366일. 생략하면 오늘 포함 최근 7일. 오류: `COMMON_INVALID_INPUT`(400)

```json
{ "from": "2026-09-25", "to": "2026-10-01",
  "kpi": { "attempted": 10000, "sent": 9812, "successRate": 0.9812, "uniqueOpens": 3061, "openRate": 0.312, "uniqueClicks": 667, "clickRate": 0.068, "couponUsed": 204, "conversionRate": 0.0208 } }
```

**GET /dashboard/daily-sends?days=14 응답 data** — 오늘 포함 최근 `days`일(1~90), 오래된 날짜부터, 발송 없는 날은 0

```json
[ { "date": "2026-09-18", "sent": 0 }, { "date": "2026-09-19", "sent": 1204 } ]
```

**GET /dashboard/queue 응답 data**

```json
{ "pending": 4210, "sending": 14, "retrying": 3, "ratePerSecond": 14, "expectedEndAt": "2026-09-30T18:42:00+09:00", "adSendWindowOpen": true }
```

- 큐는 운영 상태라 TEST·NOTICE도 포함한다(같은 큐를 쓰므로). `pending` = 아직 시도하지 않은 PENDING, `retrying` = 재시도 대기 PENDING(`attempt_count > 0`), 둘은 겹치지 않는다.
- `expectedEndAt` = 지금 + (pending + retrying + sending) ÷ `ratePerSecond`(초). 남은 건이 없으면 `null`. `adSendWindowOpen`은 08:00 이상 20:50 미만.

**GET /dashboard/events?after=1520&size=20 응답 data** — 오픈·클릭 최신순(봇·TEST·NOTICE 제외), `size` 1~100(기본 20)

```json
{ "events": [ { "eventId": 1523, "eventType": "CLICK", "occurredAt": "2026-10-01T10:15:02+09:00", "campaignId": 42, "campaignName": "가을 감사 쿠폰 발송", "customerName": "홍길동" } ],
  "lastEventId": 1523 }
```

- 10초 폴링은 직전 응답의 `lastEventId`를 `after`로 넘긴다. 새 이벤트가 없으면 `events`는 빈 배열이고 `lastEventId`는 받은 `after` 그대로다. 첫 호출은 `after` 없이 최신 `size`개.
- 화면의 "활성 캠페인 현황"은 별도 API 없이 `GET /campaigns?status=ACTIVE`(6장)와 아래 캠페인 성과 API를 함께 쓴다.

**GET /analytics/campaigns/{id} 응답 data**

```json
{
  "campaignId": 42, "name": "가을 감사 쿠폰 발송",
  "kpi": { "attempted": 10000, "sent": 9812, "successRate": 0.981, "uniqueOpens": 3061, "openRate": 0.312, "uniqueClicks": 667, "clickRate": 0.068, "couponUsed": 204, "conversionRate": 0.021 },
  "funnel": [ { "stage": "ATTEMPTED", "count": 10000 }, { "stage": "SENT", "count": 9812 }, { "stage": "OPENED", "count": 3061 }, { "stage": "CLICKED", "count": 667 }, { "stage": "CONVERTED", "count": 204 } ]
}
```

## 11. AI (팀원3 · `ai`)

| 메서드 | 경로 | 권한 | 설명 |
|---|---|---|---|
| POST | `/api/v1/ai/copy-drafts` | O M S | AI-01 제목·본문 3안 |
| GET | `/api/v1/ai/send-time-recommendations` | O M | AI-02 발송 시간 추천 (`targetCount`, `adYn`) |
| POST | `/api/v1/ai/reports/campaigns/{campaignId}` | O M | AI-03 성과 요약 생성·재생성 |
| GET | `/api/v1/ai/reports/campaigns/{campaignId}` | O M S | 최근 요약 조회 |

**POST /ai/copy-drafts**

```json
// 요청
{ "purpose": "가을 쿠폰 안내", "target": "20~30대 수도권 우수 고객", "tone": "친근하게", "keyMessage": "5,000원 할인, 10월 한 달" }
// 응답 data
{ "drafts": [ { "subject": "...", "body": "..." }, { "subject": "...", "body": "..." }, { "subject": "...", "body": "..." } ] }
```

- 네 항목 모두 필수(목적·타깃 200자, 톤 50자, 핵심 메시지 500자 이하). 비면 `COMMON_INVALID_INPUT`(400).
- `body`는 HTML이 아닌 평문이고 문단은 빈 줄(`\n\n`)로 나뉜다. 템플릿 에디터에 넣을 때 화면에서 `<p>` 문단으로 바꾼다.
- 치환자는 `{{name|고객}}`만 들어갈 수 있다. 서버가 다른 치환자·HTML 태그·`(광고)` 머리말을 지운다(광고 표기·수신거부 문구는 발송 시 자동 삽입).
- 응답이 형식에 맞지 않거나 3안이 안 되면 `AI_UNAVAILABLE`(503). 화면은 오류 안내와 재시도 버튼을 둔다(PRD 5.3).

**GET /ai/send-time-recommendations 응답 data**

```json
{
  "dataSufficient": true,
  "recommendations": [
    { "dayOfWeek": "TUE", "startTime": "10:00", "score": 0.82, "expectedEndAt": "10:17", "reason": "최근 90일 클릭이 가장 많은 시간대입니다." }
  ]
}
```

- 시간대 집계는 SQL(클릭 2 : 오픈 1 가중치, 봇 제외). LLM은 `reason` 문장만 만든다.
- 가드레일은 코드로 적용: 시작 08:00~20:00, 시작 + 예상 소요 시간 ≤ 20:50.
- 이벤트 100건 미만이면 `dataSufficient: false`, 기본값 평일 10:00.
  - 응답은 `{ "dayOfWeek": "WEEKDAY", "startTime": "10:00", "score": null, ... }` 1건이다.
- `targetCount`는 필수(0~1,000,000). `adYn`은 받지만 판정에 쓰지 않는다. 20:50 가드레일은 광고 여부와 관계없이 항상 적용한다(2026-10-01 결정).
- `dayOfWeek`: `MON`~`SUN` 또는 `WEEKDAY`. `score`는 가장 반응이 좋은 시간대를 1.0으로 한 상대값(소수 둘째 자리). `expectedEndAt`은 분 단위 올림.
- 집계 기준: 최근 90일, 한국 시각, 사람 이벤트(`bot_yn = N`), `kind = CAMPAIGN`. 시작 시각은 정시(HH:00)만 후보다.
- 가드레일에 모두 걸리면(대상이 너무 많은 경우 등) `recommendations`는 빈 배열이다.
- `reason`은 Gemini가 쓰되, 한도 초과·응답 오류여도 요청을 실패시키지 않고 서버가 만든 문장으로 대신한다(추천 자체는 SQL 결과).

**POST /ai/reports/campaigns/{campaignId}** (생성·재생성, 요청 본문 없음) / **GET** (최근 요약) 응답 data

```json
{ "reportId": 7, "campaignId": 42, "content": "가을 감사 쿠폰 발송 캠페인은 ... (5문장 이내 평문)", "model": "gemini-3.1-flash-lite",
  "input": { "campaignName": "가을 감사 쿠폰 발송", "kpi": { "attempted": 40, "sent": 38, "successRate": 0.95, "uniqueOpens": 14, "openRate": 0.3684,
    "uniqueClicks": 5, "clickRate": 0.1316, "couponUsed": 0, "conversionRate": 0.0 } },
  "createdAt": "2026-10-01T14:00:00+09:00" }
```

- 지표는 10장 캠페인 성과와 같은 정의다. `input`은 요약을 만든 시점의 값이며, 지표가 바뀌면 재생성한다.
- 재생성할 때마다 `ai_report`에 새 행을 남기고, GET은 가장 최근 것을 돌려준다. 아직 요약이 없으면 `data: null`.
- 성공 발송이 0건이면 LLM을 부르지 않고 `"model": "none"`, 안내 문장을 저장한다.
- 없는 캠페인: `COMMON_NOT_FOUND`(404).

오류: `AI_RATE_LIMITED`(429), `AI_UNAVAILABLE`(503), `AI_PII_DETECTED`(400). LLM 요청에는 고객 개인정보를 넣지 않는다. 서버가 요청 내용에서 이메일·전화번호 패턴을 발견하면 AI로 보내지 않고 `AI_PII_DETECTED`로 거절한다.

## 12. 오류 코드 목록

| 코드 | 상태 | 의미 |
|---|---|---|
| `COMMON_INVALID_INPUT` | 400 | 요청 형식·검증 실패 (`details`에 필드별 사유) |
| `COMMON_NOT_FOUND` | 404 | 대상 없음 |
| `COMMON_INTERNAL_ERROR` | 500 | 예상하지 못한 서버 오류 (서버 로그 확인) |
| `AUTH_UNAUTHORIZED` | 401 | 로그인 필요 |
| `AUTH_TOKEN_EXPIRED` | 401 | Access 토큰 만료 (refresh 후 재시도) |
| `AUTH_INVALID_CREDENTIALS` | 401 | 이메일·비밀번호 불일치 |
| `AUTH_ACCOUNT_LOCKED` | 401 | 5회 실패로 잠금 |
| `AUTH_ACCOUNT_INACTIVE` | 401 | 비활성 계정 |
| `AUTH_FORBIDDEN` | 403 | 권한 없음 |
| `AUTH_CSRF_INVALID` | 403 | CSRF 토큰 없음·불일치 |
| `CUSTOMER_DUPLICATE_EMAIL` | 409 | 삭제되지 않은 고객 중 같은 이메일 존재 |
| `CUSTOMER_INVALID_REGION` / `_PHONE` / `_DATE` | 400 | 정규화 실패 |
| `CUSTOMER_CONSENT_EVIDENCE_REQUIRED` | 422 | 수신거부 해제에 증빙 메모 필요 |
| `CUSTOMER_INVALID_EMAIL` / `_NAME` / `_AMOUNT` / `_CONSENT` | 400 | 업로드 행별 실패 사유 (이메일 없음·형식, 이름 50자 초과, 누적구매액 음수·형식, 수신동의 Y/N 아님). `failures[].reason` 에도 `CUSTOMER_INVALID_REGION`·`_PHONE`·`_DATE`·`CUSTOMER_DUPLICATE_EMAIL`(같은 파일 안 중복)을 쓴다 |
| `UPLOAD_FILE_TOO_LARGE` / `_TOO_MANY_ROWS` / `_INVALID_HEADER` | 400 | 업로드 제한 |
| `UPLOAD_INVALID_FILE` | 400 | xlsx·csv 가 아니거나 읽을 수 없는 파일 |
| `SEGMENT_INVALID_RULE` / `_TOO_MANY_CONDITIONS` | 400 | 조건 오류 |
| `SEGMENT_IN_USE` | 409 | 캠페인이 참조 중 |
| `TEMPLATE_IN_USE` | 409 | 예약·활성·일시정지 캠페인이 사용 중 |
| `TEMPLATE_INVALID_PLACEHOLDER` / `_SUBJECT_REQUIRED` | 400 | 템플릿 오류 |
| `CAMPAIGN_INVALID_STATUS` | 409 | 현재 상태에서 불가능한 전이 |
| `CAMPAIGN_SEND_WINDOW_EXCEEDED` | 422 | 광고성 발송이 20:50을 넘김 |
| `CAMPAIGN_COUPON_REQUIRED` | 422 | `{{couponUrl}}` 템플릿에 쿠폰 미연결 |
| `WORKFLOW_INVALID_STRUCTURE` | 400 | 구조 검증 실패 |
| `COUPON_INVALID_PERIOD` / `_RATE_CAP_REQUIRED` | 400 | 쿠폰 정의 오류 |
| `COUPON_OUT_OF_PERIOD` | 422 | 유효기간 밖 |
| `COUPON_NOT_USABLE` / `COUPON_ALREADY_USED` | 422 / 409 | 사용 불가 |
| `COUPON_ALREADY_ISSUED` | 409 | 발급 이력이 있어 수정 제한 |
| `COUPON_NOT_FOUND` | 404 | 없는 쿠폰·발급·고객 페이지 토큰 |
| `UNSUBSCRIBE_INVALID_TOKEN` | 400 | 수신거부 토큰 검증 실패 |
| `AI_RATE_LIMITED` | 429 | Gemini 한도 초과 |
| `AI_UNAVAILABLE` | 503 | LLM 호출 실패 |
| `AI_PII_DETECTED` | 400 | 요청 내용에 이메일·전화번호 등 개인정보가 있어 AI 전송을 차단 |

## 13. 담당별 API 요약

| 담당 | 영역 |
|---|---|
| PL | 2장 인증·사용자, 공통 응답·예외·CSRF |
| 팀원1 | 3장 고객·구매, 4장 세그먼트, 8장 수신거부, 9장 SES 웹훅 |
| 팀원2 | 5장 템플릿·파일, 6장 캠페인·워크플로우 |
| 팀원3 | 7장 쿠폰, 8장 쿠폰 공개 API, 9장 추적, 10장 대시보드·리포트, 11장 AI |
