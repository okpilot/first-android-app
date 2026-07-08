-- 20260708120000_create_contacts.sql
-- First real table. Forward-only; never edit after it has run somewhere — add a new
-- migration instead. Conventions: docs/database.md.
--
-- No per-user auth yet (GoTrue deferred), so policies grant the anon role CRUD over
-- non-deleted rows. When the auth slice lands, tighten to owner-based policies.

create table public.contacts (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null check (length(trim(name)) > 0),
  dob         date,
  email       text,
  phone       text,
  company     text,
  remarks     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz                        -- soft-delete: NULL = live row
);

-- keep updated_at honest on every mutation
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger contacts_set_updated_at
  before update on public.contacts
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.contacts enable row level security;

create policy contacts_select on public.contacts
  for select to anon, authenticated
  using (deleted_at is null);

create policy contacts_insert on public.contacts
  for insert to anon, authenticated
  with check (true);

create policy contacts_update on public.contacts
  for update to anon, authenticated
  using (deleted_at is null)
  with check (true);

-- No DELETE policy on purpose: soft-delete only (set deleted_at). Hard DELETE stays
-- unavailable to clients (database.md #4).

grant select, insert, update on public.contacts to anon, authenticated;
