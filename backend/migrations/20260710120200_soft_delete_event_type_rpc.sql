-- 20260710120200_soft_delete_event_type_rpc.sql
-- Soft-delete an event type. Forward-only. Conventions: docs/database.md.
--
-- A single-table write, but still a SECURITY DEFINER function for the same reason as
-- soft_delete_contact / soft_delete_event: a direct REST UPDATE that sets deleted_at
-- fails PostgREST's RETURNING re-check against the SELECT policy (42501). Create/rename/
-- recolor stay as plain direct-under-RLS writes (create_event_types migration).
--
-- Non-destructive: events keep their type_id, but the type is now hidden by its SELECT
-- policy, so the events -> event_types embed comes back NULL and those events read as
-- "No type" — no event rows are rewritten.
--
-- (No auth.uid() ownership check yet — GoTrue deferred; add it with the auth slice,
-- alongside the contacts/event_types write-hardening tracked in issue #3.)

create or replace function public.soft_delete_event_type(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.event_types
     set deleted_at = now()
   where id = p_id
     and deleted_at is null;
$$;

grant execute on function public.soft_delete_event_type(uuid) to anon, authenticated;
