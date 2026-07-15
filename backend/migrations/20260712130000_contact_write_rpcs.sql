-- 20260712130000_contact_write_rpcs.sql
-- Standardize the contacts write path onto RPCs (Decision 26: all writes go through RPCs;
-- reads stay direct). Contacts previously wrote direct (INSERT/UPDATE under RLS) with only
-- the soft-delete routed through soft_delete_contact. This adds create_contact / update_contact
-- so the whole entity writes through one place — matching the event RPCs (the template) and
-- giving auth (issue #3) a single spot per entity to add auth.uid() owner checks.
--
-- SECURITY DEFINER here is for UNIFORMITY + that future auth payoff, NOT to dodge the RLS
-- RETURNING re-check (42501): create/update touch only non-delete fields, so deleted_at stays
-- null and the new row still passes contacts_select — a direct write would have worked too.
-- (Contrast soft_delete_contact, which genuinely needs SECURITY DEFINER to set deleted_at.)
--
-- The direct insert/update GRANTs and the contacts_insert/contacts_update RLS policies are
-- intentionally LEFT IN PLACE: closing the direct write path (revoke + drop policies) is auth
-- hardening, tracked under issue #3 — same posture as soft_delete_contact, which didn't revoke.
-- SUPERSEDED 2026-07-15 by 20260715120000_preauth_lockdown.sql (Decision 36): that direct write
-- path is now CLOSED and PUBLIC execute revoked on these RPCs. (Historical note — this migration's
-- executable SQL is unchanged, per forward-only.)
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred. Add them with the auth slice, #3.)

-- create -------------------------------------------------------------------
create or replace function public.create_contact(
  p_name    text,
  p_dob     date,
  p_email   text,
  p_phone   text,
  p_company text,
  p_remarks text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  -- Empty→null normalization lives here (server-side), matching the event template, so it's
  -- in one place. trim(p_name) also drives the table's check (length(trim(name)) > 0): a blank
  -- name raises a check violation, exactly as the old direct write relied on.
  insert into public.contacts (name, dob, email, phone, company, remarks)
  values (
    trim(p_name),
    p_dob,
    nullif(trim(p_email), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_company), ''),
    nullif(trim(p_remarks), '')
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- update -------------------------------------------------------------------
create or replace function public.update_contact(
  p_id      uuid,
  p_name    text,
  p_dob     date,
  p_email   text,
  p_phone   text,
  p_company text,
  p_remarks text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.contacts set
    name    = trim(p_name),
    dob     = p_dob,
    email   = nullif(trim(p_email), ''),
    phone   = nullif(trim(p_phone), ''),
    company = nullif(trim(p_company), ''),
    remarks = nullif(trim(p_remarks), '')
  where id = p_id
    and deleted_at is null;

  -- Bail (rolling back the call) if the id is unknown or already soft-deleted — otherwise we'd
  -- silently succeed on a hidden/absent row and return an id that wasn't actually updated.
  if not found then
    raise exception 'contact % not found or already deleted', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

grant execute on function public.create_contact(text, date, text, text, text, text)
  to anon, authenticated;
grant execute on function public.update_contact(uuid, text, date, text, text, text, text)
  to anon, authenticated;
