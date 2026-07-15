-- 20260714140000_create_task_comments.sql
-- Comments on a task — an archivable log, the task-side twin of event_comments (Decision 32 /
-- Slice 2b). Forward-only; never edit after it has run somewhere — add a new migration instead.
-- Conventions: docs/database.md.
--
-- Modeled exactly on event_comments (20260711120000) + comment_write_rpcs (20260712150000),
-- but delivered as ONE migration (table + write RPCs together) since this table is new — there is
-- no direct-write history to convert (event_comments predated Decision 26 and was migrated in two
-- steps; task_comments is born on the RPC path).
--
-- The one deliberate divergence from most tables is a READ policy that also applies here: the
-- SELECT policy is `using (true)`, NOT `using (deleted_at is null)`. Archived
-- (deleted_at IS NOT NULL) comments stay READABLE — that is the feature ("see archived comments").
-- That `using (true)` also means an archived row survives PostgREST's RETURNING re-check, so — as
-- with event_comments — the write RPCs below exist for UNIFORMITY with Decision 26 (one write path
-- per entity = one future home for the auth.uid() owner check), NOT to dodge a 42501: a direct
-- write would have worked here too.
--
-- The direct insert/update GRANTs and the insert/update RLS policies are intentionally in place;
-- closing the direct write path (revoke + drop policies) is auth hardening, tracked under issue #3
-- — same posture as contacts / event_types / event_comments.
-- SUPERSEDED 2026-07-15 by 20260715120000_preauth_lockdown.sql (Decision 36): the direct write path
-- is now CLOSED, PUBLIC execute revoked, AND the archived-task guard below is now IMPLEMENTED (the
-- four RPCs guard the parent task's deleted_at). (Executable SQL in THIS migration is unchanged.)
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred. Add them with the auth slice, #3.)
--
-- DEFERRED TO #3 (server-side archived-task enforcement) — ✅ NOW IMPLEMENTED by
-- 20260715120000_preauth_lockdown.sql (Decision 36); the paragraph below is the original deferral
-- rationale, kept for history (see the SUPERSEDED note above): these RPCs guard only the COMMENT's
-- deleted_at, not the parent TASK's — so a direct API caller could still mutate comments on an
-- archived task (which the UI presents as a frozen, read-only log via CommentsSection.readOnly).
-- The client fully enforces frozen-history today; making the server enforce it (add `tasks.deleted_at
-- is null` to all four RPCs) is bundled into the #3 hardening slice ALONGSIDE closing the direct
-- write path above — doing only one half while the direct path stays open is not a real boundary
-- pre-auth. Deliberately kept a faithful event_comments twin until then. (Unlike a soft-deleted
-- event, which is unreachable in the UI, an archived task IS viewable — so this guard genuinely
-- matters once the write path is locked down.)

create table public.task_comments (
  id          uuid        primary key default gen_random_uuid(),
  -- RESTRICT, not CASCADE: comments are retained content (history). Tasks are soft-deleted only,
  -- so this never fires today — but if a hard-delete of tasks is ever added, RESTRICT blocks it
  -- rather than silently erasing archived comment history. (Mirrors event_comments.event_id.)
  task_id     uuid        not null references public.tasks(id) on delete restrict,
  body        text        not null check (length(trim(body)) > 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz                        -- archive marker; NULL = live. NOT hidden by RLS.
);

-- Comments are always queried by their task, so index the FK.
create index task_comments_task_id_idx on public.task_comments (task_id);

-- keep updated_at honest on every mutation (reuse the shared fn from the contacts migration)
create trigger task_comments_set_updated_at
  before update on public.task_comments
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.task_comments enable row level security;

-- using (true), NOT (deleted_at is null): archived comments must stay readable so the app can
-- show them under a "Show archived" toggle (and so archive survives the RETURNING re-check).
create policy task_comments_select on public.task_comments
  for select to anon, authenticated
  using (true);

create policy task_comments_insert on public.task_comments
  for insert to anon, authenticated
  with check (true);

-- One update policy covers edit (body), archive (set deleted_at) AND unarchive (clear it).
-- using (true), NOT (deleted_at is null): an already-archived row must be targetable to restore it.
create policy task_comments_update on public.task_comments
  for update to anon, authenticated
  using (true)
  with check (true);

-- No DELETE policy on purpose: soft-delete (archive) only. Hard DELETE stays unavailable to
-- clients (database.md #4).
grant select, insert, update on public.task_comments to anon, authenticated;

-- write RPCs (Decision 26: all writes go through RPCs; reads stay direct) --------------------
-- SECURITY DEFINER + SET search_path = public, exactly like the event-comment RPCs.

-- create -------------------------------------------------------------------
create or replace function public.create_task_comment(
  p_task_id uuid,
  p_body    text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  -- trim(p_body) drives the table's check (length(trim(body)) > 0): a blank body raises a
  -- check violation. The task_id FK (on delete restrict) fires if p_task_id is unknown.
  insert into public.task_comments (task_id, body)
  values (p_task_id, trim(p_body))
  returning id into v_id;

  return v_id;
end;
$$;

-- update (body only — an edit can never move a comment to another task) ------
create or replace function public.update_task_comment(
  p_id   uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- No p_task_id param: an edit changes the body and nothing else. Guarded to live rows —
  -- the UI only edits live comments (archived tiles offer Unarchive, not Edit).
  update public.task_comments set
    body = trim(p_body)
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'task comment % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- archive (soft-delete) ----------------------------------------------------
create or replace function public.soft_delete_task_comment(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.task_comments set
    deleted_at = now()
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'task comment % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- restore (unarchive) — the inverse of soft_delete ------------------------
create or replace function public.restore_task_comment(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.task_comments set
    deleted_at = null
  where id = p_id
    and deleted_at is not null;

  if not found then
    raise exception 'task comment % not found or not archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

grant execute on function public.create_task_comment(uuid, text)   to anon, authenticated;
grant execute on function public.update_task_comment(uuid, text)   to anon, authenticated;
grant execute on function public.soft_delete_task_comment(uuid)    to anon, authenticated;
grant execute on function public.restore_task_comment(uuid)        to anon, authenticated;
