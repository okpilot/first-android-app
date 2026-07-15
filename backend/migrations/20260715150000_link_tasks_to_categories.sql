-- 20260715150000_link_tasks_to_categories.sql
-- Link tasks ↔ task_categories, many-to-many. Decision 40, Slice B.
-- Forward-only; never edit the executable SQL after it has run somewhere — add a new migration.
-- Conventions: docs/database.md.
--
-- Slice A (20260715140000_create_task_categories.sql) stood up the task_categories entity + its
-- manager UI, but no task referenced a category. This closes the loop: a task carries MANY
-- categories via a join table, chosen on the task form. The whole thing mirrors the task↔People
-- link (task_contacts + p_contacts threaded through the task-write RPCs) — a proven pattern.
--
-- Adding p_categories changes each task-write RPC's signature (identity), so create-or-replace alone
-- would leave the old overload and make PostgREST calls ambiguous (PGRST203) — hence the
-- `drop function if exists <OLD signature>` before each `create or replace`, per the project's
-- signature-change convention (docs/database.md; same pattern add_importance_to_tasks.sql used). Each
-- recreated body is the prior body VERBATIM (security definer, set search_path, trim, nullif-notes,
-- the `deleted_at is null` guard, the not-found raise, the People delete+reinsert, the importance
-- column) PLUS the category link block — nothing else changes.
--
-- LOCKDOWN INVARIANT (Decision 36): dropping the old functions discards the `revoke execute … from
-- public` that the lockdown put on them, and the recreated functions get Postgres's DEFAULT PUBLIC
-- execute back. So this migration MUST re-issue BOTH the PUBLIC revoke AND the anon/authenticated
-- grant on the NEW signatures — otherwise the RPCs silently reopen to PUBLIC (docs/database.md rule
-- #2). soft_delete_task / restore_task are untouched → their ACLs stand; they don't touch the link
-- table either, so an archived task keeps its category links (parity with task_contacts).
--
-- (No auth.uid() ownership checks: there is NO auth — single-user + tailnet-only, login is WON'T-DO,
-- Decision 37. Same posture as every sibling RPC.)

-- Join table ---------------------------------------------------------------
-- A verbatim mirror of task_contacts (20260714160000_add_contacts_to_tasks.sql): the composite
-- PK IS the uniqueness constraint (no surrogate id / timestamps / deleted_at — membership is
-- derived, not a soft-deletable entity with its own history). Both FKs `on delete cascade`.
create table public.task_category_links (
  task_id     uuid not null references public.tasks(id)           on delete cascade,
  category_id uuid not null references public.task_categories(id) on delete cascade,
  primary key (task_id, category_id)
);

-- The PK already indexes the (task_id, …) direction (task -> categories). Add the reverse so
-- "which tasks have this category?" doesn't scan.
create index task_category_links_category_id_idx on public.task_category_links(category_id);

alter table public.task_category_links enable row level security;

-- SELECT policy is `using (true)`, NOT a parent-live gate: tasks.tasks_select is also `using (true)`
-- so archived tasks stay embeddable, and their category roster must come along (same as task_contacts).
-- A soft-deleted CATEGORY is hidden by task_categories' own `using (deleted_at is null)` policy, so
-- the embedded to-one object comes back null and the client skips it (Task.fromJson).
create policy task_category_links_select on public.task_category_links
  for select to anon, authenticated
  using (true);

-- No write policy/grant: membership is set only by the SECURITY DEFINER RPCs below.
grant select on public.task_category_links to anon, authenticated;

-- create (title + notes + People + importance + categories) —
--   replaces create_task(text, text, uuid[], smallint) --------------------------------------------
drop function if exists public.create_task(text, text, uuid[], smallint);

create or replace function public.create_task(
  p_title      text,
  p_notes      text     default null,
  p_contacts   uuid[]   default '{}',
  p_importance smallint default 0,
  p_categories uuid[]   default '{}'
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

  -- Categories — the identical unnest-insert against the link table (same safety: no-op on empty,
  -- dedupe on the composite PK). A bad category id would raise a FK violation and roll the call back.
  insert into public.task_category_links (task_id, category_id)
  select v_id, c from unnest(p_categories) as c
  on conflict do nothing;

  return v_id;
end;
$$;

-- update (title + done + notes + People + importance + categories) —
--   replaces update_task(uuid, text, boolean, text, uuid[], smallint) ------------------------------
drop function if exists public.update_task(uuid, text, boolean, text, uuid[], smallint);

-- p_categories is REQUIRED here (no default) — same defensive rule as p_contacts / p_importance: an
-- update re-sends the whole task, so an omitted arg would silently WIPE the category set. Without a
-- default, a mismatched caller (a stale client mid-rolling-deploy sending the old 6-arg shape) fails
-- loudly with PGRST202 (function-not-found) instead of clearing the links. Our client always sends it
-- (tasks_repository.dart update()), so this costs nothing. create_task keeps its default: a create
-- has nothing to wipe.
create or replace function public.update_task(
  p_id         uuid,
  p_title      text,
  p_is_done    boolean,
  p_notes      text,
  p_contacts   uuid[],
  p_importance smallint,
  p_categories uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- One update path for the form save AND the list/detail complete-toggle (which re-sends the
  -- unchanged title + notes + People + importance + categories with a flipped is_done). Guarded to
  -- live rows — the UI only edits/toggles live tasks (archived tiles offer Restore, not
  -- Edit/complete). notes are normalized like create; importance is range-checked by the column check.
  update public.tasks set
    title      = trim(p_title),
    is_done    = p_is_done,
    notes      = nullif(trim(p_notes), ''),
    importance = p_importance
  where id = p_id
    and deleted_at is null;

  -- Bail (rolling back the whole call) if the id is unknown or already archived — otherwise we'd
  -- silently rewrite a hidden task's People/category sets and return success.
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

  -- Replace the category set — the identical delete-then-reinsert against the link table (same
  -- derived-membership rationale as the People set above).
  delete from public.task_category_links where task_id = p_id;

  insert into public.task_category_links (task_id, category_id)
  select p_id, c from unnest(p_categories) as c
  on conflict do nothing;

  return p_id;
end;
$$;

-- Re-lock the NEW signatures (the drops above discarded the old functions' ACLs). Both are needed:
-- the PUBLIC revoke re-asserts the Decision 36 lockdown that the recreate reset; the anon/
-- authenticated grant keeps the app working.
revoke execute on function public.create_task(text, text, uuid[], smallint, uuid[])                from public;
revoke execute on function public.update_task(uuid, text, boolean, text, uuid[], smallint, uuid[]) from public;

grant execute on function public.create_task(text, text, uuid[], smallint, uuid[])                to anon, authenticated;
grant execute on function public.update_task(uuid, text, boolean, text, uuid[], smallint, uuid[]) to anon, authenticated;
