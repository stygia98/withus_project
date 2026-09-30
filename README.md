# 위드어스 (Withus)

세그먼트 기반 CRM 마케팅 자동화 솔루션. 이 저장소는 **문서·로컬 인프라·배포 설정**을 담는 메인 저장소이고, 코드는 하위의 독립 저장소 두 개에 있다.

| 저장소 | 내용 |
|---|---|
| `withus` (이 저장소) | `CLAUDE.md`, `docs/`, `infra/`, `.github/` |
| `withus_backend` | Spring Boot 4.0 · MyBatis · Flyway · PostgreSQL 17 |
| `withus_frontend` | Next.js 15 · React 19 · Tailwind 4 · shadcn/ui |

## 처음 시작하기 (팀원)
```bash
git clone <withus 주소> && cd withus
git clone <withus_backend 주소>       # 반드시 withus 폴더 안에
git clone <withus_frontend 주소>

echo "@docs/roles/member1.md" > CLAUDE.local.md   # 본인 번호로 (커밋되지 않음)
cp infra/.env.example infra/.env                  # 값 입력 (커밋되지 않음)
cd infra && docker compose up -d                  # PostgreSQL 17 + Mailpit(http://localhost:8025)
```
실행 방법은 각 저장소의 README, 협업 절차는 [`docs/workflow-git.md`](docs/workflow-git.md).

## 문서
| 문서 | 용도 |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | 개발 규칙 (전원 공통, PL만 수정) |
| [`docs/prd.md`](docs/prd.md) | 기준 요구사항 (PRD v2.3) |
| [`docs/roadmap.md`](docs/roadmap.md) | 주차별 작업·담당 — **팀 진행 체크 기준** |
| [`docs/roles/`](docs/roles/) | 담당별 범위·인터페이스·체크리스트 |
| [`docs/api/API_SPEC.md`](docs/api/API_SPEC.md) | API 계약 초안 (최종은 Swagger) |
| [`docs/db/DB_SCHEMA.md`](docs/db/DB_SCHEMA.md) | 스키마, `V1__init.sql` 원본 |
| [`docs/tech/TECH_STACK_DRAFT.md`](docs/tech/TECH_STACK_DRAFT.md) | 의존성·설정·버전 고정표 |

## 담당
PL(기반·통합·배포) · 팀원1(고객: customer, segment) · 팀원2(발송: campaign, workflow) · 팀원3(전환: tracking, coupon, ai)
