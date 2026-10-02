# 위드어스 (Withus) PRD v2.3

> 최종 수정: 2026-09-30

## 1. 프로젝트 개요

위드어스는 고객/팬 데이터를 세그먼트로 묶고, 트리거 → 대기 → 조건 분기 → 발송(메일/SMS) 워크플로우를 자동 실행하며, 오픈·클릭을 추적해 성과를 보여주는 CRM 마케팅 자동화(MA) 솔루션이다. 개발 기간은 5주(W1~W5, W5는 운영 배포), 인원은 4명(PL 1명 + 팀원 3명)이다.

| 항목 | 내용 |
|---|---|
| 제품명 | 위드어스 (Withus) |
| 슬로건 | "항상 함께(With Us)" — 팬덤/고객과의 결속 |
| 제품 정의 | 세그먼트 단위 마케팅 자동화 및 워크플로우 실행 엔진 |
| 발송 채널 | 이메일(로컬 Mailpit / 운영 AWS SES), SMS(Mock 기본, 실제 연동은 선택) |
| 기준 시간대 | 모든 일시는 KST(Asia/Seoul) 기준 |

### 1.1 범위 (In Scope)

- 고객 DB 등록/업로드, 수신동의 관리, 수신거부 처리
- 조건 기반 동적 세그먼트 생성
- 메일/SMS 템플릿 작성(치환자, 이미지 업로드)
- 일회성 예약 발송 캠페인
- 워크플로우 캠페인(분기 최대 2단계)
- 오픈/클릭 추적 및 성과 대시보드
- 쿠폰 발급·사용, 구매 등록 및 전환 추적 (정액·정률, 쿠폰별 고정 기간)
- 휴면 고객 판정 배치 (최근 180일 클릭·구매 없음), 수신동의 2년 주기 확인 안내 배치
- 고객용 공개 페이지 `/c/[token]`, `/unsubscribe/[token]`
- AI 기능 3종(문구 생성, 발송 시간 추천, 성과 요약)

### 1.2 범위 제외 (Out of Scope)

- 요금제/결제 관리 (v1 PRD의 최고관리자 요금제 관리 항목 삭제)
- 외부 쇼핑몰 실시간 연동(가입/구매 웹훅)
- 다중 테넌트(회사별 데이터 분리) — 단일 조직 사용 전제
- 카카오 알림톡, 푸시 알림
- 실제 SMS 발송(선택 기능으로만 유지)

### 1.3 v1 대비 주요 변경점

- 기술 스택 이중 선택지를 하나로 확정
- 워크플로우 진행 상태 테이블(`workflow_instance`), 링크 추적 테이블(`track_link`) 등 추가
- 캠페인 유형을 일회성(ONE_TIME)과 워크플로우(WORKFLOW)로 분리
- 캠페인 상태값을 초안/예약/활성/일시정지/완료로 변경
- 트리거 종류, 분기 규칙, 법규 준수 항목을 구체화
- (v2.1) DB를 Oracle에서 PostgreSQL 17로, 프론트를 Next.js로, LLM을 Gemini로 변경
- (v2.1) 폴리레포 3개 구조, 로컬 우선 개발 후 W5 AWS 배포로 전환
- (v2.1) 역할명을 OWNER·MANAGER·STAFF로 변경, 팀을 PL + 3명(고객→발송→전환 구간별 풀스택)으로 재편
- (v2.1) 쿠폰 도메인, 휴면 판정 배치 추가. (v2.2) 전체 검토 반영: 발송 중복 방지·추적 토큰·공통 발송 큐·A/B 야간 검사·수신거부 목록·SES 웹훅 검증·SMS 광고 표기·R&R 재조정. 이후 로그인 쿠키 방식, F-12 수신동의 안내, 구매 등록, SEND 노드별 쿠폰, 발송 직전 재확인, 발송 우선순위, 명칭 통일(소문자 테이블명, MessageSender). (v2.3) 최종 검토 반영: 스케줄러 스레드 분리·멈춤 복구, 발송 SENDING 상태·재시도, 렌더링·쿠폰 발급 시점, 추적 제외 링크, 테스트 발송 규칙, 수신거부 해제 절차, rewrites 기준 도메인 정리, AI 범위 명확화, 입력값 정규화(이메일·휴대폰·지역·날짜), 만 나이 기준, 업로드 시 누적구매액 보호, 로그인 잠금, 도메인 구매 일정

## 2. 시스템 구성 및 기술 스택

저장소는 독립 Git 저장소 3개(폴리레포)이며, W1~W4는 로컬(docker compose)에서 개발하고 W5에 Spring 프로필만 바꿔 AWS로 배포한다. 아래 스택 외의 라이브러리는 팀 합의 없이 추가하지 않는다.

### 2.1 저장소 구조

메인 저장소는 문서·로컬 인프라·배포 설정을 담고, 하위 두 폴더는 메인의 `.gitignore`에 넣어 중복 추적을 막는다.

```
withus/                         ← 메인 저장소 (문서·인프라)
├─ docs/                          기획·ERD·API 계약·회의록
├─ infra/
│  ├─ docker-compose.yml          PostgreSQL 17, Mailpit(로컬 메일 수신함)
│  └─ aws/                        배포 스크립트·설정
├─ .gitignore                     withus_frontend/, withus_backend/ 제외
├─ withus_frontend/               ← 독립 저장소 (Next.js)
└─ withus_backend/                ← 독립 저장소 (Spring Boot)
```

### 2.2 기술 스택

| 영역 | 기술 | 비고 |
|---|---|---|
| 백엔드 | Spring Boot 4.x, JDK 21, Maven(mvnw) | 패키지는 도메인별: customer, segment, campaign, workflow, coupon, tracking, ai, auth, common |
| 인증 | Spring Security + JWT(jjwt) | Access/Refresh 토큰, 역할 OWNER·MANAGER·STAFF. Access·Refresh 토큰 모두 httpOnly·Secure 쿠키로 발급(프론트 JS에서 접근 불가, CSRF 대책 포함, 9장) |
| DB 접근 | MyBatis + Flyway, PostgreSQL 17 | 세그먼트 조건은 MyBatis 동적 SQL(`<where>`, `<foreach>`)로 조립, JPA 미사용 |
| API 문서 | SpringDoc OpenAPI (Swagger UI) | 프론트와의 API 계약 기준 |
| 스케줄러 | `@Scheduled` + DB 폴링 | 예약 발송, 발송 큐 소비, 워크플로우 대기 노드, A/B 승자 발송, 휴면 판정·수신동의 안내 배치. 스케줄러 스레드 풀은 작업 수 이상(spring.task.scheduling.pool.size=5)으로 두고 모든 작업을 fixedDelay로 실행해, 한 작업이 길어져도 다른 작업(특히 발송 큐 소비)이 멈추거나 같은 작업이 겹치지 않게 한다 |
| 발송 | `MessageSender` 인터페이스 | 로컬: SMTP→Mailpit, SMS Mock / 운영: AWS SES, SMS API |
| 파일 | `FileStorage` 인터페이스 | 로컬 디스크 / 운영 S3 (템플릿 이미지, CSV 원본) |
| 프론트 | Next.js 15(App Router), React 19, TypeScript 5.x, Node 22+ (권장 24 LTS) | 관리자 화면 + 고객용 공개 페이지(`/c/[token]`, `/unsubscribe/[token]`) |
| UI | Tailwind CSS 4, shadcn/ui, lucide-react, sonner, date-fns, Motion | 대시보드 차트는 shadcn Chart(Recharts) |
| 서버 상태 | TanStack Query v5 | 쿼리 키는 도메인 단위로 공통 관리 |
| 메일 에디터 | TinyMCE (자체 설치, 도입 전 라이선스 조건 확인) | HTML 출력 가능해야 함 |
| 워크플로우 캔버스 | React Flow | 선택 기능, 1차는 폼 기반 UI |
| AI | Google Gemini API (무료 등급) | 백엔드에서만 호출, 키는 환경변수. 무료 등급은 호출 한도가 있고 입력이 Google 모델 개선에 쓰일 수 있어 실제 고객 개인정보는 보내지 않음 |

### 2.3 배포 경로

| 구분 | W1~W4 (local) | W5 (prod) |
|---|---|---|
| 실행 | `docker compose up` + 로컬 실행 | EC2(백엔드) + AWS Amplify(프론트, Next.js SSR) |
| DB | PostgreSQL 17 (컨테이너) | RDS PostgreSQL |
| 메일 | SMTP → Mailpit | AWS SES |
| SMS | Mock | Mock 또는 SMS API |
| 파일 | 로컬 디스크 | S3 |

