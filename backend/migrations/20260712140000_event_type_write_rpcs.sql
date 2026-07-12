-- 20260712140000_event_type_write_rpcs.sql
-- Standardize the event_types write path onto RPCs (Decision 26: all writes go through RPCs;
-- reads stay direct). event_types previously wrote direct (INSERT/UPDATE under RLS) with only
-- the soft-delete routed through soft_delete_event_type. This adds create_event_type /
-- update_event_type so the whole entity writes through one place — matching the event + contact
-- RPCs (the template) and giving auth (issue #3) a single spot per entity for auth.uid() checks.
--
-- SECURITY DEFINER here is for UNIFORMITY + that future auth payoff, NOT to dodge the RLS
-- RETURNING re-check (42501): create/update touch only non-delete fields, so deleted_at stays
-- null and the row still passes event_types_select — a direct write would have worked too.
-- (Contrast soft_delete_event_type, which genuinely needs SECURITY DEFINER to set deleted_at.)
--
-- The direct insert/update GRANTs and the event_types_insert/event_types_update RLS policies are
-- intentionally LEFT IN PLACE: closing the direct write path (revoke + drop policies) is auth
-- hardening, tracked under issue #3 — same posture as contacts in Slice 1.
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred. Add them with the auth slice, #3.)

-- create -------------------------------------------------------------------
create or replace function public.create_event_type(
  p_name  text,
  p_color text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  -- trim(p_name) drives the table's check (length(trim(name)) > 0): a blank name raises a
  -- check violation, exactly as the old direct write relied on. p_color is a clean #RRGGBB
  -- built by the client from the palette; the table's color check re-validates it.
  insert into public.event_types (name, color)
  values (trim(p_name), p_color)
  returning id into v_id;

  return v_id;
end;
$$;

-- update -------------------------------------------------------------------
create or replace function public.update_event_type(
  p_id    uuid,
  p_name  text,
  p_color text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_types set
    name  = trim(p_name),
    color = p_color
  where id = p_id
    and deleted_at is null;

  -- Bail (rolling back the call) if the id is unknown or already soft-deleted — otherwise we'd
  -- silently succeed on a hidden/absent row and return an id that wasn't actually updated.
  if not found then
    raise exception 'event type % not found or already deleted', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

grant execute on function public.create_event_type(text, text) to anon, authenticated;
grant execute on function public.update_event_type(uuid, text, text) to anon, authenticated;
