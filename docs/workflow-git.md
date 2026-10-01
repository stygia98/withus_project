# Git 협업 규칙

저장소는 3개다: `withus`(메인: 문서·인프라), `withus_backend`, `withus_frontend`. 커밋과 PR은 **변경한 파일이 속한 저장소 안에서** 한다.

## 브랜치
```
main   ← 마일스톤(M1~M5) 때만 PL이 dev를 병합. 배포 기준
dev    ← 통합. 팀원 작업은 PR로만 들어온다 (직접 push 금지)
feature/{도메인}-{기능}   예: feature/segment-builder
fix/·hotfix/ 도 같은 방식
```

## 처음 세팅 (팀원, 1회)
```bash
# 폴더 이름을 withus 로 맞춘다 (저장소 이름은 withus_project)
git clone https://github.com/stygia98/withus_project.git withus && cd withus
git clone https://github.com/stygia98/withus_backend.git     # 반드시 withus 폴더 안에
git clone https://github.com/stygia98/withus_frontend.git
echo "@docs/roles/member1.md" > CLAUDE.local.md   # 본인 번호로
cp infra/.env.example infra/.env                  # 값 입력
cd infra && docker compose up -d
```
`CLAUDE.local.md`와 `infra/.env`는 `.gitignore` 대상이라 커밋되지 않는다. 기본 브랜치가 `dev`라 clone 하면 바로 `dev`가 받아진다.

## 작업 루틴
1. `git switch dev && git pull` → `git switch -c feature/도메인-기능`
2. 작업·커밋 (메시지 한국어, 예: `feat(segment): 조건 빌더 미리보기 API 추가`)
3. 하루 1회 `git pull origin dev` 로 dev를 가져온다 (충돌은 작을 때 해결)
4. 테스트 통과 확인: `./mvnw test` 또는 `npm run lint && npm run build`
5. `git push -u origin feature/...` → GitHub에서 **base: dev** 로 PR 생성, 팀장을 리뷰어로 지정
6. 수정 요청이 오면 같은 브랜치에 커밋·push (PR 자동 반영)
7. 병합 후: `git switch dev && git pull && git branch -d feature/...`

## 팀장(PL)
- PR은 CLAUDE.md 6·9장 위반(큐 우회, GET 상태변경, 시크릿, 기존 Flyway 수정, 번호 대역 충돌)을 중점 확인 후 dev에 병합
- dev → main 은 마일스톤(M1~M5) 시점에만
- `main`·`dev` 브랜치 보호(PR 필수·승인 1, 관리자 우회 허용) 설정

**PL 자신의 작업**
| 대상 | 방식 |
|---|---|
| backend·frontend 코드 | 팀원과 같이 `feature/...` 브랜치 → `dev`로 PR. 자기 PR은 승인할 수 없으므로 팀원에게 리뷰를 받거나(공통 모듈은 권장) 관리자 우회로 병합 |
| 메인 저장소 문서 (CLAUDE.md, roadmap 체크 등) | `dev`에 직접 push. 규칙이 바뀌면 팀에 공지 |
| `main` | 마일스톤 때만 `dev` → `main` |

**팀원이 받아야 할 변경**
- 코드: 작업 루틴 3번대로 자기 feature 브랜치에서 하루 1회 `git pull origin dev`. 마이그레이션이 추가됐으면 백엔드 재기동만 하면 Flyway가 적용한다.
- 문서: `withus` 폴더(메인 저장소, `dev` 그대로 사용)에서 가끔 `git pull`. PL이 규칙 변경을 공지하면 바로 받는다.

## 테스트 작성 규칙 (리뷰에서 실제로 겪은 문제)
통합 테스트는 각자 PC 의 로컬 Docker DB(시드 포함)를 함께 쓰고, 테스트 클래스끼리 Spring 컨텍스트를 공유한다. 그래서 **혼자 돌리면 통과하는데 전체로 돌리거나 다른 PC 에서 돌리면 깨지는** 테스트가 생기기 쉽다.

