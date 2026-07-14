-- 20260714120000_add_notes_to_tasks.sql
-- Add a single optional freeform `notes` field to tasks (Decision 27 follow-on). Forward-only;
-- never edit after it has run somewhere — add a new migration instead. Conventions: docs/database.md.
--
-- `notes` is ONE editable field on the task itself (a description) — distinct from the separate
-- task-comments log slice that follows. Optional: NULL = no notes. Blank input is normalized to
-- NULL server-side (nullif(trim(...), '')), so an empty box never stores '' .
--
-- Writes stay on the RPC path (Decision 26): create_task / update_task now also carry p_notes.
-- Adding a parameter changes a function's signature (identity), so create-or-replace alone would
-- leave a second overload and make PostgREST calls ambiguous (PGRST203) — hence the
-- `drop function if exists <OLD signature>` before each `create or replace`, per the project's
-- signature-change convention (docs/database.md; same pattern the event write RPCs use). Each
-- recreated body is the prior body VERBATIM (security definer, set search_path, the trim, the
-- `deleted_at is null` guard, the not-found raise) plus the notes handling — nothing else changes.
-- Grants are re-issued because dropping the old signatures dropped their grants.
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred, issue #3. Same posture as siblings.)

alter table public.tasks
  add column notes text;                 -- optional freeform description; NULL = none.

-- create (title + optional notes) — replaces create_task(text) -----------------
drop function if exists public.create_task(text);

create or replace function public.create_task(
  p_title text,
  p_notes text default null
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

  return v_id;
end;
$$;

-- update (title + done + notes, in one) — replaces update_task(uuid, text, boolean) ----------
drop function if exists public.update_task(uuid, text, boolean);

create or replace function public.update_task(
  p_id      uuid,
  p_title   text,
  p_is_done boolean,
  p_notes   text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- One update path for the form save AND the list/detail complete-toggle (which re-sends the
  -- unchanged title + notes with a flipped is_done). Guarded to live rows — the UI only
  -- edits/toggles live tasks (archived tiles offer Restore, not Edit/complete). notes are
  -- normalized like create: blank/whitespace clears to NULL.
  update public.tasks set
    title   = trim(p_title),
    is_done = p_is_done,
    notes   = nullif(trim(p_notes), '')
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'task % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- Re-grant on the NEW signatures (the drops above revoked the old ones). soft_delete_task /
-- restore_task are untouched by this migration, so their grants still stand.
grant execute on function public.create_task(text, text)                to anon, authenticated;
grant execute on function public.update_task(uuid, text, boolean, text) to anon, authenticated;
