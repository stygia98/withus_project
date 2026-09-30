# TECH_STACK.md — 위드어스 (Withus) 기술 스택

> 기준: `docs/prd.md` (PRD v2.3) 2장 · 상태: **확정 (PL 결정)** — 6장 합의 항목 결정 완료. 이후 변경은 PL 리뷰를 거친다.

스택은 PRD에서 이미 확정됐다. 이 문서는 그 스택을 **실제 의존성·버전·설정 수준**으로 풀어, W1에 저장소를 만들 때 그대로 따라 할 수 있게 한다. 버전은 "메이저 확정 + 마이너는 W1 시점 최신 안정판"을 원칙으로 하고, 확정한 정확한 버전은 5장 표에 기록한다.

## 1. 전체 구성

```
[브라우저] ──https──▶ [AWS Amplify: Next.js 15 SSR]  app.<도메인>
                          │  rewrites /api/* (쿠키 퍼스트파티, CORS 불필요)
                          ▼
                     [EC2: Nginx + Let's Encrypt]      api.<도메인>
                          │
                          ▼
                     [Spring Boot 4 (단일 인스턴스)]
                      ├─ PostgreSQL 17 (RDS, 자동 백업 7일)
                      ├─ AWS SES (메일) ◀── SNS 반송·스팸신고 웹훅
                      ├─ AWS S3 (템플릿 이미지, CSV 원본)
                      ├─ SMS (Mock, 실제 연동은 선택)
                      └─ Google Gemini API (백엔드에서만 호출)

[메일 수신자] ──▶ api.<도메인>/t/**, /api/v1/unsubscribe/one-click/**  (메일 속 링크)
```

로컬(W1~W4)은 `docker compose`의 PostgreSQL·Mailpit + 로컬 디스크 + SMS Mock으로 같은 구조를 흉내 낸다. 프로필(`local` / `prod`)만 바꿔 전환한다.

## 2. 백엔드

### 2.1 기반

| 항목 | 선택 | 비고 |
|---|---|---|
| 언어 | Java 21 (LTS) | 가상 스레드는 기본 사용하지 않음 (스케줄러·트랜잭션 동작을 단순하게 유지) |
| 프레임워크 | Spring Boot 4.x | 초기화: start.spring.io, Maven, Jar 패키징 |
| 빌드 | Maven Wrapper(`mvnw`) | 팀원 로컬 Maven 버전 차이 방지 |
| 패키지 루트 | `com.withus` | 도메인별 하위 패키지 (CLAUDE.md 4장) |

### 2.2 의존성

| 목적 | 의존성 | 비고 |
|---|---|---|
| 웹 | `spring-boot-starter-webmvc` | REST (Boot 4 에서 `starter-web` 이름이 바뀜) |
| 검증 | `spring-boot-starter-validation` | 요청 DTO `@Valid` |
| 보안 | `spring-boot-starter-security` | 쿠키 JWT 필터, CSRF(SPA 설정) |
| JWT | `io.jsonwebtoken:jjwt-api`, `jjwt-impl`, `jjwt-jackson` | Access 30분 / Refresh 7일 |
| DB | `org.postgresql:postgresql` | |
| SQL 매퍼 | `org.mybatis.spring.boot:mybatis-spring-boot-starter` | 4.0.1 (Boot 4.0.x 호환, 5장) |
| 마이그레이션 | `spring-boot-starter-flyway`, `flyway-database-postgresql` | PostgreSQL 모듈 별도 필요. `out-of-order: true`(번호 대역) |
| API 문서 | `org.springdoc:springdoc-openapi-starter-webmvc-ui` | 3.1.1 (Boot 4 동작 확인) |
| 메일(로컬) | `spring-boot-starter-mail` | SMTP → Mailpit(1025) |
| AWS | AWS SDK for Java v2: `ses`(또는 `sesv2`), `s3` | BOM으로 버전 통일 |
| 엑셀 | `org.apache.poi:poi-ooxml` | xlsx 업로드·양식 다운로드 |
| CSV | `org.apache.commons:commons-csv` | csv 업로드 |
| HTTP 클라이언트 | Spring `RestClient` (내장) | Gemini REST 호출, 별도 SDK 없이 |
| 속도 제한 | 직접 구현한 토큰 버킷 (단일 인스턴스) | 외부 라이브러리 없이 `ses.max-send-rate` 적용 |
| 보일러플레이트 | Lombok | 사용 (6장 결정). `@Getter`, `@RequiredArgsConstructor`, `@Builder`만 — `lombok.config`로 강제 |
| 테스트 | `spring-boot-starter-*-test`(JUnit 5, AssertJ, Mockito, MockMvc) | MyBatis 쿼리는 **로컬 Docker PostgreSQL**로 테스트(`@Transactional` 롤백). Testcontainers는 쓰지 않음 |

