# MaveN 2회 클럽 내전 대진표

프리스타일 리부트 3대3 클럽 내전(8팀 · 7경기) 대진표. 로그인 없이 링크로 보고, 관리자만 PIN으로 승패를 체크한다.

- `index.html` — 페이지 전체 (빌드 없음, Vercel 정적 배포)
- `assets/` — MaveN 클럽 마크, 프리스타일 리부트 키아트(©JOYCITY, 클럽 비상업 내부 행사용)
- `supabase/schema.sql` — 결과 테이블과 PIN 확인 함수. Supabase SQL Editor에서 한 번 실행

## 저장 구조

- `maven_bracket_results` — 경기별 결과(`w` 이긴 쪽 0/1, 점수 `a`/`b`). 누구나 읽기만 가능
- 쓰기는 `maven_set_result` / `maven_clear` 함수로만 가능하고, 둘 다 관리자 PIN을 확인한다
- PIN은 `maven_bracket_admin`에 bcrypt 해시로만 저장된다. 바꾸려면 `schema.sql` 마지막 문장만 새 PIN으로 다시 실행

## 팀·멤버 수정

`index.html`의 `TEAMS` 배열을 고치고 push하면 Vercel이 다시 배포한다.
