-- 20260712150000_comment_write_rpcs.sql
-- Standardize the event_comments write path onto RPCs (Decision 26: all writes go through RPCs;
-- reads stay direct). This is the LAST slice of the migration — contacts (Slice 1) and
-- event_types (Slice 2) already converted; comments were the final direct-write table.
--
-- IMPORTANT — why SECURITY DEFINER here is UNLIKE the other soft-delete RPCs:
-- event_comments' SELECT policy is `using (true)` (archived rows stay readable — the "show
-- archived" feature), so a direct UPDATE of `deleted_at` does NOT fail PostgREST's RETURNING
-- re-check (no 42501). A direct write would have worked fine. These RPCs exist purely for
-- UNIFORMITY with the rest of Decision 26 (one write path per entity = one future home for the
-- auth.uid() owner check), NOT to dodge a re-check. This reverses Decision 23's "no soft-delete
-- RPC needed" / database.md rule #4's "plain direct UPDATEs" for comments — the `using (true)`
-- archived-readable SELECT policy itself is unchanged and remains the documented exception.
--
-- The direct insert/update GRANTs and the event_comments_insert/event_comments_update RLS
-- policies are intentionally LEFT IN PLACE: closing the direct write path (revoke + drop
-- policies) is auth hardening, tracked under issue #3 — same posture as contacts / event_types.
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred. Add them with the auth slice, #3.)

-- create -------------------------------------------------------------------
create or replace function public.create_comment(
  p_event_id uuid,
  p_body     text
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
  -- check violation. The event_id FK (on delete restrict) fires if p_event_id is unknown.
  insert into public.event_comments (event_id, body)
  values (p_event_id, trim(p_body))
  returning id into v_id;

  return v_id;
end;
$$;

-- update (body only — an edit can never move a comment to another event) -----
create or replace function public.update_comment(
  p_id   uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  -- No p_event_id param: an edit changes the body and nothing else. Guarded to live rows —
  -- the UI only edits live comments (archived tiles offer Unarchive, not Edit).
  update public.event_comments set
    body = trim(p_body)
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'comment % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- archive (soft-delete) ----------------------------------------------------
create or replace function public.soft_delete_comment(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_comments set
    deleted_at = now()
  where id = p_id
    and deleted_at is null;

  if not found then
    raise exception 'comment % not found or already archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- restore (unarchive) — the inverse of soft_delete; new to Decision 26 -------
create or replace function public.restore_comment(p_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_comments set
    deleted_at = null
  where id = p_id
    and deleted_at is not null;

  if not found then
    raise exception 'comment % not found or not archived', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

grant execute on function public.create_comment(uuid, text)   to anon, authenticated;
grant execute on function public.update_comment(uuid, text)   to anon, authenticated;
grant execute on function public.soft_delete_comment(uuid)    to anon, authenticated;
grant execute on function public.restore_comment(uuid)        to anon, authenticated;