**사용하지 않는 것**: JPA/Hibernate, QueryDSL, Spring Batch, ShedLock, Redis, 메시지 브로커(Kafka·RabbitMQ·SQS). 발송 큐는 `send_log` 테이블 + `FOR UPDATE SKIP LOCKED`로 충분하다.

### 2.3 설정 파일 구조

```
src/main/resources/
├─ application.yml             공통
├─ application-local.yml       로컬 (docker compose, Mailpit, 로컬 디스크, SMS Mock)
├─ application-prod.yml        운영 (RDS, SES, S3) — 비밀값은 환경변수 (W5 작성)
├─ mapper/{domain}/*.xml
└─ db/migration/
   ├─ V1__init.sql
   └─ local/R__seed_local.sql   (local 프로필에서만 locations에 포함, 반복 실행 마이그레이션)
```

아래는 요약이다. **실제 기준은 `withus_backend/src/main/resources/application.yml`** 이다.

```yaml
# application.yml (핵심만)
spring:
  jackson:
    time-zone: Asia/Seoul
  task:
    scheduling:
      pool:
        size: 5
  servlet:
    multipart:
      max-file-size: 10MB
mybatis:
  mapper-locations: classpath:mapper/**/*.xml
  configuration:
    map-underscore-to-camel-case: true
    default-statement-timeout: 30

withus:
  sender:
    name: 위드어스
    phone: 02-000-0000
    unsubscribe-phone: 080-000-0000
    from-address: hello@${WITHUS_MAIL_DOMAIN:withus.local}
  tracking:
    base-url: ${WITHUS_API_BASE_URL:http://localhost:8080}
    bot-click-seconds: 10
    bot-user-agent-keywords: bot,crawler,spider,scanner,preview
  send-window:
    start: "08:00"
    end: "20:50"
  jwt:
    secret: ${JWT_SECRET}
    access-ttl: 30m
    refresh-ttl: 7d
  cookie:
    secure: true         # local 에서만 false
  owner:
    email: ${OWNER_EMAIL:}
    password: ${OWNER_PASSWORD:}
ses:
  max-send-rate: 1
```

```yaml
# application-local.yml
spring:
  config:
    # DB 접속 정보는 infra/.env 에서 읽는다 (6장 결정: 로컬도 비밀번호를 파일에 쓰지 않음)
    import: optional:file:../infra/.env[.properties]
  mail:
    host: localhost
    port: 1025
  flyway:
    locations: classpath:db/migration,classpath:db/migration/local
withus:
  storage:
    type: local
    local-path: ./uploads
  sms:
    type: mock
  cookie:
    secure: false        # 로컬 http
```

**운영 환경변수(커밋 금지)**: `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, `HMAC_SECRET`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`(가능하면 EC2 IAM 역할로 대체), `S3_BUCKET`, `SES_SNS_TOPIC_ARN`, `GEMINI_API_KEY`, `WITHUS_API_BASE_URL`, `WITHUS_MAIL_DOMAIN`, `OWNER_EMAIL`, `OWNER_PASSWORD`.

## 3. 프론트엔드

### 3.1 기반

| 항목 | 선택 | 비고 |
|---|---|---|
| 런타임 | Node.js 22 이상 (권장 24 LTS) | `.nvmrc`로 고정 |
| 프레임워크 | Next.js 15 (App Router) | `create-next-app` TypeScript·ESLint·Tailwind 선택 |
| UI 라이브러리 | React 19 | |
| 언어 | TypeScript 5.x, `strict: true` | |
| 패키지 매니저 | npm | `package-lock.json` 커밋 |

### 3.2 의존성

| 목적 | 패키지 | 비고 |
|---|---|---|
| 스타일 | `tailwindcss` 4 | |
| 컴포넌트 | shadcn/ui (CLI로 필요한 것만 추가) | 소스가 저장소에 복사되는 방식 |
| 아이콘 | `lucide-react` | |
| 알림 | `sonner` | |
| 날짜 | `date-fns` (+ `date-fns-tz` 필요 시) | KST 표시 |
| 애니메이션 | `motion` | 과하게 쓰지 않음 |
| 차트 | shadcn Chart (`recharts`) | |
| 서버 상태 | `@tanstack/react-query` v5 | 쿼리 키는 `lib/query-keys.ts` |
| 메일 에디터 | `@tinymce/tinymce-react` + `tinymce` (자체 설치) | **도입 전 라이선스 조건 확인** |
| 워크플로우 캔버스 | `@xyflow/react` (React Flow) | 선택 기능 |
| 폼 | `react-hook-form` + `zod` + `@hookform/resolvers` | 사용 (6장 결정) |

