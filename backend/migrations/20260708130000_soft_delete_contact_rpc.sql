-- 20260708130000_soft_delete_contact_rpc.sql
-- Forward-only follow-up to the contacts table.
--
-- Why an RPC for a single-table write (normally we'd go direct under RLS)?
-- The SELECT policy hides soft-deleted rows (deleted_at is null). A direct UPDATE that
-- sets deleted_at makes the new row fail that policy, which PostgREST re-checks via its
-- internal RETURNING -> "new row violates row-level security policy" (42501). Running the
-- write in a SECURITY DEFINER function bypasses RLS for that one controlled operation.
-- This matches database.md: soft-delete is the default and sensitive writes go via a fn.
--
-- (No auth.uid() check yet — GoTrue is deferred. Add the ownership check with the auth slice.)

create or replace function public.soft_delete_contact(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.contacts
     set deleted_at = now()
   where id = p_id
     and deleted_at is null;
$$;

grant execute on function public.soft_delete_contact(uuid) to anon, authenticated;
