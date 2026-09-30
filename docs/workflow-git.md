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
- dev → main 은 마일스톤 시점에만
- `main`·`dev` 브랜치 보호(직접 push 금지, PR 필수) 설정

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