### 3.3 폴더 구조

```
withus_frontend/
├─ app/
│  ├─ (auth)/login/page.tsx
│  ├─ (admin)/layout.tsx          사이드바 GNB
│  ├─ (admin)/dashboard/page.tsx
│  ├─ (admin)/customers/...
│  ├─ (admin)/segments/...
│  ├─ (admin)/campaigns/...
│  ├─ (admin)/templates/...
│  ├─ (admin)/coupons/...
│  ├─ (admin)/analytics/...
│  ├─ (admin)/settings/users/page.tsx
│  ├─ c/[token]/page.tsx          고객 쿠폰 페이지 (공개, 모바일)
│  └─ unsubscribe/[token]/page.tsx 수신거부 페이지 (공개, 모바일)
├─ components/ui/                 shadcn/ui
├─ components/{domain}/
├─ lib/api-client.ts              fetch 래퍼 (credentials, X-XSRF-TOKEN, 401 재시도)
├─ lib/query-keys.ts
└─ next.config.ts                 rewrites: /api/:path* → ${BACKEND_URL}/api/:path*
```

**환경변수**: `BACKEND_URL`(서버 전용, 로컬 `http://localhost:8080`). 브라우저 코드에서는 백엔드 주소를 쓰지 않으므로 `NEXT_PUBLIC_` 변수가 필요 없다.

## 4. 인프라·도구

| 항목 | 선택 | 비고 |
|---|---|---|
| 로컬 DB | Docker `postgres:17` | 5432, DB/계정 `withus` |
| 로컬 메일 | Docker `axllent/mailpit` | SMTP 1025, 웹 UI 8025 |
| 운영 백엔드 | EC2 1대 (Amazon Linux 또는 Ubuntu), Java 21, systemd 서비스 | |
| 리버스 프록시·HTTPS | Nginx + Let's Encrypt(certbot 자동 갱신) | |
| 운영 DB | RDS PostgreSQL 17, 자동 백업 7일 | EC2 보안 그룹에서만 접근 |
| 파일 | S3 (이미지 경로만 공개 읽기) | |
| 메일 | SES (도메인 인증 DKIM·SPF, 프로덕션 액세스) + SNS 토픽 | |
| 프론트 호스팅 | AWS Amplify (Next.js SSR), 사용자 지정 도메인 `app.<도메인>` | |
| 형상 관리 | GitHub, 저장소 3개 (메인·프론트·백엔드) | |
| 코드 스타일 | 백엔드: IntelliJ 기본, 프론트: ESLint + Prettier(`npm run format`) | 6장 결정: 자동 포맷터는 프론트 Prettier만 |

```yaml
# infra/docker-compose.yml
services:
  postgres:
    image: postgres:17
    environment:          # 값은 infra/.env (커밋 금지, .env.example 참고)
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      TZ: Asia/Seoul
    ports: ["${DB_PORT:-5432}:5432"]
    volumes: ["pgdata:/var/lib/postgresql/data"]
  mailpit:
    image: axllent/mailpit
    ports: ["1025:1025", "8025:8025"]
volumes:
  pgdata:
```

## 5. 버전 고정표

W1 첫날 저장소를 만들 때 실제 설치된 버전을 기록한다. 이후 변경은 PL 리뷰를 거친다.

