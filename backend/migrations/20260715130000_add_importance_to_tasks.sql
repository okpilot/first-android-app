-- 20260715130000_add_importance_to_tasks.sql
-- Task importance — a fixed 0..3 priority marker (none / ! / !! / !!!). Decision 38.
-- Forward-only; never edit the executable SQL after it has run somewhere — add a new migration.
-- Conventions: docs/database.md.
--
-- Adds one scalar column and threads it through the two task-write RPCs. `importance` is a fixed
-- semantic scale (0 = none, 1/2/3 = !/!!/!!!), NOT user-owned colour-as-data (Decision 19) — the
-- UI maps each level to a fixed hue. NOT NULL default 0 backfills every existing row to "none".
-- The `check (importance between 0 and 3)` is the DB-side guard; a client sending out-of-range
-- raises a check violation.
--
-- Adding p_importance changes each RPC's signature (identity), so create-or-replace alone would
-- leave the old overload and make PostgREST calls ambiguous (PGRST203) — hence the
-- `drop function if exists <OLD signature>` before each `create or replace`, per the project's
-- signature-change convention (docs/database.md; same pattern add_contacts_to_tasks.sql uses). Each
-- recreated body is the prior body VERBATIM (security definer, set search_path, trim, nullif-notes,
-- the `deleted_at is null` guard, the not-found raise, the People delete+reinsert) PLUS the
-- importance column — nothing else changes.
--
-- LOCKDOWN INVARIANT (Decision 36): dropping the old functions discards the `revoke execute … from
-- public` that 20260715120000_preauth_lockdown.sql put on them, and the recreated functions get
-- Postgres's DEFAULT PUBLIC execute back. So this migration MUST re-issue BOTH the PUBLIC revoke
-- AND the anon/authenticated grant on the NEW signatures — otherwise the RPCs silently reopen to
-- PUBLIC. This is the general rule for any drop+recreate of a client-facing RPC after the lockdown
-- (docs/database.md rule #2). soft_delete_task / restore_task are untouched → their ACLs stand.
--
-- (No auth.uid() ownership checks: there is NO auth — single-user + tailnet-only, login is WON'T-DO,
-- Decision 37. Same posture as every sibling RPC.)

-- Column -------------------------------------------------------------------
alter table public.tasks
  add column importance smallint not null default 0
  check (importance between 0 and 3);

-- create (title + notes + People + importance) — replaces create_task(text, text, uuid[]) ---------
drop function if exists public.create_task(text, text, uuid[]);

create or replace function public.create_task(
  p_title      text,
  p_notes      text     default null,
  p_contacts   uuid[]   default '{}',
  p_importance smallint default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  -- trim(p_title) drives the table's check (length(trim(title)) > 0): a blank title raises a
  -- check violation. notes are optional — nullif(trim(...), '') stores NULL for blank/whitespace.
  -- importance is range-checked by the column's `between 0 and 3`. New tasks are always live and
  -- not-done (is_done defaults false).
  insert into public.tasks (title, notes, importance)
  values (trim(p_title), nullif(trim(p_notes), ''), p_importance)
  returning id into v_id;

  -- unnest(NULL) and unnest('{}') both yield zero rows, so this is a safe no-op when there are
  -- no People. on conflict do nothing dedupes repeated ids against the composite PK.
  insert into public.task_contacts (task_id, contact_id)
  select v_id, c from unnest(p_contacts) as c
  on conflict do nothing;

  return v_id;
end;
$$;

-- update (title + done + notes + People + importance) —
--   replaces update_task(uuid, text, boolean, text, uuid[]) ---------------------------------------
drop function if exists public.update_task(uuid, text, boolean, text, uuid[]);

-- p_importance is REQUIRED here (no default) — same defensive rule as p_contacts: an update
-- re-sends the whole task, so an omitted arg would silently RESET importance to 0. Without a
-- default, a mismatched caller (a stale client mid-rolling-deploy sending the old 5-arg shape)
-- fails loudly with PGRST202 (function-not-found) instead of clearing the marker. Our client always
-- sends it (tasks_repository.dart update()), so this costs nothing. create_task keeps its default:
-- a create has nothing to reset.
create or replace function public.update_task(
  p_id         uuid,
  p_title      text,
  p_is_done    boolean,
  p_notes      text,
  p_contacts   uuid[],
  p_importance smallint
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- One update path for the form save AND the list/detail complete-toggle (which re-sends the
  -- unchanged title + notes + People + importance with a flipped is_done). Guarded to live rows —
  -- the UI only edits/toggles live tasks (archived tiles offer Restore, not Edit/complete). notes
  -- are normalized like create; importance is range-checked by the column check.
  update public.tasks set
    title      = trim(p_title),
    is_done    = p_is_done,
    notes      = nullif(trim(p_notes), ''),
    importance = p_importance
  where id = p_id
    and deleted_at is null;

  -- Bail (rolling back the whole call) if the id is unknown or already archived — otherwise we'd
  -- silently rewrite a hidden task's People set and return success.
  if not found then
    raise exception 'task % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  -- Replace the People set. Hard-DELETE of join rows is the annotated exception to
  -- "soft-delete by default" (database.md #4): membership is derived, not a soft-deletable
  -- entity with its own history. Mirrors update_event / the prior update_task.
  delete from public.task_contacts where task_id = p_id;

  insert into public.task_contacts (task_id, contact_id)
  select p_id, c from unnest(p_contacts) as c
  on conflict do nothing;

  return p_id;
end;
$$;

-- Re-lock the NEW signatures (the drops above discarded the old functions' ACLs). Both are needed:
-- the PUBLIC revoke re-asserts the Decision 36 lockdown that the recreate reset; the anon/
-- authenticated grant keeps the app working.
revoke execute on function public.create_task(text, text, uuid[], smallint)                from public;
revoke execute on function public.update_task(uuid, text, boolean, text, uuid[], smallint) from public;

grant execute on function public.create_task(text, text, uuid[], smallint)                to anon, authenticated;
grant execute on function public.update_task(uuid, text, boolean, text, uuid[], smallint) to anon, authenticated;
