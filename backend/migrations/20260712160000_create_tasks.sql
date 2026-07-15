-- 20260712160000_create_tasks.sql
-- Tasks (v0): a lightweight to-do list. Forward-only; never edit after it has run somewhere —
-- add a new migration instead. Conventions: docs/database.md.
--
-- Full CRUD from day one (Decision 27): add / complete / edit / archive / restore, plus VIEW of
-- completed AND archived. Writes go through SECURITY DEFINER RPCs (Decision 26 — universal); reads
-- stay direct. No per-user auth yet (GoTrue deferred, issue #3), so policies grant the anon role.
--
-- The one deliberate divergence — the SAME one event_comments makes — is a READ policy: the SELECT
-- policy is `using (true)`, NOT `using (deleted_at is null)`. Archived (deleted_at IS NOT NULL) tasks
-- stay READABLE — that is the "view archived" feature. NOTE: that `using (true)` also means an
-- archived row survives PostgREST's RETURNING re-check, so the write RPCs below are for UNIFORMITY
-- with Decision 26 (one write path per entity = one future home for the auth.uid() owner check),
-- NOT to dodge a 42501 (unlike soft_delete_contact / soft_delete_event_type, which genuinely need
-- SECURITY DEFINER) — a direct write would have worked here. This makes `tasks` the SECOND
-- viewable-soft-delete table alongside event_comments (docs/database.md #4).
--
-- The direct insert/update GRANTs and the tasks_insert/tasks_update RLS policies are intentionally
-- LEFT IN PLACE: closing the direct write path (revoke + drop policies) is auth hardening, tracked
-- under issue #3 — same posture as contacts / event_types / event_comments.
-- SUPERSEDED 2026-07-15 by 20260715120000_preauth_lockdown.sql (Decision 36): that direct write
-- path is now CLOSED and PUBLIC execute revoked on these RPCs. (Executable SQL here unchanged.)

create table public.tasks (
  id          uuid        primary key default gen_random_uuid(),
  title       text        not null check (length(trim(title)) > 0),
  is_done     boolean     not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz                        -- archive marker; NULL = live. NOT hidden by RLS.
);

-- keep updated_at honest on every mutation (reuse the shared fn from the contacts migration)
create trigger tasks_set_updated_at
  before update on public.tasks
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.tasks enable row level security;

-- using (true), NOT (deleted_at is null): archived tasks must stay readable so the app can show
-- them under a "Show archived" section (and so archive survives the RETURNING re-check).
create policy tasks_select on public.tasks
  for select to anon, authenticated
  using (true);

create policy tasks_insert on public.tasks
  for insert to anon, authenticated
  with check (true);

-- One update policy covers edit (title), complete (set is_done), archive (set deleted_at) AND
-- restore (clear it). using (true), NOT (deleted_at is null): an already-archived row must be
-- targetable to restore it.
create policy tasks_update on public.tasks
  for update to anon, authenticated
  using (true)
  with check (true);

-- No DELETE policy on purpose: soft-delete (archive) only. Hard DELETE stays unavailable to
-- clients (database.md #4).
grant select, insert, update on public.tasks to anon, authenticated;

-- Write RPCs (Decision 26). SECURITY DEFINER for UNIFORMITY here, not necessity (see header). ------

-- create -------------------------------------------------------------------
create or replace function public.create_task(p_title text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  -- trim(p_title) drives the table's check (length(trim(title)) > 0): a blank title raises a
  -- check violation. New tasks are always live and not-done (is_done defaults false).
  insert into public.tasks (title)
  values (trim(p_title))
  returning id into v_id;

  return v_id;
end;
$$;

-- update (title + done, in one) --------------------------------------------
create or replace function public.update_task(
  p_id      uuid,
  p_title   text,
  p_is_done boolean
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- One update path for both the form save AND the list complete-toggle (which re-sends the
  -- unchanged title with a flipped is_done). Guarded to live rows — the UI only edits/toggles
  -- live tasks (archived tiles offer Restore, not Edit/complete).
  update public.tasks set
    title   = trim(p_title),
    is_done = p_is_done
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'task % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- archive (soft-delete) ----------------------------------------------------
create or replace function public.soft_delete_task(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.tasks set
    deleted_at = now()
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'task % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- restore (unarchive) — the inverse of soft_delete ------------------------
create or replace function public.restore_task(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.tasks set
    deleted_at = null
  where id = p_id
    and deleted_at is not null;

  if not found then
    raise exception 'task % not found or not archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

grant execute on function public.create_task(text)               to anon, authenticated;
grant execute on function public.update_task(uuid, text, boolean) to anon, authenticated;
grant execute on function public.soft_delete_task(uuid)          to anon, authenticated;
grant execute on function public.restore_task(uuid)              to anon, authenticated;