- 발송·파일을 인터페이스로 분리해 두는 것이 이 전환을 코드 수정 없이 하기 위한 핵심이다.
- 관리자·고객 페이지의 모든 API 호출은 Next.js rewrites(/api/* → 백엔드)로 프록시한다. 브라우저는 프론트 주소(Amplify 기본 주소, 예: main.xxxx.amplifyapp.com)만 호출하므로 CORS를 열 필요가 없고, 인증·CSRF 쿠키도 프론트 도메인의 퍼스트파티 쿠키로 동작한다(로컬 localhost:3000 → localhost:8080도 같은 방식). Next.js 서버 컴포넌트가 백엔드를 직접 호출할 때는 요청의 쿠키를 전달한다. 도메인은 구매하지 않는다(10.4). 메일에 들어가는 추적(`/t/*`)·수신거부·원클릭 수신거부 링크와 SES 웹훅도 모두 Amplify 주소(HTTPS)로 받아 Next.js rewrites로 백엔드에 넘긴다. 백엔드(EC2)에는 별도 도메인·인증서를 두지 않는다. 로컬(http)에서는 쿠키의 Secure 플래그를 프로필 설정으로 끈다.

- [ ] SES는 도메인 없이 이메일 주소 인증 + 샌드박스로 운영한다(8.2). 발신 주소와 시연 수신 주소를 W3에 미리 인증 (PL)

### 2.4 기술 공통 규칙

- JSON 컬럼(세그먼트 규칙, 워크플로우 노드 설정)은 PostgreSQL `JSONB`로 저장하고, 해석은 Java(Jackson)에서 한다.
- 스키마 변경은 Flyway 마이그레이션 파일로만 한다. 운영 DB를 직접 수정하지 않는다.
- 서버 JVM 타임존과 DB 세션 타임존을 모두 `Asia/Seoul`로 고정한다.
- 외부 연동(메일, SMS, 파일, LLM)은 모두 인터페이스 뒤에 두고 로컬용 구현을 제공한다.
- API 응답은 공통 포맷 `{ success, data, error: { code, message } }`을 사용한다.

## 3. 사용자 역할 및 권한

시스템 사용자 역할은 3개(`OWNER`, `MANAGER`, `STAFF`)이며, 수신 고객은 로그인하지 않는 외부 사용자다. 권한은 API 단에서 `@PreAuthorize`로 강제하고, 프론트는 메뉴 노출만 제어한다. 역할 대응: OWNER = 최고관리자, MANAGER = 마케팅 매니저, STAFF = 콘텐츠 담당자.

| 기능 | OWNER | MANAGER | STAFF |
|---|---|---|---|
| 대시보드 조회 | O | O | O |
| 고객 조회 | O | O | X |
| 고객 등록/수정/업로드 | O | O | X |
| 세그먼트 조회 | O | O | 조회만 |
| 세그먼트 생성/수정/삭제 | O | O | X |
| 템플릿 조회 | O | O | O |
| 템플릿 생성/수정/삭제 | O | O | O |
| AI 문구 생성 | O | O | O |
| 캠페인 조회 | O | O | 조회만 |
| 캠페인 생성/수정/실행/중지 | O | O | X |
| 쿠폰 조회 | O | O | 조회만 |
| 쿠폰 생성/수정 | O | O | X |
| 구매 등록·쿠폰 사용 처리 | O | O | X |
| 성과 리포트 조회 | O | O | O |
| 사용자 계정/권한 관리 | O | X | X |

- 수신 고객(Customer/Fan): 메일/SMS 수신, 링크 클릭, 수신거부 페이지 이용. 인증 없이 추측할 수 없는 토큰(수신거부는 HMAC 서명, 쿠폰 페이지는 UUID)으로만 접근한다.
- 최초 OWNER 계정은 애플리케이션 시작 시 환경변수 기반으로 1개 생성한다.

## 4. 화면 목록 (GNB)

좌측 사이드바 GNB 7개 메뉴와 고객용 공개 페이지 2개, 추적 API 2개로 구성한다. 프론트 경로는 Next.js App Router 기준이며, 담당은 10.1의 구간별 배정을 따른다.

| GNB | 화면 | 경로 | 주요 내용 | 담당 |
|---|---|---|---|---|
| - | 로그인 | `/login` | 이메일/비밀번호 로그인 | PL |
| 대시보드 | 메인 대시보드 | `/dashboard` | 총 발송/평균 오픈율/평균 클릭률 카드, 활성 캠페인 현황, 최근 이벤트 로그(10초 폴링) | 팀원3 |
| 고객·세그먼트 | 고객 목록 | `/customers` | 검색/필터/페이징, 개별 등록·수정, 수신동의 변경, 업로드 모달 | 팀원1 |
| 고객·세그먼트 | 고객 상세 | `/customers/[id]` | 인적사항, 동의 이력, 발송·이벤트·쿠폰 이력, 구매 등록·쿠폰 사용 처리 | 팀원1 |
| 고객·세그먼트 | 세그먼트 목록 | `/segments` | 조건 요약, 현재 대상 고객 수 | 팀원1 |
| 고객·세그먼트 | 세그먼트 생성/수정 | `/segments/new`, `/segments/[id]` | AND/OR 조건 빌더, 대상 수 미리보기 | 팀원1 |
| 캠페인 | 캠페인 목록 | `/campaigns` | 유형·상태 필터, 시작/일시정지/종료 | 팀원2 |
| 캠페인 | 캠페인 생성/수정 | `/campaigns/new`, `/campaigns/[id]/edit` | 유형 선택 → 일회성 예약 설정 또는 워크플로우 빌더, AI 발송 시간 추천 | 팀원2 |
| 템플릿 | 템플릿 목록 | `/templates` | 채널(메일/SMS) 필터 | 팀원2 |
| 템플릿 | 템플릿 에디터 | `/templates/new`, `/templates/[id]` | HTML 에디터/SMS 본문, 치환자 삽입, 이미지 업로드, 미리보기, AI 초안 3안 | 팀원2 |
| 쿠폰 | 쿠폰 목록/생성 | `/coupons`, `/coupons/new` | 쿠폰 정의, 발급·사용 현황 (정액·정률, 쿠폰별 고정 기간) | 팀원3 |
| 성과 리포트 | 캠페인 성과 | `/analytics`, `/analytics/[campaignId]` | 단계별 발송/성공/오픈/클릭/전환 차트, A/B 비교, AI 성과 요약 | 팀원3 |
| 시스템 설정 | 사용자 관리 | `/settings/users` | 계정 생성, 역할 부여, 비활성화 | PL |
| 공개 | 고객 페이지 | `/c/[token]` | 쿠폰 확인, '사용하기' 버튼(POST, 발급 1건당 1회, 유효기간 내) | 팀원3 |
| 공개 | 수신거부 | `/unsubscribe/[token]` | 채널별 수신거부 처리, 완료 안내 | 팀원1 |
| 백엔드 API | 오픈 추적 | `GET /t/o/{``trackingToken``}.gif` | 1x1 투명 GIF 반환 | 팀원3 |
| 백엔드 API | 클릭 추적 | `GET /t/c/{``trackingToken``}/{linkId}` | 이벤트 저장 후 302 리다이렉트 | 팀원3 |

## 5. 기능 요구사항

필수(F) 기능 12개와 AI 기능 3종(5.3)이 W4 완료 기준이며 시연 범위에 포함된다. 선택(O) 기능은 필수·AI 완료 후 여유가 있을 때만 진행한다.

### 5.1 필수 기능

**F-01 고객 DB 업로드**

- xlsx, csv 파일 업로드(최대 10MB, 최대 10,000행).
- 1행은 헤더이며 컬럼은 고정 양식을 따른다: 이름, 이메일, 휴대폰, 지역, 생년월일, 가입일, 누적구매액, 이메일수신동의(Y/N), SMS수신동의(Y/N). 양식 파일 다운로드를 제공한다. 날짜는 YYYY-MM-DD, 지역은 시/도명(예: 서울, 경기)을 받아 코드(SEOUL, GYEONGGI 등)로 변환한다. 이메일은 소문자로 바꾸고 앞뒤 공백을 지우며, 휴대폰은 숫자만 남겨 저장한다. 같은 정규화를 개별 등록과 수신거부 목록 비교에도 똑같이 적용한다.
- 삭제되지 않은 고객 중 이메일이 같으면 업데이트, 없으면 신규 등록한다. 기존 고객을 업데이트할 때 누적구매액은 바꾸지 않는다(구매 등록으로만 증가하며, 파일 값은 신규 등록 때만 사용). 수신거부 목록(suppression, 7장)에 있는 이메일·휴대폰은 파일 값과 관계없이 해당 채널 수신동의를 N으로 등록하고, 결과에 "과거 수신거부 이력"으로 표시한다.
- 행 단위 검증 후 결과를 성공 n건 / 실패 n건 / 실패 사유(행 번호 포함)로 반환한다. 실패 행이 있어도 성공 행은 저장한다.
- 업로드로 등록된 고객은 워크플로우 "신규 고객 등록" 트리거를 발생시키지 않는다(대량 발송 사고 방지). 개별 등록만 트리거한다.

**F-02 고객 개별 관리 및 수신동의**

- 고객 등록/수정/삭제(논리 삭제), 이메일·SMS 수신동의를 채널별로 관리한다. 삭제된 고객과 같은 이메일로 다시 등록하면 새 고객으로 만들고 이전 동의 상태는 이어받지 않는다. 과거 수신거부 이력 규칙(F-01)은 개별 등록에도 똑같이 적용한다.
- 동의 상태가 바뀔 때마다 `consent_history`에 변경 일시·경로(관리자/업로드/수신거부 페이지/SES 반송·스팸신고)를 기록한다.

**F-03 조건 기반 세그먼트**

- 조건 필드: 지역(시/도, IN), 연령(생년월일로 계산한 만 나이, 범위), 가입일(범위 또는 최근 N일), 누적구매액(비교 연산), 이메일/SMS 수신동의 여부, 휴면 여부(F-11).
- 연산자: `EQ`, `NE`, `GT`, `GTE`, `LT`, `LTE`, `BETWEEN`, `IN`, `IN_LAST_DAYS`.
- 조합: 그룹 1단계까지 허용(그룹 내 AND/OR, 그룹 간 AND/OR). 조건 최대 10개.
- 세그먼트는 동적(Dynamic)이다. 대상 고객은 발송 시점에 조건으로 다시 계산한다.
- 조건 편집 시 대상 고객 수를 미리보기(디바운스 500ms)로 보여준다.
- 조건 필드와 연산자는 화이트리스트로만 SQL에 매핑한다. 사용자 입력을 컬럼명으로 직접 쓰지 않는다.

**F-04 템플릿 편집기**

- 채널: 메일(제목 + HTML 본문), SMS(본문, 90바이트 초과 시 LMS 표시).
- 치환자: `{{name}}`, `{{email}}`, `{{region}}`, `{{totalPurchase}}`, {{couponUrl}}(발송에 쿠폰이 연결된 경우 고객별 /c/[token] 주소. 쿠폰 연결 여부는 템플릿 저장이 아니라 일회성 캠페인 또는 워크플로우 SEND 노드를 저장할 때 검사하며, {{couponUrl}}을 쓰는 템플릿에 쿠폰이 연결되지 않으면 저장 오류). 발송 시 고객 값으로 치환한다. 값이 없으면 템플릿에 지정한 기본값({{name|고객}} 형식)을 쓰고, 지정이 없으면 치환자별 시스템 기본값(이름 → "고객", 지역 → 빈 값, 누적구매액 → 0)을 쓴다. 빈 문자열이 그대로 나가지 않게 한다. 발송 전 미리보기에 "대상 n명 중 m명은 기본값으로 발송"을 표시한다. SMS 바이트 수(90바이트 초과 시 LMS)는 치환 후 기준으로 계산한다.
- 이미지는 FileStorage(로컬 디스크 / 운영 S3)에 업로드(최대 5MB, jpg/png/gif)하고 공개 URL을 본문에 삽입한다.
- 테스트 발송: 입력한 이메일 1개로 샘플 발송한다(send_log kind = TEST, customer_id 없음). 치환자는 샘플 값, 쿠폰 링크는 발급 없이 예시 주소를 쓰고, 추적·수신거부 링크는 동작하지 않는 예시로 넣는다. 광고성 시간 제한은 적용하지 않으며 통계에서 제외한다. 예약·활성·일시정지 상태 캠페인이 쓰는 템플릿은 수정할 수 없고, 복제해서 고친다. track_link 행은 삭제하지 않는다(이미 보낸 메일의 링크 보존). 캠페인이나 SEND 노드가 참조 중인 템플릿은 삭제할 수 없다.

**F-05 일회성 예약 발송 캠페인**

- 세그먼트 + 템플릿 + 발송 일시(또는 즉시)를 지정한다.
- 발송 시점에 수신동의 = Y인 고객만 대상으로 한다. 광고성 캠페인은 예약 발송과 즉시 발송 모두 예상 소요 시간((현재 대기 중인 PENDING 건수 + 대상 수) ÷ 초당 발송 한도)을 계산해, 20:50을 넘겨 끝날 것으로 예상되면 발송을 막고 가능한 시각을 안내한다(8.4).

**F-06 워크플로우 캠페인**

- 상세 규칙은 6장 워크플로우 엔진 명세를 따른다.

**F-07 오픈·클릭 추적**

- 상세 규칙은 8.1을 따른다.

**F-08 수신거부**

- 모든 광고성 메일 하단에 수신거부 링크를 자동 삽입한다. 템플릿에서 삭제할 수 없다.
- 수신거부 링크의 GET 요청은 확인 화면만 보여준다. 사용자가 채널(이메일/SMS/전체)을 고르고 버튼을 눌러 보낸 POST 요청으로만 처리한다(보안 솔루션·백신의 링크 자동 열람으로 수신거부되는 것을 방지). 처리 즉시 수신거부 목록(suppression)에 추가하고 이후 모든 캠페인 발송 대상에서 제외한다. 완료 화면에 처리한 채널과 처리 일시를 표시해 처리 결과를 바로 알린다. 메일 헤더 원클릭 수신거부는 8.3을 따른다.

**F-09 성과 대시보드**

- 지표 정의: 발송 성공률 = 성공 / 발송 시도, 오픈율 = 고유 오픈 고객 / 발송 성공, 클릭률 = 고유 클릭 고객 / 발송 성공. 모든 지표에서 봇 이벤트(bot_yn = Y)와 TEST·NOTICE 발송은 제외한다.
- 캠페인별, 워크플로우 단계별로 집계한다. 기간 필터(최근 7/30일, 직접 지정)를 제공한다.

**F-10 쿠폰 및 전환**

- 쿠폰을 정의하고 발송에 연결해 고객별로 발급한다. 일회성 캠페인은 campaign.coupon_id로, 워크플로우는 SEND 노드별 config_json의 couponId로 연결한다. 따라서 한 워크플로우에서 경로마다 다른 쿠폰(예: 6.4의 VIP·일반 쿠폰)을 보낼 수 있다.
- 고객은 메일/SMS의 `/c/[token]` 링크로 쿠폰을 확인한다. 이 토큰은 coupon_issue.token(추측할 수 없는 UUID)이며 발급 1건당 1개다. 템플릿에는 {{couponUrl}} 치환자(F-04)로 넣는다. 화면은 단순 쿠폰 카드형으로, 쿠폰명·할인 내용·유효기간·사용하기 버튼과 사용 완료/만료 상태만 보여준다.
- 쿠폰 사용을 전환으로 집계해 성과 리포트에 전환율(쿠폰 사용 고객 / 발송 성공)로 표시한다.
- 사용 처리는 두 경로를 모두 지원한다. ① 관리자 화면(고객 상세)에서 구매 등록(금액 입력, 쿠폰 선택 가능) → purchase 저장, total_purchase 가산, 쿠폰 선택 시 사용 처리(해당 고객에게 발급됐고, 미사용이며, 유효기간 안인 쿠폰만 선택 가능). ② 고객 페이지 /c/[token]의 '사용하기' 버튼 → POST 요청으로만 사용 처리(링크 스캐너 오작동 방지), 발급 1건당 1회, 유효기간 내에서만 가능. 이 경로는 금액이 없으므로 coupon_issue.used_at만 기록하고 purchase는 만들지 않는다. 할인 유형은 정액(원)과 정률(%)을 모두 지원하며, 정률은 최대 할인액 상한을 둔다. 유효기간은 쿠폰마다 고정 기간(valid_from~valid_to)으로 정하고, 발급 시점과 관계없이 모든 발급 건에 같은 기간을 적용한다.

**F-11 휴면 판정 배치**

- `@Scheduled` 일 1회(새벽) 배치로 휴면 조건에 맞는 고객을 휴면 상태로 표시하고, 조건에서 벗어난 고객은 휴면을 해제한다. 휴면 고객에게도 발송은 가능하며, 제외하려면 세그먼트 조건으로 뺀다.
- 휴면 여부는 세그먼트 조건 필드로 쓸 수 있게 한다.
- 휴면 기준: 최근 180일 동안 클릭(봇 제외)과 구매가 모두 없는 고객. 오픈은 Apple Mail 등으로 부정확해 판정에서 제외한다. 가입 후 180일이 지나지 않은 고객은 판정하지 않는다.

**F-12 수신동의 2년 주기 확인 안내**

- `@Scheduled` 일 1회 배치로, 이메일·SMS 수신동의 일시(또는 직전 안내 일시)로부터 2년이 된 동의 고객을 찾는다.
- 해당 고객에게 전송자 명칭, 수신동의 날짜와 동의 사실, 수신거부 방법(수신거부 링크)을 담은 안내를 보낸다. 안내는 광고가 아니므로 제목에 (광고)를 붙이지 않는다.
- 안내 발송은 8.2 공통 발송 큐와 08:00~20:50 시간 제한을 따르고, 발송 후 `customer.consent_notified_at`을 갱신한다.
- 고객이 아무 조치를 하지 않으면 동의는 유지된다. 안내 문구와 채널별 세부 요건은 KISA 안내서로 확인한다.

### 5.2 선택 기능

| ID | 기능 | 요구사항 |
|---|---|---|
| O-01 | A/B 테스트 | 일회성 캠페인 한정. 제목 2안, 대상의 20%를 A/B 각 10%로 발송 → 지정 시간(기본 4시간) 후 오픈율(봇 제외) 높은 안을 나머지 80%에 자동 발송. 발송 전 "테스트 발송 + 대기 + 나머지 발송"이 20:50 전에 끝나는지 검사하고, 넘으면 승자 발송은 다음 날 08:00에 한다. 나머지 80%는 승자 발송 시점에 세그먼트를 다시 계산해, 이미 받은 고객을 뺀 전원에게 보낸다 |
| O-02 | 시각적 워크플로우 빌더 | React Flow 캔버스. 폼 기반 빌더와 같은 `workflow_step` 구조를 저장 |
| O-03 | 실제 SMS 연동 | `Message``Sender`의 SMS 구현체만 추가. 공급사 확정 필요 |

### 5.3 AI 기능

| ID | 기능 | 입력 | 출력 | 예외 처리 |
|---|---|---|---|---|
| AI-01 | 메일 문구 초안 | 목적, 타깃, 톤, 핵심 메시지 | 제목+본문 3안(JSON) | 실패 시 오류 안내, 재시도 버튼 |
| AI-02 | 최적 발송 시간 추천 | 최근 90일 오픈/클릭 이벤트(봇 제외) | 08:00~20:00 안의 요일·시간대 상위 3개 + 근거 | 이벤트 100건 미만이면 기본값(평일 10시) 표시 및 "데이터 부족" 안내 |
| AI-03 | 성과 요약 리포트 | 캠페인 집계 지표(JSON) | 자연어 요약 5문장 이내 | `ai_report`에 저장, 재생성 버튼 제공 |

- AI-02의 시간대 집계는 SQL로 계산하고, LLM은 설명 문장 생성에만 쓴다. 추천 결과에는 법적 가드레일을 데이터와 관계없이 항상 적용한다: 시작 시각은 08:00~20:00만 허용하고, 시작 시각 + 예상 소요 시간((현재 대기 중인 PENDING 건수 + 대상 수) ÷ 초당 발송 한도)이 20:50을 넘는 후보는 제외한다. 가드레일은 LLM이 아니라 코드로 적용한다. 클릭 이벤트에 오픈보다 높은 가중치(클릭 2 : 오픈 1)를 준다.
- LLM(Gemini 무료 등급)에는 고객 개인정보(이름, 이메일, 휴대폰)를 전달하지 않는다. 무료 등급의 호출 한도를 넘으면 오류 안내 후 재시도하게 한다.

## 6. 워크플로우 엔진 명세

워크플로우는 설계도(`workflow_step`)와 고객별 진행 상태(`workflow_instance`)로 분리하고, 스케줄러가 1분마다 실행 시각이 된 인스턴스를 처리하는 폴링 방식으로 구현한다.

### 6.1 노드 종류

| 노드 | 설정값 | 동작 |
|---|---|---|
| TRIGGER | 트리거 유형 | 워크플로우 시작점. 워크플로우당 정확히 1개 |
| WAIT | 대기 시간(분/시간/일) | `next_run_at = now + 대기시간` 설정 후 다음 노드로 이동. 직전 노드가 SEND면 실제 발송 시각(sent_at) 기준(6.5) |
| CONDITION | 조건 1개 | 참이면 YES 경로, 거짓이면 NO 경로로 이동 |
| SEND_EMAIL | 메일 템플릿 ID, 쿠폰 ID(선택) | 메일을 발송 큐에 적재한 뒤 다음 노드로 이동 |
| SEND_SMS | SMS 템플릿 ID, 쿠폰 ID(선택) | SMS를 발송 큐에 적재한 뒤 다음 노드로 이동 |
| END | 없음 | 인스턴스 완료 처리 |

### 6.2 트리거 유형

| 유형 | 설명 |
|---|---|
| `SEGMENT_SCHEDULED` | 지정 일시에 세그먼트 대상 고객 전체로 인스턴스를 일괄 생성 |
| `CUSTOMER_REGISTERED` | 캠페인이 활성 상태일 때 개별 등록된 고객이 세그먼트 조건에 맞으면 인스턴스 생성 |

### 6.3 분기 조건

| 조건 | 판정 기준 |
|---|---|
| `EMAIL_OPENED` | 이 워크플로우의 직전 메일 발송 건에 OPEN 이벤트(봇 제외)가 있는가 |
| `EMAIL_CLICKED` | 이 워크플로우의 직전 메일 발송 건에 CLICK 이벤트(봇 제외)가 있는가 |
| `PURCHASE_GTE` | 판정 시점의 고객 누적구매액이 기준 금액 이상인가 |

`EMAIL_OPENED`는 Apple Mail 개인정보 보호 등으로 실제보다 "열었음"이 많이 나온다. 빌더에서 이 조건을 고르면 `EMAIL_CLICKED` 사용을 권장하는 안내를 띄운다.

### 6.4 구조 제약 (저장 시 검증)

- CONDITION 노드는 한 경로에서 최대 2번까지 중첩할 수 있다. 따라서 종료 경로는 최대 4개다.
- 전체 노드 수는 최대 15개다.
- `EMAIL_OPENED`, `EMAIL_CLICKED` 조건은 앞 경로에 SEND_EMAIL과 WAIT가 순서대로 있어야만 둘 수 있다.
- 모든 경로는 END로 끝나야 하며, 순환(loop)은 허용하지 않는다.
- 활성 상태 캠페인의 구조는 수정할 수 없다. 수정하려면 일시정지 후 복제하여 새 캠페인으로 만든다.

예시 구조:

```
TRIGGER(CUSTOMER_REGISTERED)
 └ SEND_EMAIL(환영 메일)
    └ WAIT(2일)
       └ CONDITION(EMAIL_CLICKED)
          ├ YES → CONDITION(PURCHASE_GTE 100000)
          │        ├ YES → SEND_EMAIL(VIP 쿠폰) → END
          │        └ NO  → SEND_EMAIL(일반 쿠폰) → END
          └ NO  → SEND_SMS(리마인드) → END
```

### 6.5 실행 흐름

1. `WorkflowScheduler`가 1분마다 `status = WAITING AND next_run_at <= now`인 인스턴스를 500건씩 조회해 처리하고, 처리할 건이 없을 때까지 반복한다. 10만 건이 한꺼번에 시작돼도 한 실행 주기 안에서 계속 소진된다.
2. 각 인스턴스를 `RUNNING`으로 바꾼 뒤(PostgreSQL FOR UPDATE SKIP LOCKED로 조회), 현재 노드를 실행한다.
3. SEND 노드는 직접 발송하지 않고 send_log에 PENDING으로 적재해 8.2의 공통 발송 큐와 속도 제한을 거친다. 적재 전 고객의 수신동의와 수신거부 목록을 다시 확인하고(발송 직전에도 8.2에서 한 번 더 확인), 거부 상태면 발송하지 않고 `send_log`에 `SKIPPED`로 기록한 뒤 다음 노드로 진행한다.
4. WAIT 노드를 만나면 `next_run_at`을 설정하고 `WAITING`으로 되돌린다. WAIT가 아닌 노드는 같은 실행 안에서 연속 처리한다. WAIT 바로 앞이 SEND 노드이면 그 메시지가 실제 발송(SENT)된 시각부터 대기 시간을 센다. 아직 PENDING이면 인스턴스는 next_run_at을 비운 WAITING 상태로 두고, 발송이 완료되면 next_run_at = sent_at + 대기 시간으로 설정한다. 발송이 SKIPPED·FAILED로 끝나면 대기 없이 다음 노드로 진행하고, 메일 이벤트 조건은 NO로 판정한다.
5. END에 도달하면 `COMPLETED`, 오류 발생 시 `retry_count`를 올리고 5분 뒤 재시도, 3회 실패하면 `FAILED`로 기록한다.

**멈춤 복구와 멱등성.**

- 서버가 처리 도중 멈춰 `RUNNING`으로 10분 넘게 남은 인스턴스는 스케줄러가 `WAITING`(next_run_at = now)으로 되돌려 다시 처리한다.
- SEND 노드를 다시 실행하다 `(instance_id, step_id)` 유니크 충돌이 나면 이미 적재된 것으로 보고 다음 노드로 진행한다.
- 발송 작업은 워크플로우 발송 건의 결과(SENT/SKIPPED/FAILED)를 기록하는 같은 트랜잭션에서, next_run_at이 비어 있는 해당 인스턴스를 깨운다. 다음 노드가 WAIT면 next_run_at = sent_at(SKIPPED·FAILED면 now) + 대기 시간, 아니면 now로 설정한다.
- 고객이 삭제되면 진행 중인 그 고객의 인스턴스는 `CANCELLED`로 바꾼다.

### 6.6 중복 방지 및 상태

- 백엔드는 단일 인스턴스로 운영하며, 인스턴스 조회에 FOR UPDATE SKIP LOCKED를 써서 스케줄러가 겹쳐 실행돼도 같은 건을 중복 처리하지 않게 한다.
- `send_log`에 `(instance_id, step_id)` 유니크 제약을 두어 같은 단계의 재발송을 막는다.
- 한 고객은 같은 캠페인에 인스턴스를 1개만 가진다(`(campaign_id, customer_id)` 유니크).
- 캠페인 일시정지 시 인스턴스와 이미 적재된 PENDING 발송 건이 모두 멈추고, 재개하면 밀린 건을 즉시 처리한다(광고성 시간 제한은 그대로 적용). 종료 시 진행 중 인스턴스는 `CANCELLED`로 바꾼다.

### 6.7 캠페인 상태

| 상태 | 의미 | 가능한 전이 |
|---|---|---|
| `DRAFT` | 작성 중 | → SCHEDULED, ACTIVE |
| `SCHEDULED` | 예약됨(일회성, SEGMENT_SCHEDULED) | → ACTIVE, DRAFT(취소) |
| `ACTIVE` | 실행 중 | → PAUSED, COMPLETED |
| `PAUSED` | 일시정지 | → ACTIVE, COMPLETED |
| `COMPLETED` | 종료 | 없음 |

일회성 캠페인은 전체 발송이 끝나면 자동으로 `COMPLETED`가 된다. `SEGMENT_SCHEDULED` 워크플로우는 모든 인스턴스가 끝나면 자동 종료되고, `CUSTOMER_REGISTERED` 워크플로우는 수동 종료 전까지 `ACTIVE`를 유지한다.

## 7. 데이터 모델

핵심 테이블은 v1의 9종에 9종을 더한 18종이다. 모든 테이블은 `created_at`, `updated_at`(TIMESTAMPTZ)을 가지며, PK는 PostgreSQL `BIGINT GENERATED ALWAYS AS IDENTITY`를 사용한다. 스키마는 이 표를 기준으로 W1에 Flyway `V1__init.sql`로 작성하고, 이후 변경도 Flyway 파일로만 한다.

| 테이블 | 구분 | 주요 컬럼 | 제약/인덱스 |
|---|---|---|---|
| `member` | 기존 | member_id, email, password(BCrypt), name, role(OWNER/MANAGER/STAFF), active_yn, refresh_token_hash, failed_login_count, locked_until | email UNIQUE |
| `customer` | 기존 | customer_id, name, email, phone, region_code, birth_date, joined_at, total_purchase, email_consent_yn, email_consent_at, sms_consent_yn, sms_consent_at, dormant_yn, dormant_at, consent_notified_at, source(MANUAL/UPLOAD), deleted_yn | email 부분 UNIQUE(deleted_yn = 'N'), (region_code), (joined_at), (birth_date), (total_purchase) 인덱스 |
| `consent_history` | 신규 | history_id, customer_id, channel, before_yn, after_yn, source(ADMIN/UPLOAD/UNSUBSCRIBE/BOUNCE/COMPLAINT), changed_at | (customer_id) 인덱스 |
| `segment` | 기존 | segment_id, name, description, created_by |  |
| `segment_rule` | 기존 | rule_id, segment_id, rule_json(JSONB) | segment_id UNIQUE |
| `template` | 기존 | template_id, channel(EMAIL/SMS), name, subject, body(TEXT), ad_yn, created_by |  |
| `campaign` | 기존 | campaign_id, name, type(ONE_TIME/WORKFLOW), status, segment_id, template_id(일회성), coupon_id(일회성, 선택), scheduled_at, trigger_type, started_at, ended_at | (status) 인덱스 |
| `ab_test` | 신규 | ab_test_id, campaign_id, subject_a, subject_b, sample_ratio, decide_after_min, winner, decided_at | campaign_id UNIQUE |
| `workflow_step` | 기존 | step_id, campaign_id, node_type, config_json(JSONB: 템플릿·쿠폰·대기 시간·조건), next_step_id, yes_step_id, no_step_id, depth | (campaign_id) 인덱스 |
| `workflow_instance` | 신규 | instance_id, campaign_id, customer_id, current_step_id, status(WAITING/RUNNING/COMPLETED/FAILED/CANCELLED), next_run_at, retry_count, last_error | (campaign_id, customer_id) UNIQUE, (status, next_run_at) 인덱스 |
| `send_log` | 기존 | send_log_id, campaign_id, instance_id, step_id, customer_id, channel, ab_variant, status(PENDING/SENDING/SENT/FAILED/SKIPPED/BOUNCED), kind(CAMPAIGN/NOTICE/TEST), priority, provider_message_id, tracking_token(UUID), attempt_count, next_attempt_at, error_message(SKIPPED·FAILED 사유 코드 포함), sent_at | (instance_id, step_id) UNIQUE(워크플로우), (campaign_id, customer_id) 부분 UNIQUE(instance_id IS NULL, 일회성·A/B), tracking_token UNIQUE, (campaign_id), (provider_message_id) 인덱스 |
| `track_link` | 신규 | link_id, template_id, original_url, link_order | (template_id) 인덱스 |
| `track_event` | 기존 | event_id, send_log_id, event_type(OPEN/CLICK), link_id, user_agent, ip_hash, bot_yn, occurred_at | (send_log_id, event_type), (occurred_at) 인덱스 |
| `coupon` | 신규 | coupon_id, name, discount_type(AMOUNT/RATE), discount_value, max_discount_amount(정률 상한), valid_from, valid_to |  |
| `coupon_issue` | 신규 | issue_id, coupon_id, customer_id, send_log_id, token, issued_at, used_at | token UNIQUE, (coupon_id, customer_id) 인덱스 |
| `ai_report` | 신규 | report_id, campaign_id, report_type, input_json(JSONB), content(TEXT), model | (campaign_id) 인덱스 |
| `suppression` | 신규 | suppression_id, channel(EMAIL/SMS), value(이메일 또는 휴대폰), reason(UNSUBSCRIBE/BOUNCE/COMPLAINT), created_at | (channel, value) UNIQUE |
| `purchase` | 신규 | purchase_id, customer_id, amount, coupon_issue_id(선택), created_by(관리자 등록만 존재), purchased_at | (customer_id), (coupon_issue_id) 인덱스 |

추가 규칙:

- 테이블·컬럼명은 PostgreSQL 관례에 따라 소문자 snake_case로 쓴다.
- 추적 URL에는 순번 ID 대신 `send_log.tracking_token`(UUID)을 쓴다(8.1).
- 수신거부 토큰은 `send_log_id + customer_id`를 HMAC 서명한 값으로 만든다(8.3). 고객 페이지 `/c/[token]`의 토큰은 `coupon_issue.token`(UUID)이다.
- `ip_hash`는 원본 IP를 저장하지 않고 SHA-256 해시로 저장한다.
- 고객 이메일은 삭제되지 않은 고객 사이에서만 유일하다. 논리 삭제된 고객과 같은 이메일로 재등록할 수 있도록 부분 유니크 인덱스를 쓴다(아래 SQL). 업로드·개별 등록의 중복 비교도 `deleted_yn = 'N'`인 고객만 대상으로 한다.
- 수신거부·반송·스팸신고가 발생하면 `suppression`에 이메일 또는 휴대폰 값을 저장한다. 고객이 삭제·재등록되어도 이 목록은 지우지 않으며, 등록·업로드·발송 적재·발송 직전에 항상 이 목록을 확인한다. 예외적으로 고객이 새로 동의했다는 증빙이 있으면 OWNER·MANAGER가 고객 상세에서 동의를 Y로 바꿀 수 있고, 이때 해당 값을 suppression에서 지우고 consent_history에 source=ADMIN으로 남긴다. 업로드로는 해제되지 않는다.
- 일회성·A/B 캠페인은 한 고객에게 한 번만 적재되도록 `send_log`에 부분 유니크 인덱스를 둔다(아래 SQL). PostgreSQL은 NULL끼리를 중복으로 보지 않으므로 워크플로우용 `(instance_id, step_id)` 제약만으로는 일회성 중복을 막지 못한다. 캠페인이 아닌 발송(F-12 수신동의 안내, F-04 테스트 발송)도 send_log에 기록하되 kind를 NOTICE/TEST로 두고 campaign_id는 비운다(campaign_id NULL 허용).

```sql
CREATE UNIQUE INDEX uq_customer_email_active
  ON customer (email) WHERE deleted_yn = 'N';

CREATE UNIQUE INDEX uq_send_log_one_time
  ON send_log (campaign_id, customer_id) WHERE instance_id IS NULL;
```

세그먼트 규칙 JSON 예시:

```json
{
  "operator": "AND",
  "groups": [
    {
      "operator": "OR",
      "conditions": [
        { "field": "region", "op": "IN", "value": ["SEOUL", "GYEONGGI"] },
        { "field": "totalPurchase", "op": "GTE", "value": 100000 }
      ]
    },
    {
      "operator": "AND",
      "conditions": [
        { "field": "age", "op": "BETWEEN", "value": [20, 34] },
        { "field": "joinedAt", "op": "IN_LAST_DAYS", "value": 90 }
      ]
    }
  ]
}
```

## 8. 추적·발송·법규·인프라

추적 URL은 원본 주소를 노출하지 않는 토큰 기반으로, 수신거부는 서명 토큰 기반으로 구현하고, 광고성 발송 규칙은 사람이 아니라 시스템이 강제한다.

### 8.1 오픈·클릭 추적

- 발송 직전 HTML 본문의 모든 `<a href>`를 `track_link`에 등록된 `/t/c/{``trackingToken``}/{linkId}`로 바꾸고, 본문 끝에 `/t/o/{``trackingToken``}.gif` 픽셀을 삽입한다. 단, 수신거부 링크, {{couponUrl}} 링크(고객마다 주소가 달라 track_link에 담을 수 없음), mailto:·tel: 링크는 치환하지 않는다.
- 클릭 API는 `linkId`로 원본 URL을 조회해 302 리다이렉트한다. 쿼리스트링의 URL로 리다이렉트하지 않는다(오픈 리다이렉트 방지).
- 추적 API는 인증 없이 호출되며, 처리 실패해도 픽셀/리다이렉트 응답은 항상 반환한다. 이벤트 저장은 비동기로 처리한다.
- 클릭이 발생했는데 오픈 이벤트가 없으면 오픈 이벤트도 함께 기록한다. 단, 봇 클릭은 오픈을 만들지 않는다.
- 한계 인지: Apple Mail 개인정보 보호, Gmail 이미지 프록시 등으로 오픈율은 부정확할 수 있다. 리포트에 이 안내 문구를 표시한다.

**추적 토큰.** `trackingToken`은 발송 건마다 만드는 UUID(`send_log.tracking_token`)다. 순번 ID를 URL에 쓰면 숫자만 바꿔 남의 오픈·클릭을 만들어낼 수 있으므로 쓰지 않는다. 없는 토큰이 들어와도 픽셀·리다이렉트 응답은 정상으로 주고 이벤트만 저장하지 않는다.

**봇 이벤트 판정.** 회사 메일 보안 솔루션과 백신은 메일 속 링크를 미리 열어 본다. 이런 이벤트는 저장하되 `bot_yn = Y`로 표시하고, 오픈율·클릭률 집계와 워크플로우 분기(6.3)에서 제외한다.

- 발송 후 10초(설정값) 이내에 발생한 클릭
- 알려진 보안 스캐너·봇 User-Agent (목록은 설정 파일로 관리)
- 한 발송 건의 모든 추적 링크가 1초 안에 동시에 클릭된 경우
- 판정 기준은 대시보드 수치에 직접 영향을 주므로 W3 통합 테스트에서 실제 메일로 검증한다.

### 8.2 메일 발송 (AWS SES)

- W1~W4는 MessageSender의 SMTP 구현으로 Mailpit에 발송해 확인한다. 운영은 도메인 없이 SES **이메일 주소 인증**(발신 주소 1개)과 **샌드박스** 상태로 한다. 샌드박스에서는 인증된 수신 주소로만 발송되고 초당 1건·하루 200건 한도가 있으므로, PL이 W3에 시연 수신 주소를 미리 인증한다. 발신 도메인 인증(DKIM·SPF)이 없어 수신 측에서 스팸함으로 분류될 수 있으며, 실제 도착 시연이 어려우면 Mailpit 녹화로 대체한다.
- 발송 속도는 SES 계정의 초당 한도를 넘지 않도록 설정값(`ses.max-send-rate`)으로 조절한다.
- SES 반송(Bounce, Permanent)과 스팸신고(Complaint)를 SNS → `POST /api/webhooks/ses`로 수신해 해당 고객의 이메일 수신동의를 N으로 바꾸고 `consent_history`에 기록한다.
- 발송 결과는 `send_log`에 `provider_message_id`와 함께 저장한다.

**SES 웹훅 보안과 검증.** `/api/webhooks/ses`는 인증 없이 열리므로 다음을 지킨다.

- SNS 메시지 서명을 검증하고, 등록한 토픽 ARN에서 온 요청만 처리한다. 검증 실패 요청은 무시하고 로그만 남긴다.
- SNS 구독 확인(SubscriptionConfirmation) 요청을 처리한다.
- 반송(Permanent)·스팸신고는 `suppression`에 추가하고 수신동의를 N으로 바꾼다.
- SNS는 공개 URL이 필요해 로컬(W1~W4)에서는 받을 수 없다. 로컬은 SNS 형식의 Mock 요청으로 처리 로직을 검증하고, 실제 연동은 W5 배포 후 확인한다.

**대량 발송 처리.** 10만 건을 한 번에 보내면 서버 메모리와 SES 한도를 모두 넘으므로, 발송은 적재 → 순차 소비 구조로 만든다. 일회성·A/B·워크플로우의 모든 메일/SMS 발송이 같은 큐와 같은 속도 제한을 거친다.

1. 발송 시작 시 대상자를 한 번에 메모리에 올리지 않고 500건씩 나눠 조회해 `send_log`에 `PENDING`으로 먼저 적재한다.
2. 발송 작업은 `PENDING` 건을 `FOR UPDATE SKIP LOCKED`로 꺼내 보내고 결과를 `SENT`/`FAILED`로 바꾼다.
3. 초당 발송 수는 설정값 `ses.max-send-rate`로 제한한다(토큰 버킷 방식). 값은 SES 승인 후 계정의 실제 한도로 맞춘다.
4. 서버가 중간에 멈추면 재시작 후 남은 `PENDING` 건부터 이어서 보낸다.
5. 로컬 Mailpit은 한도가 없으므로, 로컬에서도 같은 속도 제한이 동작하는지 테스트한다.

**발송 직전 재확인.** 적재와 실제 발송 사이에는 큐 대기(10만 건이면 약 2시간)나 야간 보류가 있을 수 있다. 그래서 발송 작업은 PENDING 건을 꺼내 보내기 직전에 다음을 다시 확인하고, 하나라도 해당하면 보내지 않고 `SKIPPED`로 기록한다.

- 고객의 해당 채널 수신동의가 N이거나 `suppression`에 있음
- 고객이 삭제됨
- 캠페인이 `PAUSED` 또는 `COMPLETED` 상태임 (`PAUSED`는 건너뛰지 않고 PENDING으로 남겨 재개 시 발송)
- 광고성 발송 또는 수신동의 안내(F-12)인데 현재 시각이 08:00~20:50 밖임 (건너뛰지 않고 다음 날 08:00까지 보류)

**발송 우선순위.** 발송 작업은 `priority`가 높은 건부터, 같으면 적재 순으로 꺼낸다. 대량 발송이 쌓여 있어도 환영 메일 같은 워크플로우 발송이 몇 시간씩 밀리지 않게 하기 위해서다.

| priority | 대상 |
|---|---|
| 1 (가장 먼저) | 테스트 발송 (F-04) |
| 2 | 워크플로우 발송, 수신동의 안내 (F-12) |
| 3 | 일회성·A/B 대량 발송 |

**발송 작업의 처리 순서와 재시도.**

1. 발송 작업은 `PENDING`이고 next_attempt_at이 비었거나 지난 건을 우선순위 순으로 `FOR UPDATE SKIP LOCKED`로 잡아 `SENDING`으로 바꾸고 바로 커밋한다. SES·SMS 호출은 DB 트랜잭션 밖에서 한다(잠금을 오래 잡지 않기 위해).
2. 발송 직전 재확인(위)을 통과한 건만 렌더링한다. 치환자 치환, (광고)·발신자·수신거부 문구 삽입, 추적 링크 치환, 쿠폰 발급은 모두 이 시점에 한다. SKIPPED 건에는 쿠폰을 발급하지 않는다.
3. 연결된 쿠폰이 유효기간 밖이면 보내지 않고 SKIPPED(사유 COUPON_INVALID)로 기록한다. 캠페인·SEND 노드를 저장할 때도 유효기간을 검사한다.
4. 일시 오류(SES 스로틀링, 네트워크)는 attempt_count를 올리고 1분·5분·15분 뒤로 next_attempt_at을 잡아 `PENDING`으로 되돌린다. 3회를 넘기거나 영구 오류(잘못된 주소 등)면 `FAILED`로 기록한다.
5. 서버가 멈춰 `SENDING`으로 10분 넘게 남은 건은 실제 발송 여부를 알 수 없으므로 다시 보내지 않고 `FAILED`(사유 UNKNOWN_RESULT)로 기록한다. 마케팅 메일이 두 번 나가는 것보다 한 건 누락이 낫다는 판단이다.

### 8.3 수신거부

- 링크 형식: `/unsubscribe``/[token]`. 토큰 = Base64URL(`send_log_id:customer_id:HMAC-SHA256`). 이메일 주소를 URL에 넣지 않는다.
- 토큰 검증 실패 시 "유효하지 않은 링크" 안내만 보여주고 고객 정보를 노출하지 않는다.
- 처리 즉시 DB에 반영하고, 진행 중인 워크플로우 인스턴스의 해당 채널 발송과 이미 큐에 적재된 PENDING 건은 발송 직전 재확인(8.2)에서 SKIPPED로 처리된다.

**수신거부 처리 방식.**

- `GET /unsubscribe/[token]`은 확인 화면만 보여준다. 링크를 여는 것만으로는 아무것도 바뀌지 않는다.
- 실제 처리는 사용자가 버튼을 눌러 보낸 POST 요청으로만 한다. 링크 스캐너가 수신거부를 대신 누르는 문제를 막기 위해서다.
- 모든 광고성 메일 헤더에 원클릭 수신거부(`List-Unsubscribe`, `List-Unsubscribe-Post: List-Unsubscribe=One-Click`)를 넣는다. 이 요청은 POST(`/api/v1/unsubscribe/one-click/{token}`)로만 처리하며 이메일 채널만 거부한다. Gmail·Yahoo 등은 대량 발신자에게 이를 요구하므로 없으면 스팸 분류 가능성이 커진다.

### 8.4 정보통신망법 대응 (시스템 강제 항목)

템플릿의 `ad_yn = Y`(광고성)인 경우 다음을 적용한다. 세부 요건은 KISA 불법스팸 방지 안내서로 최종 확인한다.

| 항목 | 구현 |
|---|---|
| 제목 표기 | 메일 제목 앞에 `(광고)` 자동 삽입 |
| 발신자 정보 | 본문 하단에 발신자 명칭, 연락처 자동 삽입 (시스템 설정값) |
| 수신거부 안내 | 본문 하단 수신거부 링크 자동 삽입, SMS는 무료 수신거부 문구 자동 추가 |
| 야간 발송 제한 | 광고성 발송은 08:00~20:50에만 한다. 예약은 예상 소요 시간을 더해 20:50 전에 끝나는 시각만 허용하고, AI 추천도 같은 범위로 제한한다. 발송 도중 20:50이 되면 남은 건을 멈추고 다음 날 08:00에 이어서 보낸다. 워크플로우 발송이 이 시간 밖에 걸리면 08:00로 보류한다 |
| 동의 기반 발송 | 수신동의 = Y인 고객에게만 발송 |
| 동의 이력 | `consent_history`에 모든 변경을 기록 |

야간 전송 제한(21:00~08:00)은 정보통신망법상 주로 문자(SMS) 등에 적용되고, 시행령에서 전자우편은 예외로 알려져 있다. 위드어스는 안전을 위해 메일에도 같은 시간 제한을 자체 정책으로 적용한다. 20:50 컷오프는 대량 발송이 21:00를 넘기지 않게 하는 10분 안전 마진이다. 위반 시 과태료 대상이므로 세부 요건은 KISA 안내서로 확인한다.

**SMS 광고 표기.** 광고성 SMS는 발송 시 다음을 자동으로 넣는다. 템플릿 작성자가 지울 수 없고, 바이트 수 계산(F-04)에 포함한다.

- 본문 맨 앞 `(광고)`
- 발신자 명칭 (시스템 설정값)
- 본문 끝 무료 수신거부 방법 (예: 무료수신거부 080-XXX-XXXX, 번호는 시스템 설정값)

### 8.5 인프라

- Spring 프로필: `local`(docker compose PostgreSQL, Mailpit, 로컬 디스크, SMS Mock), `prod`(RDS, SES, S3). 프로필 전환 외 코드 수정 없이 배포되어야 한다.
- 운영 구성: EC2(백엔드 1대) + RDS PostgreSQL + S3 + SES + AWS Amplify(프론트, Next.js SSR). RDS 자동 백업(보관 7일)을 켠다.
- 도메인·HTTPS 인증서를 따로 두지 않는다. 브라우저 요청·메일 링크·SES 웹훅은 모두 Amplify 주소(HTTPS)로 들어와 Next.js rewrites(`/api/*`, `/t/*`)로 EC2 백엔드에 전달된다(2.3). CORS는 열지 않는다. EC2는 Amplify에서 오는 HTTP 요청을 받도록 보안 그룹에서 백엔드 포트만 연다.
- 비밀값(DB 비밀번호, JWT 키, AWS 키, Gemini 키, HMAC 키)은 환경변수로만 주입하고 저장소에 커밋하지 않는다.
- S3 버킷은 이미지 경로만 공개 읽기를 허용한다. 발신자 명칭·연락처·080 수신거부 번호 등 "시스템 설정값"은 프로필별 application.yml(withus.sender.*)에서 관리한다.

## 9. 비기능 요구사항

목표 규모는 고객 10만 명, 캠페인당 발송 10만 건이며, 아래 기준을 만족해야 한다.

| 구분 | 기준 |
|---|---|
| 성능 | 목록 API 응답 1초 이내(페이지당 20건), 세그먼트 대상 수 미리보기 2초 이내(고객 10만 명 기준) |
| 추적 API | 픽셀/리다이렉트 응답 200ms 이내, 이벤트 저장은 비동기 |
| 업로드 | 10,000행 파일 30초 이내 처리, 배치 insert(500행 단위) |
| 발송 | 발송 10만 건을 500건 단위 분할 적재와 초당 발송 제한으로 누락 없이 처리(8.2), 서버 재시작 시 남은 PENDING 건부터 이어서 발송, 실패 건은 send_log에서 확인 가능 |
| 보안 | 비밀번호 BCrypt(로그인 5회 연속 실패 시 5분 잠금), SQL은 MyBatis `#{}` 바인딩만 사용(`${}` 금지), 공개 API(추적, 수신거부, 쿠폰 확인·사용, SES 웹훅) 외 모든 API 인증 필수. Access(30분)·Refresh(7일) 토큰은 httpOnly·Secure·SameSite=Lax 쿠키로 발급하고(Refresh는 Path=/api/v1/auth로 제한), 새로고침해도 로그인이 유지된다. Refresh 토큰은 member.refresh_token_hash에 해시로 저장해(사용자당 세션 1개: 다른 기기에서 로그인하면 이전 로그인은 종료된다) 재발급 시 교체, 로그아웃 시 무효화하고 쿠키를 만료시킨다. 쿠키는 요청마다 자동 전송되므로 인증이 필요한 상태 변경 요청(POST/PUT/PATCH/DELETE)에는 CSRF 토큰(Spring Security CookieCsrfTokenRepository, X-XSRF-TOKEN 헤더)을 요구한다. 공개 API는 자체 토큰으로 검증하므로 CSRF 검사에서 제외한다. 로그인·토큰 재발급 요청도 CSRF 검사를 받으므로 프론트는 앱 시작 시 CSRF 쿠키 발급 API(GET /api/v1/auth/csrf)를 먼저 호출한다(Spring Security 6 이상 SPA 설정: CookieCsrfTokenRepository.withHttpOnlyFalse + CsrfTokenRequestAttributeHandler). XSS 대책: 템플릿 HTML 미리보기는 sandbox iframe에서만 렌더링하고 dangerouslySetInnerHTML 사용 금지 |
| 개인정보 | 목록 화면에서 이메일·휴대폰 일부 마스킹, LLM에 개인정보 전달 금지, IP 원본 미저장 |
| 로깅 | 발송·스케줄러 오류는 캠페인ID/인스턴스ID 포함하여 기록 |
| 테스트 | 세그먼트 JSON → SQL 변환, 워크플로우 구조 검증, 워크플로우 단계 실행 로직은 단위 테스트 필수 |
| 브라우저 | 관리자 화면은 최신 Chrome/Edge 데스크톱 기준, 수신거부·쿠폰 고객 페이지는 모바일 대응 |

공통 API 규칙:

- API 계약은 SpringDoc OpenAPI(Swagger UI)를 기준으로 하며, 프론트는 이 명세에 맞춰 개발한다.
- 경로 접두어 `/api/v1`, 추적은 `/t`, 웹훅은 `/api/webhooks`.
- 페이징 파라미터 `page`(0부터), `size`(기본 20). 응답에 `totalElements`, `totalPages` 포함.
- 날짜/시간은 ISO-8601 문자열(`2026-10-05T09:00:00+09:00`)로 주고받는다.
- 오류 코드는 `도메인_사유` 형식(예: `SEGMENT_INVALID_RULE`, `CAMPAIGN_INVALID_STATUS`)으로 정의한다.
- TanStack Query 쿼리 키는 도메인 단위 공통 파일에서 관리한다.

## 10. 역할 분담, 일정, 완료 기준

팀은 4명이다. 팀원 3명은 시나리오 흐름(고객 → 발송 → 전환)을 한 구간씩 맡아 각자 도메인의 DB·API·화면을 끝까지(풀스택) 책임지고, PL은 모두가 기대는 공통 기반과 통합·배포를 맡는다.

### 10.1 역할 분담

구간별 도메인 배정은 아래와 같이 확정한다.

| 담당 | 구간 | 백엔드 패키지 | 화면·기능 |
|---|---|---|---|
| PL | 공통 기반·통합·배포 | auth, common | 폴리레포·docker compose·Flyway 초기 설정, 로그인/JWT, 사용자 관리, 공통 응답·예외, SpringDoc, Next.js 골격·공통 레이아웃, 통합 테스트, SES 신청(W3), AWS 배포(W5) |
| 팀원1 | 고객 | customer, segment | 고객 목록/상세, CSV 업로드, 수신동의·동의 이력, 세그먼트 빌더, 수신거부 페이지·수신거부 목록, SES 반송·스팸신고 웹훅, 휴면 판정 배치, 수신동의 2년 확인 안내(F-12), 구매 등록(purchase, 쿠폰 선택 시 CouponService 호출) |
| 팀원2 | 발송 | campaign(템플릿 포함), workflow | 템플릿 에디터·이미지 업로드, 캠페인 목록/생성, 일회성 예약 발송, 워크플로우 빌더·엔진, MessageSender(SMTP/SES/SMS Mock), 공통 발송 큐·속도 제한·우선순위·발송 직전 재확인 |
| 팀원3 | 전환 | tracking, coupon, ai | 오픈/클릭 추적 API, 쿠폰·고객 페이지(`/c/[token]`), 메인 대시보드, 성과 리포트, AI-01 문구 생성, AI-02 발송 시간 추천, AI-03 성과 요약, AI 공통 클라이언트(Gemini) |

구간 간 연결 지점 (W1에 인터페이스 먼저 합의):

- 발송(팀원2) → 고객(팀원1): `SegmentService.findTargetCustomers(segmentId)`, 수신동의 확인(`ConsentService.isSendable(customerId, channel)`, 적재용 일괄 판정 `ConsentService.filterSendable(customerIds, channel)` — 같은 규칙, 쿼리 1회)
- 발송(팀원2) → 전환(팀원3): `TrackingLinkService.rewrite(html, sendLogId)`, `CouponService.issue(couponId, customerId, sendLogId)`
- 워크플로우 CONDITION(팀원2) → 전환(팀원3): `TrackEventRepository` 조회
- 대시보드·리포트(팀원3) → 발송(팀원2): `send_log` 집계
- 발송 렌더링(팀원2) → 전환(팀원3): `PlaceholderRenderer`(치환자·기본값 처리, F-04). 팀원2 부담 분산을 위해 팀원3으로 이관 (roadmap 4장)
- 템플릿 에디터(팀원2) → AI-01 API(팀원3), 캠페인 생성 화면(팀원2) → AI-02 API(팀원3), SES 웹훅(팀원1) → send_log의 provider_message_id로 고객 조회(팀원2), 구매 등록(팀원1) → 쿠폰 사용 처리 CouponService(팀원3)

### 10.2 주차별 일정

| 주차 | PL | 팀원1 (고객) | 팀원2 (발송) | 팀원3 (전환) |
|---|---|---|---|---|
| W1 | 저장소·docker compose·Flyway V1, 인증, 공통 모듈, Next.js 골격 | 고객 CRUD, 도메인 API 명세 | 템플릿 CRUD, Mailpit 발송 확인 | 추적 API, Gemini 클라이언트 |
| W2 | 일회성 발송 E2E 통합 | CSV 업로드, 세그먼트 빌더 | 일회성 예약 발송, 링크 치환 연결 | 메인 대시보드, 캠페인 성과 차트 |
| W3 | SES 이메일 주소 인증, 통합 테스트 | 수신거부·수신거부 목록, 동의 이력, 휴면 배치, SES 웹훅(Mock 검증), 구매 등록 | 워크플로우 엔진·빌더(폼) | 쿠폰, `/c/[token]`, 전환 집계 |
| W4 | 통합 테스트, 코드 리뷰 | 수신동의 2년 확인 안내(F-12), 버그 수정 | 워크플로우 안정화, A/B 테스트(선택) | AI-01, AI-02, AI-03, 성과 리포트 마무리 |
| W5 | AWS 배포(EC2·RDS·S3·SES·Amplify), rewrites 프록시(`/api/*`, `/t/*`) | 운영 검증 | 운영 검증 | 운영 검증 |

### 10.3 완료 기준 (시연 시나리오)

- [ ] CSV로 고객 100명 업로드 후 성공/실패 건수가 표시된다
- [ ] "서울·경기, 구매액 10만 원 이상" 세그먼트를 만들고 대상 수가 미리보기된다
- [ ] 일회성 캠페인을 예약하면 지정 시각에 메일이 도착하고(로컬 Mailpit, 운영 SES — 인증된 수신 주소) 제목에 (광고)가 붙어 있다
- [ ] 메일을 열고 링크를 누르면 대시보드에 오픈·클릭이 반영된다
- [ ] 6.4 예시 구조의 워크플로우가 클릭/미클릭 고객에 따라 다른 메시지를 보낸다
- [ ] 메일로 받은 쿠폰을 `/c/[token]`에서 확인하고, 사용 처리하면 전환율에 반영된다
- [ ] 수신거부 후 해당 고객에게 더 이상 발송되지 않는다
- [ ] 21시에 광고 메일을 예약하려 하면 막히고 가능한 시각이 안내되며, 야간에 도달한 워크플로우 광고 발송은 다음 날 08시에 나간다
- [ ] AI 문구 3안, 발송 시간 추천, 성과 요약이 동작한다
- [ ] W5에 프로필 변경만으로 운영 환경에서 위 시나리오가 동작한다

- [ ] 수신거부 링크를 열기만 하면(GET) 처리되지 않고, 버튼을 눌러야 처리된다
- [ ] 이름이 없는 고객에게 "안녕하세요 고객님"처럼 기본값으로 발송된다
- [ ] 삭제된 고객과 같은 이메일로 다시 등록되고, 과거 수신거부 이력이 있으면 동의 N으로 등록된다
- [ ] 발송 후 10초 이내 클릭은 봇으로 표시되어 클릭률과 워크플로우 분기에서 빠진다
- [ ] 20:50을 넘겨 끝날 대량 예약은 막히고, AI는 08:00~20:00 시간대만 추천한다
- [ ] 발송 도중 서버를 재시작해도 남은 건부터 이어서 발송된다

- [ ] 같은 일회성 캠페인을 두 번 실행해도 고객당 한 번만 발송된다
- [ ] 추적 URL의 토큰을 임의로 바꾸면 이벤트가 저장되지 않는다
- [ ] (A/B 구현 시) 18시에 시작한 A/B 테스트의 승자 발송이 다음 날 08시에 나간다
- [ ] 쿠폰이 연결된 캠페인 메일에 고객별 쿠폰 링크가 들어간다
- [ ] 광고 SMS 앞에 (광고), 끝에 무료 수신거부 문구가 붙는다

- [ ] 관리자가 구매를 등록하면 누적구매액이 늘고, `PURCHASE_GTE` 분기와 전환율에 반영된다
- [ ] 고객 페이지의 '사용하기'는 한 번만 되고, 링크를 열기만 해서는 사용 처리되지 않는다
- [ ] 동의 일시를 2년 전으로 바꾼 테스트 고객에게 수신동의 확인 안내가 발송된다
- [ ] 새로고침해도 로그인이 유지되고, 토큰이 브라우저 JS(document.cookie, localStorage)에서 보이지 않으며, CSRF 토큰 없는 변경 요청은 거부된다

- [ ] 6.4 예시 워크플로우에서 경로에 따라 VIP 쿠폰과 일반 쿠폰이 각각 발급된다
- [ ] 10만 건 대량 발송이 쌓여 있어도 신규 가입 환영 메일이 먼저 나간다
- [ ] 적재 후 발송 전에 수신거부한 고객에게는 발송되지 않는다(SKIPPED)
- [ ] 야간 보류된 메일 뒤의 WAIT는 실제 발송 시각부터 계산되어 클릭 분기가 정상 동작한다
- [ ] 1만 명 대상 SEGMENT_SCHEDULED 워크플로우가 한 번의 스케줄 주기 안에서 모두 큐에 적재된다

- [ ] 처리 도중 서버를 강제 종료해도 RUNNING 인스턴스는 10분 뒤 복구되고, SENDING 건은 다시 나가지 않는다
- [ ] SES 스로틀링 오류를 흉내 내면 1분·5분·15분 간격으로 재시도된다
- [ ] 수신거부 링크와 쿠폰 링크는 추적 주소로 바뀌지 않는다
- [ ] 테스트 발송은 대시보드 통계에 잡히지 않는다
- [ ] 수신거부한 고객은 관리자가 증빙과 함께 동의 Y로 바꿀 때만 다시 발송 대상이 된다
- [ ] 발송 큐가 10만 건 처리 중이어도 휴면 배치 등 다른 스케줄 작업이 멈추지 않는다

- [ ] 대문자 이메일(Foo@A.com)로 업로드해도 기존 고객(foo@a.com)과 같은 사람으로 처리된다
- [ ] 하이픈이 있는 휴대폰 번호와 없는 번호가 수신거부 목록과 똑같이 비교된다
- [ ] 기존 고객을 CSV로 다시 올려도 등록된 구매로 쌓인 누적구매액이 줄지 않는다
- [ ] 로그인 5회 연속 실패 후 5분간 로그인이 막힌다

### 10.4 결정 사항

모든 항목을 권장안으로 확정했다. 시연용 가상 값은 아래 체크리스트의 시점에 실제 값으로 교체한다.

| 항목 | 결정 |
|---|---|
| 팀원별 도메인 배정 | 10.1대로 확정 |
| 쿠폰 할인 유형 | 정액·정률 모두 지원, 정률은 최대 할인액 상한 적용 |
| 쿠폰 유효기간 | 쿠폰별 고정 기간(valid_from~valid_to) |
| 휴면 기준 | 최근 180일 클릭(봇 제외)·구매 없음, 오픈은 판정에서 제외 |
| 고객 쿠폰 페이지 | 단순 쿠폰 카드형 |
| 메일 HTML 에디터 | TinyMCE (자체 설치, 도입 전 라이선스 조건 확인) |
| 백엔드 HTTPS | 별도 인증서 없음. Amplify 주소(HTTPS)에서 rewrites로 EC2에 프록시 |
| 도메인 | **구매하지 않음(비용 0원)**. 프론트는 Amplify 기본 주소, 메일 링크·웹훅도 그 주소로 프록시. 메일은 SES 이메일 주소 인증 + 샌드박스 |
| 봇 클릭 판정 | 발송 후 10초 이내 클릭, 스캐너 User-Agent, 1초 안 전체 링크 클릭 |
| 봇 판정 User-Agent | 초기값은 bot·crawler·spider·scanner·preview 키워드를 포함한 UA. 설정 파일로 관리하고 W3 실제 메일 검증 결과로 보강 |
| 치환자 시스템 기본값 | 이름 → 고객, 지역 → 빈 값, 누적구매액 → 0 |
| 발신자 명칭·연락처 | 시연용 위드어스 / 02-000-0000 (`withus.sender.name`, `withus.sender.phone`), 운영 전 실제 값으로 교체 |
| SMS 080 수신거부 번호 | 시연용 가상 번호 080-000-0000 (`withus.sender.unsubscribe-phone`), 실제 SMS 연동(O-03) 시 확보 |
| SES 초당 발송 한도 | 샌드박스 한도(초당 1건)에 맞춰 `ses.max-send-rate=1` 유지 |

값 교체 일정:

- [ ] SES 발신 주소·시연 수신 주소 인증 (W3, PL)
- [ ] 봇 판정 User-Agent 목록 보강 (W3, 팀원3)
- [ ] 발신자 명칭·연락처와 080 번호를 실제 값으로 교체 (W5 운영 배포 전, PL)