| 구성 요소 | 원칙 | 확정 버전 |
|---|---|---|
| JDK | 21 LTS | 21.0.12 (Zulu) |
| Spring Boot | 4.x 최신 안정판 | 4.0.8 (MyBatis 스타터가 4.1 미지원) |
| MyBatis Spring Boot Starter | Spring Boot 4 호환 최신 | 4.0.1 |
| Flyway | Spring Boot BOM 관리 버전 | 11.14.1 |
| springdoc-openapi | Spring Boot 4 호환 최신 | 3.1.1 |
| jjwt | 0.12.x 이상 | 0.13.0 |
| AWS SDK v2 BOM | 최신 안정판 | |
| Apache POI | 5.x | |
| PostgreSQL (로컬·RDS) | 17 | 17 (docker `postgres:17`) |
| Node.js | 22+ (권장 24 LTS) | 24 (`.nvmrc`) |
| Next.js | 15.x | 15.5.26 |
| React | 19.x | 19.1.0 |
| Tailwind CSS | 4.x | 4.3.3 |
| TanStack Query | 5.x | 5.104.0 |
| TinyMCE | 최신 (자체 설치, GPLv2+) | 설치 시 기록 (팀원2), `license_key: 'gpl'` |
| Lombok | Spring Boot BOM 관리 버전 | BOM 관리 (허용 어노테이션은 `lombok.config`로 강제) |
| react-hook-form / zod / @hookform/resolvers | 최신 안정판 | 7.89.0 / 4.6.5 / 5.9.1 |
| Prettier | 최신 안정판 | 3.9.9 (`.prettierrc`: printWidth 100, `*.md` 제외) |
| shadcn/ui 기반 | CLI 기본값 | `@base-ui/react`(프리미티브), `cn`(shadcn 공식 클래스 병합 유틸) |

## 6. 결정 사항

| 항목 | 결정 | 근거·적용 |
|---|---|---|
| MyBatis·springdoc의 Spring Boot 4 호환 | Spring Boot **4.0.8** 사용 | MyBatis 4.0.1이 Boot 4.0.x까지 지원. 기동·Flyway V1·Swagger 확인 완료. 4.1 지원 MyBatis 출시 시 상향 |
| Lombok | **사용**, `@Getter`·`@RequiredArgsConstructor`·`@Builder`만 | `pom.xml` 추가. `lombok.config`로 그 외(`@Data`·`@Setter`·`@AllArgsConstructor` 등)는 컴파일 오류 처리. 기존 코드를 Lombok으로 바꿀 필요는 없음 |
| 폼 라이브러리 | **react-hook-form + zod** (+ `@hookform/resolvers`) | 고객·쿠폰·캠페인 등 폼이 많음. `package.json` 추가 완료 |
| TinyMCE 라이선스 | **TinyMCE 자체 설치, GPLv2+** (`license_key: 'gpl'`) | 저장소가 공개(GitHub public)라 GPL 소스 공개 의무 충족. Tiptap 대체 불필요 |
| SES API | **`sesv2`** | List-Unsubscribe 헤더를 포함한 원시 메시지 전송 (W2, 팀원2) |
| SNS 서명 검증 | **AWS SDK 제공 기능 우선**, 없으면 직접 구현 | W3, 팀원1 |
| Gemini 모델 | **무료 등급의 가장 가벼운 텍스트 모델** | 정확한 모델명·한도는 팀원3이 W1에 확인해 5장에 기록 |
| 자동 포맷터 | **프론트 Prettier만** | `.prettierrc`(printWidth 100), `npm run format` / `format:check`, ESLint와 충돌 방지(`eslint-config-prettier`). 백엔드는 IntelliJ 기본 |
| 로컬 DB 비밀번호 | **`infra/.env`에서 읽음** (파일에 직접 쓰지 않음) | CLAUDE.md 7장 "비밀값은 환경변수로만"과 일치. `.env.example` 복사 후 사용 |

## 7. 선택하지 않은 대안과 이유

| 대안 | 선택하지 않은 이유 |
|---|---|
| JPA/Hibernate, QueryDSL | 세그먼트 조건을 동적 SQL로 직접 조립하는 비중이 크고, 팀이 SQL을 명확히 통제하기 위해 MyBatis로 통일 |
| Oracle | 비용과 로컬 개발 편의(docker) 때문에 PostgreSQL 17로 변경 (v2.1) |
| Spring Batch, ShedLock | 단일 인스턴스 + DB 폴링 + `FOR UPDATE SKIP LOCKED`로 충분 |
| Redis, Kafka, SQS | 5주 일정과 10만 건 규모에서는 DB 테이블 큐로 충분, 운영 구성 단순화 |
| JWT를 localStorage에 저장 | XSS에 취약. httpOnly 쿠키 + CSRF로 결정 |
| CORS로 프론트·백엔드 직접 통신 | 쿠키·CORS 설정이 복잡해져 Next.js rewrites 프록시로 결정 |
| OpenAI·Claude API | 비용 때문에 Gemini 무료 등급 선택. 개인정보는 보내지 않음 |
| ALB + ACM | 월 고정 비용. EC2 Nginx + Let's Encrypt로 결정 |
