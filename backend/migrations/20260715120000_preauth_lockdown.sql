-- 20260715120000_preauth_lockdown.sql
-- Pre-auth DB lockdown — the auth-INDEPENDENT subset of issue #3. Decision 36.
-- Forward-only; never edit the executable SQL after it has run somewhere — add a new migration.
-- Conventions: docs/database.md.
--
-- This migration CLOSES the "direct write path open / PUBLIC-execute deferred to #3" posture that
-- the sibling table + RPC migrations deliberately LEFT IN PLACE (contact_write_rpcs,
-- event_type_write_rpcs, comment_write_rpcs, create_tasks, create_task_comments — each says
-- "closing the direct write path is auth hardening, tracked under #3"). It does three things, all
-- BEHAVIOR-PRESERVING (the app already writes exclusively via the RPCs and reads direct — verified):
--
--   1. Close the direct anon write path on the 5 still-open mutable tables — revoke the direct
--      insert/update grants + drop the direct write RLS policies, so the SECURITY DEFINER RPCs are
--      the SOLE mutation interface (matching events/event_attendees, which were SELECT-only from
--      day one). Reads stay direct-under-RLS: the `grant select` + SELECT policies are untouched.
--      Safe because the RPCs run as the table owner, which bypasses RLS (no table has FORCE ROW
--      LEVEL SECURITY) and holds full table privileges independent of anon's grants.
--   2. Revoke EXECUTE from PUBLIC on every client-facing SECURITY DEFINER RPC (Postgres grants it by
--      default). The explicit `grant execute … to anon, authenticated` on each persists, so the app
--      keeps working; PUBLIC (any future/other role) loses the implicit execute.
--   3. Add the deferred server-side archived-task guard to the 4 task_comment RPCs: they now require
--      the PARENT task to be live, closing the hole where a raw anon caller could mutate the log of a
--      task the UI presents as a frozen, read-only history (CommentsSection.readOnly).
--
-- STILL DEFERRED to #3 (need GoTrue / a convention slice, NOT closed here):
--   • auth.uid() ownership checks + owner-based RLS (no user identity until GoTrue is wired).
--   • SET search_path = '' + schema-qualify hardening (a separate follow-up slice — it rewrites
--     every RPC body and ripples the convention across docs; kept out to keep this slice behavior-
--     preserving and reviewable).

-- 1. Close the direct anon write path (RPC becomes the sole write path) ---------------------------
-- Leave `grant select` + the SELECT policies in place; only the write door closes.

revoke insert, update on public.contacts       from anon, authenticated;
drop policy if exists contacts_insert       on public.contacts;
drop policy if exists contacts_update       on public.contacts;

revoke insert, update on public.event_types    from anon, authenticated;
drop policy if exists event_types_insert    on public.event_types;
drop policy if exists event_types_update    on public.event_types;

revoke insert, update on public.event_comments from anon, authenticated;
drop policy if exists event_comments_insert on public.event_comments;
drop policy if exists event_comments_update on public.event_comments;

revoke insert, update on public.tasks          from anon, authenticated;
drop policy if exists tasks_insert          on public.tasks;
drop policy if exists tasks_update          on public.tasks;

revoke insert, update on public.task_comments  from anon, authenticated;
drop policy if exists task_comments_insert  on public.task_comments;
drop policy if exists task_comments_update  on public.task_comments;

-- 2. Revoke EXECUTE from PUBLIC on every client-facing SECURITY DEFINER RPC ------------------------
-- Signatures are each function's latest/only overload (the drop+recreate chain drops old ones).
-- The `grant execute … to anon, authenticated` on each stays, so the app is unaffected.
-- (pgrst_watch() is intentionally omitted — it is not SECURITY DEFINER and not client-facing.)

revoke execute on function public.soft_delete_contact(uuid)                                             from public;
revoke execute on function public.create_contact(text, date, text, text, text, text)                    from public;
revoke execute on function public.update_contact(uuid, text, date, text, text, text, text)              from public;
revoke execute on function public.soft_delete_event(uuid)                                               from public;
revoke execute on function public.create_event(text, date, boolean, time, time, text, text, uuid[], uuid)        from public;
revoke execute on function public.update_event(uuid, text, date, boolean, time, time, text, text, uuid[], uuid)  from public;
revoke execute on function public.soft_delete_event_type(uuid)                                          from public;
revoke execute on function public.create_event_type(text, text)                                         from public;
revoke execute on function public.update_event_type(uuid, text, text)                                   from public;
revoke execute on function public.create_comment(uuid, text)                                            from public;
revoke execute on function public.update_comment(uuid, text)                                            from public;
revoke execute on function public.soft_delete_comment(uuid)                                             from public;
revoke execute on function public.restore_comment(uuid)                                                 from public;
revoke execute on function public.create_task(text, text, uuid[])                                       from public;
revoke execute on function public.update_task(uuid, text, boolean, text, uuid[])                        from public;
revoke execute on function public.soft_delete_task(uuid)                                                from public;
revoke execute on function public.restore_task(uuid)                                                    from public;
revoke execute on function public.create_task_comment(uuid, text)                                       from public;
revoke execute on function public.update_task_comment(uuid, text)                                       from public;
revoke execute on function public.soft_delete_task_comment(uuid)                                        from public;
revoke execute on function public.restore_task_comment(uuid)                                            from public;

-- 3. task_comments archived-task guard (the #3-deferred server-side enforcement) ------------------
-- Each body below is the prior body VERBATIM (create_task_comments migration :84-175) PLUS a
-- parent-task-live guard. `create or replace` (no drop) preserves the ACL, so the PUBLIC revoke in
-- part 2 survives. The guard matches the UI contract (archived tasks are read-only), so no app flow
-- breaks; it only rejects a raw anon caller mutating a frozen task's log.

-- create: reject an unknown OR soft-deleted parent. The FK (on delete restrict) already catches an
-- unknown id, but not a still-present soft-deleted one — hence the explicit exists() pre-check.
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
  -- Fold the parent-task-live check INTO the insert (one statement) so it can't race with a
  -- concurrent soft_delete_task(p_task_id) — matching the UPDATE-based sibling RPCs, which AND the
  -- same exists() into their WHERE. The FK (on delete restrict) still catches an unknown id; the
  -- exists() adds the archived-but-present case. trim(p_body) drives the table's
  -- check (length(trim(body)) > 0): a blank body on a LIVE task still raises a check violation.
  insert into public.task_comments (task_id, body)
  select p_task_id, trim(p_body)
  where exists (
    select 1 from public.tasks where id = p_task_id and deleted_at is null
  )
  returning id into v_id;

  if not found then
    raise exception 'task % not found or archived', p_task_id
      using errcode = 'no_data_found';
  end if;

  return v_id;
end;
$$;

-- update (body only): live comment AND live parent task.
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
  update public.task_comments set
    body = trim(p_body)
  where id = p_id
    and deleted_at is null
    and exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id and t.deleted_at is null
    );

  if not found then
    raise exception 'task comment % not found, already archived, or on an archived task', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- archive (soft-delete): live comment AND live parent task.
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
    and deleted_at is null
    and exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id and t.deleted_at is null
    );

  if not found then
    raise exception 'task comment % not found, already archived, or on an archived task', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- restore (unarchive): archived comment AND live parent task.
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
    and deleted_at is not null
    and exists (
      select 1 from public.tasks t
      where t.id = task_comments.task_id and t.deleted_at is null
    );

  if not found then
    raise exception 'task comment % not found, not archived, or on an archived task', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;
