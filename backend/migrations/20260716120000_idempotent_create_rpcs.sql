-- 20260716120000_idempotent_create_rpcs.sql
-- Make every create_* write RPC idempotent on a client-supplied id (issue #9, Decision 41).
-- Forward-only; never edit the executable SQL after it has run somewhere — add a new migration.
-- Conventions: docs/database.md.
--
-- PROBLEM (CodeRabbit, PR #8, re-raised on create_event_type in Slice 2): every create_* minted the
-- id server-side (gen_random_uuid()) then the repo did a SEPARATE _fetchOne. If the response drops
-- after the row is committed (or the user re-taps a hung "Add"), a retry inserts a DUPLICATE. This
-- window was open on all 7 create RPCs.
--
-- FIX (uniform): each create_* gains a trailing optional `p_id uuid default null`; the body computes
-- `v_id := coalesce(p_id, gen_random_uuid())`, inserts the id EXPLICITLY, and does
-- `on conflict (id) do nothing`. The repo's existing `_fetchOne(v_id)` then returns the row whether it
-- was just inserted or already existed → a same-id retry is a harmless no-op, not a second row. The
-- client mints the id up front (lib/util/ids.dart) and each form reuses it across re-taps. p_id is
-- appended LAST — PostgREST binds params by name, so order is irrelevant to callers, and a trailing
-- defaulted param keeps every signature valid. update_*/soft_delete_* are unchanged (retrying
-- re-applies the same values — already idempotent).
--
-- Semantics of a CHANGED-payload replay (create committed, response dropped, user edits, re-Saves the
-- SAME id): `on conflict (id) do nothing` is first-write-wins on the scalar columns, and the junction
-- inserts (event_attendees / task_contacts / task_category_links) UNION rather than replace. This is
-- correct idempotent-create behaviour, not a lost update — `_fetchOne(v_id)` returns the actually-
-- persisted row, and the way to make an after-the-fact edit take effect is the Edit path (`update_*`,
-- last-write-wins + delete-then-reinsert on the junctions), not a re-Save. The trigger window is narrow.
--
-- Why DROP + recreate (not `create or replace`): a function's identity is name + argument TYPES.
-- Appending a param — even defaulted — is a NEW signature, so create-or-replace would leave the old
-- overload in place and a PostgREST named-arg call could hit PGRST203 ("could not choose the best
-- candidate function"). Dropping the exact old signature first avoids that. (create_task_comment was
-- last redefined in-place by 20260715120000 keeping its signature; here it changes, so it drops too.)
--
-- LOCKDOWN INVARIANT (Decision 36; recreate re-grant rule per Decision 38 / docs/database.md rule #2):
-- DROP discards the old function's ACL, and a recreate gets Postgres's DEFAULT PUBLIC execute back. So
-- each recreated RPC below MUST re-issue BOTH `revoke execute … from public` AND
-- `grant execute … to anon, authenticated` on the NEW signature — otherwise the RPC silently reopens
-- to PUBLIC. Verify with `has_function_privilege('public', oid, 'execute') = false`.
--
-- Ends with `notify pgrst, 'reload schema'`: the client now calls the NEW signatures, and
-- deploy-homebase.sh applies SQL over psql but never reloads PostgREST — without this, create would
-- 404 (PGRST202) in prod between deploy and a manual reload (same reason as events_rpc_add_type).
--
-- (No auth.uid() ownership checks: there is NO auth — single-user + tailnet-only, login is WON'T-DO,
-- Decision 37. Same posture as every sibling RPC.)

drop function if exists public.create_contact(text, date, text, text, text, text);
drop function if exists public.create_event(text, date, boolean, time, time, text, text, uuid[], uuid);
drop function if exists public.create_event_type(text, text);
drop function if exists public.create_task(text, text, uuid[], smallint, uuid[]);
drop function if exists public.create_task_category(text, text);
drop function if exists public.create_comment(uuid, text);
drop function if exists public.create_task_comment(uuid, text);

-- create_contact -----------------------------------------------------------
create or replace function public.create_contact(
  p_name    text,
  p_dob     date,
  p_email   text,
  p_phone   text,
  p_company text,
  p_remarks text,
  p_id      uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  -- Empty→null normalization lives here (server-side), matching the event template, so it's
  -- in one place. trim(p_name) also drives the table's check (length(trim(name)) > 0): a blank
  -- name raises a check violation, exactly as the old direct write relied on. on conflict (id) do
  -- nothing makes a same-id retry a no-op (issue #9): the repo's _fetchOne(v_id) returns the row.
  insert into public.contacts (id, name, dob, email, phone, company, remarks)
  values (
    v_id,
    trim(p_name),
    p_dob,
    nullif(trim(p_email), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_company), ''),
    nullif(trim(p_remarks), '')
  )
  on conflict (id) do nothing;

  return v_id;
end;
$$;

-- create_event -------------------------------------------------------------
create or replace function public.create_event(
  p_title      text,
  p_event_date date,
  p_all_day    boolean,
  p_start_time time,
  p_end_time   time,
  p_location   text,
  p_notes      text,
  p_attendees  uuid[],
  p_type_id    uuid default null,
  p_id         uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  insert into public.events (id, title, event_date, all_day, start_time, end_time, location, notes, type_id)
  values (
    v_id,
    trim(p_title),
    p_event_date,
    coalesce(p_all_day, false),
    case when coalesce(p_all_day, false) then null else p_start_time end,
    case when coalesce(p_all_day, false) then null else p_end_time end,
    nullif(trim(p_location), ''),
    nullif(trim(p_notes), ''),
    p_type_id
  )
  on conflict (id) do nothing;

  -- unnest(NULL) and unnest('{}') both yield zero rows, so this is a safe no-op when
  -- there are no attendees. on conflict do nothing dedupes repeated ids (and re-inserting the
  -- same set on an idempotent retry is harmless).
  insert into public.event_attendees (event_id, contact_id)
  select v_id, a from unnest(p_attendees) as a
  on conflict do nothing;

  return v_id;
end;
$$;

-- create_event_type --------------------------------------------------------
create or replace function public.create_event_type(
  p_name  text,
  p_color text,
  p_id    uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  -- trim(p_name) drives the table's check (length(trim(name)) > 0): a blank name raises a
  -- check violation, exactly as the old direct write relied on. p_color is a clean #RRGGBB
  -- built by the client from the palette; the table's color check re-validates it.
  insert into public.event_types (id, name, color)
  values (v_id, trim(p_name), p_color)
  on conflict (id) do nothing;

  return v_id;
end;
$$;

-- create_task --------------------------------------------------------------
create or replace function public.create_task(
  p_title      text,
  p_notes      text     default null,
  p_contacts   uuid[]   default '{}',
  p_importance smallint default 0,
  p_categories uuid[]   default '{}',
  p_id         uuid     default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  -- trim(p_title) drives the table's check (length(trim(title)) > 0): a blank title raises a
  -- check violation. notes are optional — nullif(trim(...), '') stores NULL for blank/whitespace.
  -- importance is range-checked by the column's `between 0 and 3`. New tasks are always live and
  -- not-done (is_done defaults false).
  insert into public.tasks (id, title, notes, importance)
  values (v_id, trim(p_title), nullif(trim(p_notes), ''), p_importance)
  on conflict (id) do nothing;

  -- unnest(NULL) and unnest('{}') both yield zero rows, so this is a safe no-op when there are
  -- no People. on conflict do nothing dedupes repeated ids against the composite PK.
  insert into public.task_contacts (task_id, contact_id)
  select v_id, c from unnest(p_contacts) as c
  on conflict do nothing;

  -- Categories — the identical unnest-insert against the link table (same safety: no-op on empty,
  -- dedupe on the composite PK). A bad category id would raise a FK violation and roll the call back.
  insert into public.task_category_links (task_id, category_id)
  select v_id, c from unnest(p_categories) as c
  on conflict do nothing;

  return v_id;
end;
$$;

-- create_task_category -----------------------------------------------------
create or replace function public.create_task_category(
  p_name  text,
  p_color text,
  p_id    uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  -- trim(p_name) drives the table's check (length(trim(name)) > 0): a blank name raises a check
  -- violation. p_color is a clean #RRGGBB built by the client from the palette; the table's color
  -- check re-validates it.
  insert into public.task_categories (id, name, color)
  values (v_id, trim(p_name), p_color)
  on conflict (id) do nothing;

  return v_id;
end;
$$;

-- create_comment (event comments) ------------------------------------------
create or replace function public.create_comment(
  p_event_id uuid,
  p_body     text,
  p_id       uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  -- trim(p_body) drives the table's check (length(trim(body)) > 0): a blank body raises a
  -- check violation. The event_id FK (on delete restrict) fires if p_event_id is unknown.
  insert into public.event_comments (id, event_id, body)
  values (v_id, p_event_id, trim(p_body))
  on conflict (id) do nothing;

  return v_id;
end;
$$;

-- create_task_comment ------------------------------------------------------
-- Keeps the Decision 36 archived-parent guard folded into the insert (race-safe vs a concurrent
-- soft_delete_task). The insert can affect zero rows for TWO reasons now: (a) the parent task is
-- archived/missing (the guard — must raise), or (b) this exact id already exists (an idempotent
-- replay — must succeed). The old `if not found` couldn't tell them apart; distinguish by checking
-- the row exists AFTER the insert, and only raise for the genuine archived/missing-parent case.
create or replace function public.create_task_comment(
  p_task_id uuid,
  p_body    text,
  p_id      uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_id, gen_random_uuid());
begin
  insert into public.task_comments (id, task_id, body)
  select v_id, p_task_id, trim(p_body)
  where exists (
    select 1 from public.tasks where id = p_task_id and deleted_at is null
  )
  on conflict (id) do nothing;

  -- Row absent → the guard rejected it (archived/missing parent). Row present → it was inserted now
  -- OR by a prior attempt with this id (replay) — either way, success. This also stays correct in the
  -- "created live, parent archived between attempts, retried" case: the row from attempt 1 exists.
  if not exists (select 1 from public.task_comments where id = v_id) then
    raise exception 'task % not found or archived', p_task_id
      using errcode = 'no_data_found';
  end if;

  return v_id;
end;
$$;

-- Re-lock the NEW signatures (the drops above discarded the old functions' ACLs). Both are needed:
-- the PUBLIC revoke re-asserts the Decision 36 lockdown that the recreate reset; the anon/
-- authenticated grant keeps the app working (docs/database.md rule #2).
revoke execute on function public.create_contact(text, date, text, text, text, text, uuid)                    from public;
revoke execute on function public.create_event(text, date, boolean, time, time, text, text, uuid[], uuid, uuid) from public;
revoke execute on function public.create_event_type(text, text, uuid)                                         from public;
revoke execute on function public.create_task(text, text, uuid[], smallint, uuid[], uuid)                     from public;
revoke execute on function public.create_task_category(text, text, uuid)                                      from public;
revoke execute on function public.create_comment(uuid, text, uuid)                                            from public;
revoke execute on function public.create_task_comment(uuid, text, uuid)                                       from public;

grant execute on function public.create_contact(text, date, text, text, text, text, uuid)                    to anon, authenticated;
grant execute on function public.create_event(text, date, boolean, time, time, text, text, uuid[], uuid, uuid) to anon, authenticated;
grant execute on function public.create_event_type(text, text, uuid)                                         to anon, authenticated;
grant execute on function public.create_task(text, text, uuid[], smallint, uuid[], uuid)                     to anon, authenticated;
grant execute on function public.create_task_category(text, text, uuid)                                      to anon, authenticated;
grant execute on function public.create_comment(uuid, text, uuid)                                            to anon, authenticated;
grant execute on function public.create_task_comment(uuid, text, uuid)                                       to anon, authenticated;

-- Refresh PostgREST's schema cache so the new signatures resolve immediately (see header).
notify pgrst, 'reload schema';
