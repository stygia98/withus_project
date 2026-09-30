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
git clone <withus 주소> && cd withus
git clone <withus_backend 주소>
git clone <withus_frontend 주소>
echo "@docs/roles/member1.md" > CLAUDE.local.md   # 본인 번호로
```
`CLAUDE.local.md`는 `.gitignore` 대상이라 커밋되지 않는다. 이후 `cd infra && docker compose up -d`.

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
- Flyway 번호 대역: PL `V1~V9`, 팀원1 `V10~V19`, 팀원2 `V20~V29`, 팀원3 `V30~V39` (부족하면 PL과 협의). 같은 번호가 생기면 기동이 실패한다.
- 공유 파일(`common`, `application.yml`, `lib/query-keys.ts`)은 PL 리뷰가 필요하다.
- `docs/`는 메인 저장소에서 커밋한다.

## V1 동결 전 예외와 로컬 DB 초기화
- `V1__init.sql`은 **W1 ERD 확정 회의까지만** 수정할 수 있다. 수정하면 PL이 팀 채널에 공지한다.
- 공지를 받으면(또는 기동 시 `Migration checksum mismatch for migration version 1` 오류가 나면) 로컬 DB를 초기화한다. 로컬 DB 데이터는 모두 지워진다.
  ```bash
  cd infra
  docker compose down -v   # DB 볼륨까지 삭제
  docker compose up -d     # 백엔드를 다시 띄우면 새 V1이 적용된다
  ```
- 확정 회의 후 V1은 **동결**한다. 이후 스키마 변경은 번호 대역에 맞는 새 파일로만 한다 (PL은 `V2`부터).
- local 시드는 버전 번호를 쓰지 않는 `R__seed_local.sql`(반복 실행)이라 번호 대역과 충돌하지 않는다 (`docs/db/DB_SCHEMA.md` 9장).

## 작업 관리
- 팀 분배·진행 기준은 `docs/roadmap.md` 체크박스다. 항목 단위로 완료 시 갱신하고 PR에 포함한다.
- 세부 작업 분해는 각자 Shrimp를 쓴다. Shrimp 데이터는 커밋하지 않는다.
- 발송 큐·워크플로우 엔진·인증·세그먼트 SQL은 코드 전에 Plan을 제시하고 PL 승인을 받는다.
