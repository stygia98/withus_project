# CLAUDE.md — 위드어스 (Withus)

세그먼트 기반 CRM 마케팅 자동화 솔루션. 고객을 세그먼트로 묶고, 트리거 → 대기 → 조건 분기 → 발송(메일/SMS) 워크플로우를 실행하며, 오픈·클릭·쿠폰 전환을 추적한다.

## 0. 가장 먼저 지킬 것

- **기준 문서는 `docs/prd.md`(PRD v2.3)다.** 이 파일과 PRD가 다르면 PRD를 따른다.
- 작업 전에 해당 기능의 PRD 섹션을 먼저 읽는다. PRD에 없는 동작은 **추측해서 만들지 말고 질문한다.**
- 일정과 담당은 `docs/roadmap.md`를 따른다.
- 세부 기준: API 계약 `docs/api/API_SPEC.md`, 스키마 `docs/db/DB_SCHEMA.md`(V1 DDL 원본), 의존성·설정 `docs/tech/TECH_STACK.md`, 담당별 범위 `docs/roles/`, Git 절차 `docs/workflow-git.md`.
- 워크플로우 엔진, 발송 큐, 세그먼트 동적 쿼리, 인증/CSRF는 **코드를 쓰기 전에 계획(Plan)을 먼저 제시**하고 승인받는다.
- 아래 기술 스택 외의 라이브러리는 추가하지 않는다. 필요하면 이유와 함께 먼저 묻는다.

## 1. 저장소 구조 (폴리레포)

```
withus/                    ← 메인 저장소: 문서·로컬 인프라·배포 설정 (Claude Code는 여기서 실행)
├─ CLAUDE.md
├─ docs/                   prd.md, roadmap.md, ERD, API 계약, 회의록
├─ infra/
│  ├─ docker-compose.yml   PostgreSQL 17, Mailpit
│  └─ aws/                 배포 스크립트·설정
├─ withus_frontend/        ← 독립 Git 저장소 (Next.js)
└─ withus_backend/         ← 독립 Git 저장소 (Spring Boot)
```

- `withus_frontend/`, `withus_backend/`는 메인의 `.gitignore`에 포함되어 있다. 커밋은 **각 저장소 안에서** 한다.
- 한 작업이 두 저장소에 걸치면 저장소별로 나눠 커밋한다.

## 2. 자주 쓰는 명령어

```bash
# 로컬 인프라 (메인 저장소)
cp infra/.env.example infra/.env          # 처음 한 번 (비밀값, 커밋 금지)
cd infra && docker compose up -d          # PostgreSQL 17 + Mailpit
# Mailpit 웹 UI: http://localhost:8025

# 백엔드
cd withus_backend
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
./mvnw test
# Swagger UI: http://localhost:8080/swagger-ui/index.html

# 프론트엔드
cd withus_frontend
npm run dev        # http://localhost:3000 (/api/* 는 rewrites로 백엔드 8080에 프록시)
npm run format     # Prettier
npm run lint
npm run build
```

작업을 끝내기 전에 해당 저장소의 테스트(`./mvnw test`) 또는 `npm run lint && npm run build`를 실행해 통과를 확인한다.

## 3. 기술 스택 (고정)

| 영역 | 기술 |
|---|---|
| 백엔드 | Spring Boot 4.x, JDK 21, Maven(mvnw) |
| 인증 | Spring Security + JWT(jjwt), httpOnly 쿠키, CSRF 토큰 |
| DB | PostgreSQL 17, MyBatis(JPA 사용 금지), Flyway |
| API 문서 | SpringDoc OpenAPI — 프론트와의 API 계약 기준 |
| 스케줄러 | `@Scheduled` + DB 폴링 (Spring Batch 사용 금지) |
| 외부 연동 | `MessageSender`(SMTP→Mailpit / SES / SMS Mock), `FileStorage`(로컬 디스크 / S3), LLM 클라이언트(Gemini) |
| 프론트 | Next.js 15(App Router), React 19, TypeScript 5.x |
| UI | Tailwind CSS 4, shadcn/ui, lucide-react, sonner, date-fns, Motion, 차트는 shadcn Chart(Recharts) |
| 서버 상태 | TanStack Query v5 |
| 메일 에디터 | TinyMCE (자체 설치) |
| 워크플로우 캔버스 | React Flow (선택 기능, 1차는 폼 기반) |

## 4. 백엔드 규칙

**패키지 구조** — 도메인별로 나눈다: `customer`, `segment`, `campaign`(템플릿 포함), `workflow`, `coupon`, `tracking`, `ai`, `auth`, `common`.

```
com.withus.{domain}
├─ controller   # REST 컨트롤러, 요청/응답 DTO 변환만
├─ service      # 비즈니스 로직, 트랜잭션 경계
├─ mapper       # MyBatis Mapper 인터페이스
├─ dto
└─ domain       # 엔티티성 객체, enum
resources/mapper/{domain}/*.xml
resources/db/migration/V{n}__{설명}.sql
```