| 규칙 | 이유 (사례) |
|---|---|
| 데이터 개수를 고정값(`0건`, `1건`)으로 가정하지 않는다. **조회 전후 차이**로 검증한다 | 시드(고객 100명 등)나 다른 테스트 데이터가 있으면 실패 (backend #7 템플릿 수) |
| 무작위 테스트 값에 숫자를 섞지 않는다(검색어가 휴대폰 검색으로도 쓰임) | 시드 고객 휴대폰과 우연히 겹쳐 간헐 실패 (backend #9) |
| `@Transactional` 테스트에서 `JdbcTemplate` 으로 바꾼 값을 MyBatis 로 다시 읽으면 1차 캐시 결과가 나온다. 해당 select 에 `flushCache="true"` | 상태를 바꿔도 이전 값이 나옴 (backend #7) |
| MockMvc 에서 `with(csrf())` 를 쓰면 공유 컨텍스트의 CSRF 저장소가 바뀌어, 이후 실제 `GET /auth/csrf` 쿠키를 쓰는 테스트가 깨진다. **한 클래스 안에서 방식을 하나로**, `with(csrf())` 를 쓰는 클래스가 쿠키 방식 테스트보다 먼저 실행될 수 있으면 `@DirtiesContext` | 패키지 이름 순서에 따라 22건이 깨짐 (backend #7, #26) |
| URL 에 `%25` 처럼 인코딩한 값을 직접 쓰지 말고 `.param("keyword", "%" + tag)` 를 쓴다 | MockMvc 가 다시 인코딩해 의도와 다른 값이 전달됨 (backend #9) |
| "오늘"에 기대는 날짜는 고정 `Clock` 이나 상대 날짜(`CURRENT_DATE - 1`)로 만든다 | 특정 날짜가 지나면 실패하는 테스트 (backend #16) |
| PR 전에 **Docker DB 를 띄우고 `./mvnw test` 전체**를 돌린다. 못 돌렸으면 PR 에 그렇게 적는다 | DB 테스트를 못 돌린 PR 에서 우선순위 버그가 나옴 (backend #21) |

## 충돌 예방
- Flyway 번호 대역: PL `V1(동결)~V9`, 팀원1 `V10~V19`, 팀원2 `V20~V29`, 팀원3 `V30~V39` (부족하면 PL과 협의). 같은 번호가 생기면 기동이 실패한다.
  - 대역 때문에 낮은 번호(예: PL `V2`)가 높은 번호(`V10`) 뒤에 추가될 수 있어 `spring.flyway.out-of-order: true`로 둔다. 그래서 **적용 순서가 PC마다 다를 수 있다.** 다른 대역의 마이그레이션이 만드는 테이블·컬럼에 의존하는 SQL은 쓰지 말고, 필요하면 해당 담당자·PL과 먼저 맞춘다.
- 공유 파일(`common`, `application.yml`, `lib/query-keys.ts`)은 PL 리뷰가 필요하다.
- **다른 도메인 테이블**: 조회(SELECT)는 자기 mapper XML에서 해도 된다. 쓰기(INSERT·UPDATE·DELETE)는 소유 도메인의 서비스·인터페이스로만 한다 (예: 대시보드의 `send_log` 집계, 휴면 배치의 `track_event` 조회는 직접 SELECT 가능).
- `docs/`는 메인 저장소에서 커밋한다.

## V1 동결
- `V1__init.sql`과 PRD 10.1 인터페이스 6개(`SegmentService`, `ConsentService`, `TrackingLinkService`, `TrackEventRepository`, `CouponService`, `PlaceholderRenderer`)는 **확정·동결**됐다. V1은 절대 수정하지 않는다.
- 스키마 변경은 번호 대역에 맞는 새 파일로만 한다 (PL은 `V2`부터). 인터페이스 시그니처 변경은 PL 리뷰를 거친다.
- local 시드는 버전 번호를 쓰지 않는 `R__seed_local.sql`(반복 실행)이라 번호 대역과 충돌하지 않는다 (`docs/db/DB_SCHEMA.md` 9장).
- 로컬 DB를 처음부터 다시 만들고 싶으면(데이터 모두 삭제):
  ```bash
  cd infra
  docker compose down -v   # DB 볼륨까지 삭제
  docker compose up -d     # 백엔드를 다시 띄우면 마이그레이션이 처음부터 적용된다
  ```

## 작업 관리
- 팀 분배·진행 기준은 `docs/roadmap.md` 체크박스다. roadmap은 메인 저장소에 있어 코드 PR에 함께 넣을 수 없으므로, **PR 설명에 해당 roadmap 항목을 적고 체크는 PL이 병합할 때 한다.**
- 세부 작업 분해는 각자 Shrimp를 쓴다. Shrimp 데이터는 커밋하지 않는다.
- 발송 큐·워크플로우 엔진·인증·세그먼트 SQL은 코드 전에 Plan을 제시하고 PL 승인을 받는다.

## Plan 승인 절차
1. 메인 저장소에서 `feature/{주제}-plan` 브랜치를 만들고 `docs/plans/{주제}.md`에 Plan을 쓴다 (예: `docs/plans/segment-sql.md`). 근거 PRD 섹션, 처리 흐름, 테스트, 병합 순서, **PL에게 확인할 질문**을 담는다.
2. `dev`로 PR을 올린다. **PR 승인 = Plan 승인**이다. 승인 전에는 해당 코드를 쓰지 않는다.
3. PL은 승인하면서 반영 사항·질문 답변을 Plan 문서 맨 아래 **"PL 승인 결과"** 절에 남긴다 (PR 코멘트만으로 끝내지 않는다 — 문서에 남아야 구현할 때 다시 볼 수 있다).
4. 구현 PR 설명에는 해당 Plan 문서를 적는다.
