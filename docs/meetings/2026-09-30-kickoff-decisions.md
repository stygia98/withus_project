# 2026-09-30 킥오프 결정 사항 (PL 확정)

W1 첫 회의 안건을 PL이 권장안으로 확정했다. 팀원은 이 문서를 먼저 읽고 시작한다. 이의가 있으면 PL에게 알리고, 바꾸는 경우 이 문서와 해당 기준 문서를 함께 갱신한다.

## 1. 스키마·인터페이스 동결
| 대상 | 결정 | 기준 문서 |
|---|---|---|
| Flyway `V1__init.sql` (18개 테이블) | **확정·동결**. 절대 수정하지 않는다. 변경은 번호 대역에 맞는 새 파일로만 | `docs/db/DB_SCHEMA.md`, `docs/workflow-git.md` |
| 구간 간 인터페이스 6개 | **시그니처 확정**. 변경은 PL 리뷰 | `withus_backend/README.md` |
| local 시드 | `R__seed_local.sql`(반복 실행, 버전 번호 없음) | `docs/db/DB_SCHEMA.md` 9장 |
| Flyway 번호 대역 | PL `V2~V9`, 팀원1 `V10~V19`, 팀원2 `V20~V29`, 팀원3 `V30~V39`. `out-of-order` 허용 | `docs/workflow-git.md` |

확정된 인터페이스:

| 인터페이스 | 제공 | 호출 |
|---|---|---|
| `segment.service.SegmentService#findTargetCustomers(segmentId)` | 팀원1 | 팀원2 |
| `customer.service.ConsentService#isSendable(customerId, channel)` | 팀원1 | 팀원2 |
| `tracking.service.TrackingLinkService#rewrite(html, sendLogId)` | 팀원3 | 팀원2 |
| `tracking.service.TrackEventRepository#existsHumanEvent(sendLogId, eventType)` | 팀원3 | 팀원2, 팀원1 |
| `coupon.service.CouponService#issue(...)`, `#markUsed(couponIssueId)` | 팀원3 | 팀원2, 팀원1 |
| `common.render.PlaceholderRenderer#render(...)`, `#usesDefault(...)` | 팀원3 | 팀원2 |

## 2. 기술 스택 (TECH_STACK 6장)
| 항목 | 결정 | 적용 상태 |
|---|---|---|
| Lombok | 사용. `@Getter`·`@RequiredArgsConstructor`·`@Builder`만 | 추가 완료. 그 외는 `lombok.config`로 컴파일 오류 |
| 폼 | react-hook-form + zod | 추가 완료 |
| 메일 에디터 | TinyMCE 자체 설치, GPLv2+ (`license_key: 'gpl'`) | 팀원2가 W1에 설치 |
| SES API | `sesv2` | 팀원2, W2 |
| SNS 서명 검증 | AWS SDK 기능 우선 | 팀원1, W3 |
| Gemini 모델 | 무료 등급의 가장 가벼운 텍스트 모델 | 팀원3이 W1에 모델명·한도 확인 후 TECH_STACK 5장 기록 |
| 포맷터 | 프론트 Prettier만 (`npm run format`) | 적용 완료. 기존 코드 일괄 포맷함 |
| 로컬 DB 비밀번호 | `infra/.env`에서 읽음 | 적용 완료 |

## 3. W1 우선 작업과 기한
| 담당 | 먼저 할 일 | 기한 | 이유 |
|---|---|---|---|
| 팀원1 | `SegmentService`·`ConsentService` **stub** 병합 (고정값 반환) | **W1 수요일** | 팀원2가 기다리지 않고 발송 큐를 개발 |
| 팀원3 | `TrackingLinkService`·`CouponService`·`TrackEventRepository`·`PlaceholderRenderer` **stub** 병합 | **W1 수요일** | 위와 같음 |
| 팀원2 | **발송 큐 설계 Plan** 작성 → PL 승인 | W2 착수 전 | CLAUDE.md: 발송 큐는 Plan 선행 대상. 최대 난이도 구간 |
| 팀원3 | Gemini 모델명·호출 한도 확인 | W1 | 위 2번 |

stub 은 실제 구현으로 나중에 교체한다. 호출 측 코드는 바꿀 필요가 없다.

## 4. 이미 준비된 것 (PL)
- 로그인·CSRF·공통 응답·오류 처리 (사용법: `withus_backend/README.md` "팀원용 사용법")
- Swagger 에서 `csrf` → `login` 후 POST 테스트 가능 (CSRF 헤더 자동)
- 최초 OWNER 계정: 각자 `infra/.env`의 `OWNER_EMAIL`/`OWNER_PASSWORD`
