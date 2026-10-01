# 위드어스 (Withus)

세그먼트 기반 CRM 마케팅 자동화 솔루션. 이 저장소는 **문서·로컬 인프라·배포 설정**을 담는 메인 저장소이고, 코드는 하위의 독립 저장소 두 개에 있다.

| 저장소 | 내용 |
|---|---|
| `withus` (이 저장소) | `CLAUDE.md`, `docs/`, `infra/`, `.github/` |
| `withus_backend` | Spring Boot 4.0 · MyBatis · Flyway · PostgreSQL 17 |
| `withus_frontend` | Next.js 15 · React 19 · Tailwind 4 · shadcn/ui |

## 처음 시작하기 (팀원)
```bash
# 폴더 이름을 withus 로 맞춘다 (저장소 이름은 withus_project)
git clone https://github.com/stygia98/withus_project.git withus && cd withus
git clone https://github.com/stygia98/withus_backend.git     # 반드시 withus 폴더 안에
git clone https://github.com/stygia98/withus_frontend.git

echo "@docs/roles/member1.md" > CLAUDE.local.md   # 본인 번호로 (커밋되지 않음)
cp infra/.env.example infra/.env                  # 값 입력 (커밋되지 않음)
cd infra && docker compose up -d                  # PostgreSQL 17 + Mailpit(http://localhost:8025)
```
실행 방법은 각 저장소의 README, 협업 절차는 [`docs/workflow-git.md`](docs/workflow-git.md).

- Windows는 Docker Desktop 설치 시 WSL 설치와 재부팅이 필요하다.
- 백엔드를 띄운 뒤 `infra/.env`의 `OWNER_EMAIL`/`OWNER_PASSWORD`로 로그인한다 (http://localhost:3000/login 또는 Swagger).

- PC에 PostgreSQL이 이미 설치돼 5432를 쓰고 있으면 `infra/.env`의 `DB_PORT`를 5433 등으로 바꾼다.
- 스키마(V1)와 구간 인터페이스는 **확정·동결**됐다. 스키마 변경은 새 Flyway 파일로만 한다 → [`docs/workflow-git.md`](docs/workflow-git.md#v1-동결)

## 문서
| 문서 | 용도 |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | 개발 규칙 (전원 공통, PL만 수정) |
| [`docs/prd.md`](docs/prd.md) | 기준 요구사항 (PRD v2.3) |
| [`docs/roadmap.md`](docs/roadmap.md) | 주차별 작업·담당 — **팀 진행 체크 기준** |
| [`docs/roles/`](docs/roles/) | 담당별 범위·인터페이스·체크리스트 |
| [`docs/api/API_SPEC.md`](docs/api/API_SPEC.md) | API 계약 초안 (최종은 Swagger) |
| [`docs/db/DB_SCHEMA.md`](docs/db/DB_SCHEMA.md) | 스키마, `V1__init.sql` 원본 |
| [`docs/tech/TECH_STACK.md`](docs/tech/TECH_STACK.md) | 의존성·설정·버전 고정표 (6장 결정 사항) |
| [`docs/plans/`](docs/plans/) | 승인된 설계 Plan (발송 큐·워크플로우·세그먼트 SQL 등). 구현 전 "PL 승인 결과" 절 확인 |
| [`docs/meetings/`](docs/meetings/) | **결정 기록 — 시작 전 [킥오프 결정 사항](docs/meetings/kickoff-decisions.md) 먼저 읽기** |

## 담당
PL(기반·통합·배포) · 팀원1(고객: customer, segment) · 팀원2(발송: campaign, workflow) · 팀원3(전환: tracking, coupon, ai)
