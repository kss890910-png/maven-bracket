-- MaveN 클럽 내전 대진표 · Supabase 설정 (한 번만 실행)
-- 실행 위치: Supabase 대시보드 → SQL Editor → 새 쿼리 → 전체 붙여넣기 → Run
-- 실행 전에 맨 아래 '여기에_관리자_PIN' 을 원하는 비밀번호로 바꾸세요 (6자 이상 권장).
-- 전술보드 테이블은 건드리지 않습니다. 이 파일은 maven_bracket_* 이름만 만듭니다.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.maven_bracket_results (
  match_id   smallint primary key check (match_id between 1 and 7),
  w          smallint check (w in (0, 1)),
  a          integer check (a >= 0),
  b          integer check (b >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.maven_bracket_admin (
  id       smallint primary key default 1 check (id = 1),
  pin_hash text not null
);

alter table public.maven_bracket_results enable row level security;
alter table public.maven_bracket_admin   enable row level security;

-- 누구나 결과를 읽을 수 있음. 쓰기 정책은 없음 → 아래 함수(PIN 확인)로만 기록.
drop policy if exists "maven results are public" on public.maven_bracket_results;
create policy "maven results are public" on public.maven_bracket_results
  for select to anon, authenticated using (true);
-- maven_bracket_admin 에는 정책이 없으므로 브라우저에서 읽을 수 없음.

create or replace function public.maven_check_pin(p_pin text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.maven_bracket_admin
    where id = 1 and pin_hash = crypt(p_pin, pin_hash)
  );
$$;

create or replace function public.maven_set_result(
  p_pin text, p_match smallint, p_w smallint, p_a integer, p_b integer
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.maven_check_pin(p_pin) then
    raise exception 'invalid pin' using errcode = '28P01';
  end if;
  if p_w is null and p_a is null and p_b is null then
    delete from public.maven_bracket_results where match_id = p_match;
  else
    insert into public.maven_bracket_results (match_id, w, a, b, updated_at)
    values (p_match, p_w, p_a, p_b, now())
    on conflict (match_id) do update
      set w = excluded.w, a = excluded.a, b = excluded.b, updated_at = now();
  end if;
end;
$$;

create or replace function public.maven_clear(p_pin text, p_matches smallint[])
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.maven_check_pin(p_pin) then
    raise exception 'invalid pin' using errcode = '28P01';
  end if;
  delete from public.maven_bracket_results where match_id = any (p_matches);
end;
$$;

revoke all on function public.maven_check_pin(text) from public;
revoke all on function public.maven_set_result(text, smallint, smallint, integer, integer) from public;
revoke all on function public.maven_clear(text, smallint[]) from public;
grant execute on function public.maven_check_pin(text) to anon, authenticated;
grant execute on function public.maven_set_result(text, smallint, smallint, integer, integer) to anon, authenticated;
grant execute on function public.maven_clear(text, smallint[]) to anon, authenticated;

-- 팀 명단 (비어 있으면 페이지에 적힌 기본 명단을 씀)
create table if not exists public.maven_bracket_teams (
  team_no    smallint primary key check (team_no between 1 and 8),
  members    text[] not null check (array_length(members, 1) between 1 and 4),
  updated_at timestamptz not null default now()
);
alter table public.maven_bracket_teams enable row level security;
drop policy if exists "maven teams are public" on public.maven_bracket_teams;
create policy "maven teams are public" on public.maven_bracket_teams
  for select to anon, authenticated using (true);

create or replace function public.maven_set_team(p_pin text, p_team smallint, p_members text[])
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.maven_check_pin(p_pin) then
    raise exception 'invalid pin' using errcode = '28P01';
  end if;
  if exists (select 1 from unnest(p_members) m where length(m) > 30) then
    raise exception 'name too long';
  end if;
  insert into public.maven_bracket_teams (team_no, members, updated_at)
  values (p_team, p_members, now())
  on conflict (team_no) do update set members = excluded.members, updated_at = now();
end;
$$;
revoke all on function public.maven_set_team(text, smallint, text[]) from public;
grant execute on function public.maven_set_team(text, smallint, text[]) to anon, authenticated;

-- 실시간 갱신
do $$
begin
  alter publication supabase_realtime add table public.maven_bracket_results;
exception when duplicate_object then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.maven_bracket_teams;
exception when duplicate_object then null;
end $$;

-- 관리자 PIN 설정 (다시 실행하면 PIN 이 바뀝니다)
insert into public.maven_bracket_admin (id, pin_hash)
values (1, extensions.crypt('여기에_관리자_PIN', extensions.gen_salt('bf')))
on conflict (id) do update set pin_hash = excluded.pin_hash;
