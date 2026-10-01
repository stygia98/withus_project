# Plan — 세그먼트 규칙 JSON → 동적 SQL (팀원1, W2)

> 상태: **PL 승인 완료** (메인 저장소 PR #1) · 작성: 팀원1 · 2026-10-01 — 구현 전 맨 아래 "10. PL 승인 결과"를 먼저 읽는다
> 근거: PRD F-03·F-11·3장(권한)·6.2(트리거)·9장(성능)·10.3, `DB_SCHEMA.md` 5.1, `API_SPEC.md` 4장, CLAUDE.md 0·4·9장
> CLAUDE.md 0장에 따라 세그먼트 동적 쿼리는 코드보다 Plan을 먼저 승인받는다. 승인 전에는 코드를 쓰지 않는다.

## 1. 목표와 범위

- `segment_rule.rule_json`(JSONB)을 검증한 뒤 MyBatis 동적 SQL로 바꿔 대상 고객을 계산한다. 세그먼트는 동적이라 저장된 결과가 없고, 매번 다시 계산한다 (F-03).
- 산출물:
  - `SegmentService.findTargetCustomers(segmentId)` 실제 구현 (동결된 인터페이스, 팀원2가 호출)
  - API_SPEC 4장 API 7개: 목록·상세·생성·수정·삭제·미리보기·필드 목록
- 범위 밖: 세그먼트 빌더 화면(프론트, 별도 태스크), 워크플로우 트리거 판정 로직(팀원2).
- 스키마 변경 없음. V1 테이블(`segment`, `segment_rule`, `customer`)만 사용하므로 Flyway 파일을 추가하지 않는다.

## 2. 처리 흐름

```
rule_json (요청 본문 또는 segment_rule)
  → ① Jackson 파싱 → SegmentRule 레코드 (operator, groups[operator, conditions[field, op, value]])
  → ② 검증: 구조·개수·필드×연산자 화이트리스트·값 형식  (실패 시 BusinessException)
  → ③ 변환: 조건마다 SqlCondition(column enum, op enum, 파라미터 값)으로 바꿈
           age·IN_LAST_DAYS 같은 상대 조건은 이 단계에서 today 기준 날짜로 계산
  → ④ MyBatis XML: <foreach> 그룹·조건 순회, <choose>로 column·op enum → 고정 SQL 조각
           값은 모두 #{} 바인딩, deleted_yn = 'N' 은 XML에 고정
```

- ①~③은 DB 없이 단위 테스트할 수 있는 순수 Java(`SegmentRuleTranslator`)로 둔다. `today`는 인자로 받는다. 기본값은 `LocalDate.now(Asia/Seoul)`로, JVM 타임존이 `Asia/Seoul`이어서 DB `CURRENT_DATE`와 같다.
- `${}`는 쓰지 않는다. 사용자 입력은 enum으로만 바뀌고, enum은 XML의 `<when test="c.column == @...@REGION_CODE">region_code</when>`처럼 고정 문자열로만 SQL에 들어간다.

## 3. 필드 × 연산자 화이트리스트 (DB_SCHEMA 5.1 그대로)

| field | 컬럼 | 허용 연산자 | value 검증 |
|---|---|---|---|
| `region` | `region_code` | EQ, NE, IN | `Region` enum 코드(고객 정규화와 같은 enum). IN은 1~17개 배열, 중복 제거 |
| `age` | `birth_date` | EQ, GT, GTE, LT, LTE, BETWEEN | 0~150 정수. BETWEEN은 `[min, max]`, min ≤ max |
| `joinedAt` | `joined_at` | BETWEEN, IN_LAST_DAYS | BETWEEN `["YYYY-MM-DD","YYYY-MM-DD"]`(`CustomerNormalizer.date` 재사용), IN_LAST_DAYS 1~3650 정수 |
| `totalPurchase` | `total_purchase` | EQ, GT, GTE, LT, LTE, BETWEEN | 0 이상 정수. BETWEEN은 min ≤ max |
| `emailConsent` | `email_consent_yn` | EQ | "Y" / "N" |
| `smsConsent` | `sms_consent_yn` | EQ | "Y" / "N" |
| `dormant` | `dormant_yn` | EQ | "Y" / "N" |

**만 나이 변환** (DB_SCHEMA 5.1 예시 식 그대로, today = 기준일)

| 조건 | SQL (`birth_date` 범위, 인덱스 `ix_customer_birth_date` 사용) |
|---|---|
| age ≥ a (GTE) | `birth_date <= today - a년` |
| age ≤ b (LTE) | `birth_date > today - (b+1)년` |
| age > a / age < b | GTE a+1 / LTE b-1 로 바꿔 위와 같이 |
| age = a (EQ) | GTE a AND LTE a |
| BETWEEN a, b | `birth_date > today - (b+1)년 AND birth_date <= today - a년` ← 문서 예시와 동일 |

- `birth_date`가 NULL인 고객은 나이 조건에서 항상 빠진다(SQL 비교 결과가 NULL).
- 날짜는 Java `LocalDate.minusYears`로 계산해 `#{}`로 넘긴다. 기준일이 2월 29일인데 뺀 해가 평년이면 2월 28일로 맞춘다(PostgreSQL `INTERVAL`과 같은 동작).

## 4. 검증과 오류 (API_SPEC 4장·12장)

| 위반 | 오류 코드 |
|---|---|
| 조건 합계 10개 초과 | `SEGMENT_TOO_MANY_CONDITIONS` (400) |
| 최상위·그룹 operator가 AND/OR가 아님, 그룹 안에 그룹(2단계), 빈 그룹 | `SEGMENT_INVALID_RULE` (400) |
| 모르는 field, 필드에 허용되지 않은 op, value 형식·범위 오류 | `SEGMENT_INVALID_RULE` (400) |
| 삭제하려는 세그먼트를 캠페인이 참조 | `SEGMENT_IN_USE` (409) |

- 오류 `details`에 위치를 담는다. 예: `{ "path": "groups[1].conditions[0]", "reason": "age 에 IN 은 쓸 수 없습니다" }`. 프론트 빌더가 해당 조건에 오류를 표시할 수 있게 하기 위해서다.
- 저장할 때(생성·수정)와 미리보기 때 같은 검증을 탄다. 이미 저장된 규칙도 계산할 때 다시 검증한다. 저장 이후 화이트리스트가 바뀌어도 잘못된 SQL이 나가지 않게 하기 위해서다.
- `SEGMENT_IN_USE`는 `campaign.segment_id`를 SELECT로 확인한다. 다른 도메인 테이블 조회는 허용(workflow-git.md)되고, 쓰기는 하지 않는다.

## 5. SQL과 성능 (목표: 고객 10만 명 미리보기 2초)

```sql
-- 대상 계산 (findTargetCustomers) — 그룹·조건은 <foreach>, 연결어는 rule 의 AND/OR
SELECT customer_id FROM customer
WHERE deleted_yn = 'N'
  AND ( (region_code IN (#{..}, #{..}) OR total_purchase >= #{..})
    AND (birth_date > #{..} AND birth_date <= #{..} AND joined_at >= #{..}) )
ORDER BY customer_id

-- 미리보기 — 한 번 스캔으로 4개 숫자 (API_SPEC 4장 응답 형식)
SELECT count(*)                                        AS total,
       count(*) FILTER (WHERE email_consent_yn = 'Y') AS email_consent,
       count(*) FILTER (WHERE sms_consent_yn = 'Y')   AS sms_consent,
       count(*) FILTER (WHERE dormant_yn = 'Y')       AS dormant
FROM customer WHERE deleted_yn = 'N' AND ( ...같은 조건 조각... )
```

- 조건 조각은 `<sql id="ruleWhere">` 하나로 두고, 대상 조회·미리보기·목록 대상 수가 모두 공유한다. 계산 방식이 하나뿐이라 결과가 어긋나지 않는다.
- V1에 `region_code`·`joined_at`·`birth_date`·`total_purchase` 인덱스가 이미 있다. 10만 행 기준으로는 OR 조합에서 순차 스캔이 나와도 수십 ms 수준으로 예상한다. **검증 방법:** 로컬 DB에 `generate_series`로 10만 명을 넣고 대표 규칙 3개를 `EXPLAIN ANALYZE`해 결과를 PR에 첨부한다(시연 데이터에는 넣지 않는다).
- `findTargetCustomers`는 `List<Long>`을 반환한다(동결 시그니처). 10만 개 ID는 약 1MB라 메모리 문제가 없다. 10.3의 "1만 명 SEGMENT_SCHEDULED 한 주기 적재"도 쿼리 1회로 끝난다.
- 세그먼트 목록의 "현재 대상 수"는 세그먼트마다 count를 한 번씩 돌린다(페이지당 20개 × 수십 ms). 느리면 그때 캐시를 검토한다.

## 6. 패키지 구성 (CLAUDE.md 4장)

```
segment/controller/SegmentController          API 7개, @PreAuthorize(조회 O·M·S / 변경 O·M, PRD 3장)
segment/service/SegmentServiceImpl            SegmentService 구현 + CRUD·미리보기
segment/service/SegmentRuleTranslator         ①~③ 파싱·검증·변환 (순수 Java, 단위 테스트 대상)
segment/domain/SegmentField, SegmentOperator  화이트리스트 enum (필드별 허용 연산자 포함)
segment/domain/SegmentErrorCode               SEGMENT_INVALID_RULE / _TOO_MANY_CONDITIONS / _IN_USE
segment/mapper/SegmentMapper + resources/mapper/segment/SegmentMapper.xml
```

- `GET /segments/fields`는 `SegmentField` enum에서 바로 만든다. 프론트 빌더와 서버의 화이트리스트가 한 곳에서 나와서 어긋나지 않는다.
- 고객 도메인의 `Region` enum과 `CustomerNormalizer.date`를 재사용한다. 둘 다 팀원1 소유라 다른 구간에 영향이 없다.

## 7. 테스트 (CLAUDE.md 테스트 필수 대상: 세그먼트 규칙 JSON → SQL 변환)

**단위 (DB 없음, `SegmentRuleTranslator`)**
- DB_SCHEMA 5.1 예시 규칙이 그대로 통과하고, 기대한 SqlCondition 목록이 나온다
- 조건 11개 → `TOO_MANY_CONDITIONS` / 그룹 2단계·빈 그룹·잘못된 operator → `INVALID_RULE`
- 필드×연산자 표 밖의 조합 전부 거부(예: `age IN`, `region GT`, `emailConsent NE`)
- value 오류: BETWEEN 원소 1개, min > max, 음수 금액, 없는 지역 코드, 잘못된 날짜, IN 빈 배열
- 만 나이 경계(today 고정 2026-10-01): age BETWEEN 20,34 → `(1991-10-01, 2006-10-01]`, 생일 당일·전날, 2월 29일생
- IN_LAST_DAYS 경계(Q2 답에 맞춰 확정)

**SQL (로컬 Docker DB, `@Transactional` 롤백)**
- 고유 태그로 고객을 시드하고 연산자별 대상 수 확인. 삭제 고객 제외, AND/OR 그룹 조합
- 미리보기 4개 숫자가 대상 조회 결과와 맞는지
- PRD 10.3: "서울·경기, 구매액 10만 원 이상" 세그먼트를 만들고 대상 수가 미리보기된다
- 삭제: 캠페인 참조 시 409, 권한(STAFF는 조회만)

## 8. 병합 순서 (M2를 막지 않도록 — roadmap 4장 의존 관계)

| 단계 | 내용 | 목표 |
|---|---|---|
| **1차** | 파싱·검증 골격, region(EQ·IN)·totalPurchase(비교)·emailConsent·smsConsent·dormant, 그룹 AND/OR, `findTargetCustomers` 실제 구현 + **`SegmentServiceStub` 삭제**, 생성·조회·미리보기 API | W2 초 (2일) — 팀원2가 실제 대상으로 일회성 발송 E2E 진행 |
| **2차** | age(만 나이 변환), joinedAt(BETWEEN·IN_LAST_DAYS), region NE, 수정·삭제(`SEGMENT_IN_USE`)·필드 목록 API, 10만 명 성능 측정 | W2 중반 |

- stub은 1차 PR에서 삭제한다. 같은 인터페이스의 빈이 2개면 기동이 실패한다(README). 1차 병합 시점에 팀원2에게 알린다.

## 9. PL 확인 요청 (문서에 정의 없음)

| # | 질문 | 제안안 |
|---|---|---|
| Q1 | `region NE 'SEOUL'`일 때 지역이 비어 있는(NULL) 고객을 포함할까? | **포함하지 않음** (SQL 기본 동작, "지역을 아는 고객 중 서울 외"). 포함하려면 `IS DISTINCT FROM` |
| Q2 | `joinedAt IN_LAST_DAYS N`의 경계는? | **오늘 포함 N일**: `joined_at > today - N` (N=1이면 오늘 가입자만) |
| Q3 | 조건이 0개인 규칙(전체 고객)을 허용할까? | **허용하지 않음** (최소 1개, 실수로 전체 발송되는 것 방지) |
| Q4 | 미리보기 `emailConsent`·`smsConsent` 수에서 suppression 대상을 뺄까? | **빼지 않음** (동의 컬럼 기준, suppression 대상은 등록 때 이미 N). 실제 발송 가능 여부는 발송 직전 `ConsentService`가 판정 |
| Q5 | `CUSTOMER_REGISTERED` 트리거(PRD 6.2)는 "개별 등록 고객이 세그먼트 조건에 맞는지" 한 명만 판정해야 한다. 동결된 인터페이스에는 `findTargetCustomers`뿐이다 | 팀원2가 `findTargetCustomers(...).contains(id)`로 판정(추가 작업 없음, 10만 명에서도 1회 수십 ms). 부족하면 `matches(segmentId, customerId)` 추가를 PL 리뷰로 |
| Q6 | 제출·승인 방식 | 이 문서를 메인 저장소 PR로 올리고, PR 승인 = Plan 승인으로 본다 |

## 10. PL 승인 결과

Plan을 승인한다 (메인 저장소 PR #1). 화이트리스트·`#{}` 바인딩·`deleted_yn` 고정·순수 Java 변환 테스트 분리·1차/2차 병합 순서 모두 그대로 진행한다.

**구현할 때 반영할 것**

| # | 내용 | 이유 |
|---|---|---|
| R1 | 그룹·조건 **연결어(AND/OR)도** `SegmentOperator`처럼 enum으로 받아 XML `<choose>`의 고정 문자열로만 넣는다. `${operator}`로 넣지 않는다 | 5장 SQL의 "연결어는 rule의 AND/OR"가 사용자 입력이라, 그대로 넣으면 그 자리가 인젝션 지점이 된다 |
| R2 | 10만 명 성능 측정(5장)은 **트랜잭션 안에서 넣고 롤백**하거나 별도 스키마에서 한다 | 로컬 시드 데이터(`R__seed_local.sql`)와 섞이지 않게 |

**9장 질문 답변 — 모두 제안안대로 확정**

| # | 결정 |
|---|---|
| Q1 | `region NE`는 지역이 NULL인 고객을 **포함하지 않는다** (SQL 기본 동작) |
| Q2 | `joinedAt IN_LAST_DAYS N`은 **오늘 포함 N일**: `joined_at > today - N` |
| Q3 | 조건 0개 규칙은 **허용하지 않는다** (`SEGMENT_INVALID_RULE`) |
| Q4 | 미리보기 동의 수에서 suppression을 **빼지 않는다**. 최종 발송 가능 여부는 발송 직전 `ConsentService`가 판정 |
| Q5 | `CUSTOMER_REGISTERED` 단건 판정은 팀원2가 `findTargetCustomers(...).contains(id)`로 시작한다. 부족하면 `matches(segmentId, customerId)` 추가를 PL 리뷰로 |
| Q6 | Plan은 `docs/plans/`에 문서로 올리고 **PR 승인 = Plan 승인**으로 한다 (`docs/workflow-git.md`) |

**참고:** 로컬 시드(`feature/seed-data`, PL)의 세그먼트 "서울·경기 구매 10만 원 이상"은 대상이 35명이다. 7장의 PRD 10.3 시나리오 확인에 그대로 쓸 수 있다.
