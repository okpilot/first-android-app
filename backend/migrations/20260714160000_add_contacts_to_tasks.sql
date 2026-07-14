-- 20260714160000_add_contacts_to_tasks.sql
-- Link contacts to tasks ("People on a task") via a many-to-many join, mirroring event_attendees.
-- Forward-only; never edit after it has run somewhere — add a new migration instead.
-- Conventions: docs/database.md.
--
-- A task and its People are a multi-table write, so per database.md #1/#2 membership is managed
-- ONLY by the task-write RPCs (create_task / update_task) — a single SECURITY DEFINER function
-- (atomic rollback on failure), never multi-step client calls. So anon gets SELECT only, which
-- powers the embedded read:
--   tasks?select=...,task_contacts(contact_id, contacts(id,name,company))
--
-- Adding p_contacts changes each RPC's signature (identity), so create-or-replace alone would
-- leave the old overload and make PostgREST calls ambiguous (PGRST203) — hence the
-- `drop function if exists <OLD signature>` before each `create or replace`, per the project's
-- signature-change convention (docs/database.md; same pattern the event write RPCs and the
-- add_notes migration use). Each recreated body is the prior body VERBATIM (security definer,
-- set search_path, trim, the `deleted_at is null` guard, the not-found raise) PLUS the People
-- handling — nothing else changes. Grants are re-issued because dropping the old signatures
-- dropped their grants.
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred, issue #3. Same posture as siblings.)

-- Join table ---------------------------------------------------------------
create table public.task_contacts (
  task_id    uuid not null references public.tasks(id)    on delete cascade,
  contact_id uuid not null references public.contacts(id) on delete cascade,
  primary key (task_id, contact_id)
);

-- The PK already indexes the (task_id, …) direction (task -> People). Add the reverse so
-- "which tasks is this contact on?" doesn't scan.
create index task_contacts_contact_id_idx on public.task_contacts(contact_id);

alter table public.task_contacts enable row level security;

-- SELECT policy is `using (true)`, NOT the parent-live EXISTS gate event_attendees uses
-- (20260709120100_create_event_attendees.sql:30-38). Deliberate divergence: the `tasks` table's
-- own SELECT policy is `using (true)` (archived tasks stay readable — the "view archived"
-- feature, create_tasks.sql:42-44), so an archived task's People must stay embeddable too. A
-- parent-live gate here would hide the roster on an archived task's read-only detail. This is a
-- parent-gate difference, NOT a database.md #4 viewable-soft-delete case: task_contacts has no
-- deleted_at and isn't self-soft-deletable, so it does NOT belong on #4's exception list.
create policy task_contacts_select on public.task_contacts
  for select to anon, authenticated
  using (true);

-- No write policy/grant: membership is set only by the SECURITY DEFINER RPCs below.
grant select on public.task_contacts to anon, authenticated;

-- create (title + notes + People) — replaces create_task(text, text) ---------
drop function if exists public.create_task(text, text);

create or replace function public.create_task(
  p_title    text,
  p_notes    text  default null,
  p_contacts uuid[] default '{}'
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
  -- New tasks are always live and not-done (is_done defaults false).
  insert into public.tasks (title, notes)
  values (trim(p_title), nullif(trim(p_notes), ''))
  returning id into v_id;

  -- unnest(NULL) and unnest('{}') both yield zero rows, so this is a safe no-op when there are
  -- no People. on conflict do nothing dedupes repeated ids against the composite PK.
  insert into public.task_contacts (task_id, contact_id)
  select v_id, c from unnest(p_contacts) as c
  on conflict do nothing;

  return v_id;
end;
$$;

-- update (title + done + notes + People) — replaces update_task(uuid, text, boolean, text) -------
drop function if exists public.update_task(uuid, text, boolean, text);

-- p_contacts is REQUIRED here (no default) — unlike create_task, an update replaces the whole
-- People set, so an omitted arg would silently WIPE every link. Without a default, a mismatched
-- caller (a stale client mid-rolling-deploy sending the old 4-arg shape) fails loudly with
-- PGRST202 (function-not-found) instead of clearing People. Our client always sends it
-- (tasks_repository.dart update()), so this costs nothing. create_task keeps its default: a create
-- has nothing to wipe.
create or replace function public.update_task(
  p_id       uuid,
  p_title    text,
  p_is_done  boolean,
  p_notes    text,
  p_contacts uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- One update path for the form save AND the list/detail complete-toggle (which re-sends the
  -- unchanged title + notes + People with a flipped is_done). Guarded to live rows — the UI only
  -- edits/toggles live tasks (archived tiles offer Restore, not Edit/complete). notes are
  -- normalized like create: blank/whitespace clears to NULL.
  update public.tasks set
    title   = trim(p_title),
    is_done = p_is_done,
    notes   = nullif(trim(p_notes), '')
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
  -- entity with its own history. Mirrors update_event (20260709120200:88-95).
  delete from public.task_contacts where task_id = p_id;

  insert into public.task_contacts (task_id, contact_id)
  select p_id, c from unnest(p_contacts) as c
  on conflict do nothing;

  return p_id;
end;
$$;

-- Re-grant on the NEW signatures (the drops above revoked the old ones). soft_delete_task /
-- restore_task are untouched by this migration, so their grants still stand.
grant execute on function public.create_task(text, text, uuid[])                to anon, authenticated;
grant execute on function public.update_task(uuid, text, boolean, text, uuid[]) to anon, authenticated;