**DB·MyBatis**
- 테이블·컬럼은 소문자 snake_case, Java는 camelCase(`map-underscore-to-camel-case: true`).
- SQL 파라미터는 `#{}`만 쓴다. `${}`는 금지. 세그먼트 조건의 필드·연산자는 **화이트리스트 매핑**으로만 SQL에 넣는다.
- 스키마 변경은 새 Flyway 파일로만 한다. **이미 적용된 마이그레이션 파일은 절대 수정하지 않는다.**
- 시간 컬럼은 `TIMESTAMPTZ`, Java는 `OffsetDateTime`. JVM과 DB 세션 타임존은 `Asia/Seoul`.
- JSON 컬럼(`segment_rule.rule_json`, `workflow_step.config_json`)은 `JSONB`로 저장하고 Jackson으로 해석한다.

**API**
- 경로: `/api/v1/**`, 추적 `/t/**`, 웹훅 `/api/webhooks/**`.
- 응답은 공통 포맷 `{ success, data, error: { code, message } }`.
- 오류 코드는 `도메인_사유` (예: `SEGMENT_INVALID_RULE`, `CAMPAIGN_INVALID_STATUS`).
- 페이징: `page`(0부터), `size`(기본 20), 응답에 `totalElements`, `totalPages`.
- 날짜/시간은 ISO-8601 문자열(`2026-10-05T09:00:00+09:00`).
- 권한은 `@PreAuthorize`로 API에서 강제한다(역할: `OWNER`, `MANAGER`, `STAFF`, 권한표는 PRD 3장).
- 모든 새 API는 SpringDoc 어노테이션으로 문서화한다.

**트랜잭션·외부 호출**
- SES, SMS, S3, Gemini 호출은 **DB 트랜잭션 밖에서** 한다. 잠금을 잡은 채 외부 API를 부르지 않는다.
- 외부 연동은 인터페이스 뒤에 두고 `local` 프로필용 구현을 함께 만든다. 프로필 전환만으로 운영 배포가 되어야 한다.
- 스케줄 작업은 모두 `fixedDelay`로 실행하고, 스케줄러 스레드 풀은 `spring.task.scheduling.pool.size=5`.

**테스트 필수 대상**
- 세그먼트 규칙 JSON → SQL 변환
- 워크플로우 구조 검증(분기 2단계, 노드 15개, 순환 금지 등)과 단계 실행 로직
- 발송 큐 상태 전이(PENDING → SENDING → SENT/FAILED/SKIPPED)와 발송 직전 재확인
- 입력값 정규화(이메일·휴대폰·지역·날짜)

## 5. 프론트엔드 규칙

- 라우트: 관리자 화면은 PRD 4장 경로를 따른다. 공개 페이지는 `/c/[token]`, `/unsubscribe/[token]`.
- **API 호출은 반드시 상대 경로 `/api/...`로만** 한다(Next.js rewrites가 백엔드로 프록시). 백엔드 도메인을 코드에 직접 쓰지 않는다.
- 공통 fetch 래퍼에서 `credentials: 'include'`와 `X-XSRF-TOKEN` 헤더(쿠키 `XSRF-TOKEN` 값)를 처리한다. 앱 시작 시 `GET /api/v1/auth/csrf`를 먼저 호출한다.
- 토큰을 `localStorage`·`sessionStorage`·JS 변수에 저장하지 않는다. 인증은 httpOnly 쿠키로만 한다.
- 서버 컴포넌트에서 백엔드를 호출할 때는 요청 쿠키를 전달한다.
- TanStack Query 쿼리 키는 도메인별 공통 파일(`lib/query-keys.ts`)에서만 만든다.
- `dangerouslySetInnerHTML` 사용 금지. 메일 HTML 미리보기는 `sandbox` 속성이 있는 iframe으로만 렌더링한다.
- UI 컴포넌트는 shadcn/ui를 우선 사용하고, 알림은 sonner를 쓴다.
- 목록 화면에서 이메일·휴대폰은 일부 마스킹한다.

## 6. 절대 깨면 안 되는 도메인 규칙

아래 규칙은 법규·데이터 정합성과 직결된다. 자세한 내용은 괄호 안 PRD 섹션을 본다.

1. **모든 발송은 공통 발송 큐로만 한다.** 서비스 코드에서 `MessageSender`를 직접 호출하지 않는다. `send_log`에 PENDING으로 적재 → 발송 작업이 우선순위 순으로 처리 (8.2)
2. **발송 직전에 다시 확인한다.** 수신동의, `suppression`, 고객 삭제 여부, 캠페인 상태, 발송 가능 시간 (8.2)
3. **광고성 발송과 수신동의 안내는 08:00~20:50에만 나간다.** 시간 밖이면 다음 날 08:00까지 보류. 20:50을 넘겨 끝날 예약은 막는다. 테스트 발송만 예외 (8.4)
4. **렌더링·쿠폰 발급·추적 링크 치환은 발송 직전에 한다.** SKIPPED 건에는 쿠폰을 발급하지 않는다 (8.2)
5. **`SENDING`으로 10분 넘게 남은 건은 다시 보내지 않고 `FAILED(UNKNOWN_RESULT)`로 처리한다.** 중복 발송보다 누락이 낫다 (8.2)
6. **수신거부는 POST로만 처리한다.** `GET /unsubscribe/[token]`은 확인 화면만 보여준다. 쿠폰 '사용하기'도 POST로만 처리한다 (8.3, F-10)
7. **추적 URL에는 순번 ID를 쓰지 않는다.** `send_log.tracking_token`(UUID)만 쓴다. 수신거부·쿠폰·mailto·tel 링크는 추적 치환하지 않는다 (8.1)
8. **봇 이벤트(`bot_yn = Y`)와 TEST·NOTICE 발송은 모든 지표와 워크플로우 분기에서 제외한다** (8.1, F-09)
9. **입력값은 저장·비교 전에 정규화한다.** 이메일은 소문자 + trim, 휴대폰은 숫자만, 지역은 코드(`SEOUL` 등), 날짜는 `YYYY-MM-DD` (F-01)
10. **`suppression`은 업로드로 해제되지 않는다.** 관리자가 증빙과 함께 동의를 Y로 바꿀 때만 해제 (7장)
11. **광고성 메일·SMS에는 `(광고)`, 발신자 정보, 수신거부 수단을 시스템이 자동 삽입한다.** 템플릿에서 지울 수 없다 (8.4)
12. **LLM(Gemini)에는 고객 개인정보(이름·이메일·휴대폰)를 보내지 않는다.** AI-02의 시간 가드레일은 LLM이 아니라 코드로 적용한다 (5.3)
13. **워크플로우 WAIT는 직전 SEND의 실제 발송 시각(`sent_at`)부터 센다** (6.5)

## 7. 주요 설정 키

| 키 | 값 / 설명 |
|---|---|
| `spring.profiles.active` | `local` (W1~W4), `prod` (W5) |
| `spring.task.scheduling.pool.size` | `5` |
| `ses.max-send-rate` | `1` 유지 (SES 샌드박스 한도, 도메인 미구매 — PRD 10.4) |
| `withus.sender.name` / `withus.sender.phone` | 시연용 `위드어스` / `02-000-0000` |
| `withus.sender.unsubscribe-phone` | 시연용 `080-000-0000` |
| `withus.tracking.bot-click-seconds` | `10` |
| 비밀값 | DB 비밀번호, JWT 키, AWS 키, Gemini 키, HMAC 키는 **환경변수로만** 주입. 저장소에 커밋 금지 |

## 8. 작업 방식

- 한 번에 하나의 기능만 작업하고, 작은 단위로 커밋한다.
- 커밋 메시지: `feat(segment): 조건 빌더 미리보기 API 추가`, `fix(workflow): ...`, `refactor`, `test`, `docs`, `chore`.
- 다른 팀원 담당 도메인의 코드를 바꿔야 하면 직접 고치지 말고, PRD 10.1의 **구간 간 연결 지점 인터페이스**를 통해 호출하거나 먼저 알린다.
- 다른 도메인 **테이블 조회(SELECT)는 자기 mapper에서 직접 해도 된다.** 쓰기(INSERT·UPDATE·DELETE)는 소유 도메인의 서비스·인터페이스로만 한다.
- DB 스키마나 API 계약(요청/응답 형식)을 바꾸는 작업은 `docs/`의 ERD·API 계약 문서도 함께 갱신한다.
- 새 기능을 만들면 PRD 10.3 완료 기준 중 해당 항목을 검증하는 테스트나 확인 절차를 함께 남긴다.

## 9. 하지 말 것

- JPA/Hibernate, Spring Batch, Redux 등 스택에 없는 라이브러리 도입
- MyBatis `${}` 사용, 사용자 입력을 컬럼명·정렬 키로 직접 사용
- 적용된 Flyway 마이그레이션 수정, 운영 DB 직접 수정
- 서비스 코드에서 `MessageSender` 직접 호출(큐 우회)
- GET 요청으로 상태 변경(수신거부, 쿠폰 사용 등)
- 토큰을 브라우저 저장소에 보관, 백엔드 도메인을 프론트 코드에 하드코딩
- 비밀값·API 키 커밋
- PRD에 없는 기능을 임의로 추가하거나 규칙을 추측으로 채우기
