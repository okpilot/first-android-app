-- 20260710120000_create_event_types.sql
-- Event types (categories) with a colour. Forward-only; never edit after it has run
-- somewhere — add a new migration instead. Conventions: docs/database.md.
--
-- Single-table entity, so writes go DIRECT under RLS (like contacts), NOT through an
-- RPC: create / rename / recolor are plain insert/update. Only the soft-delete needs a
-- SECURITY DEFINER RPC (a direct REST UPDATE of deleted_at fails PostgREST's RETURNING
-- re-check against the SELECT policy, 42501 — same reason soft_delete_contact exists).
-- That delete RPC ships in a later migration, with the manage slice.
--
-- Colour is a 6-digit #RRGGBB hex (DB-authoritative, portable); the client maps it to a
-- Flutter Color. Non-destructive delete: a soft-deleted type is hidden by the SELECT
-- policy, so an event's event_types(...) embed comes back NULL and the event reads as
-- "No type" — no event rows are rewritten.

create table public.event_types (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null check (length(trim(name)) > 0),
  color       text        not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz                        -- soft-delete: NULL = live row
);

-- keep updated_at honest on every mutation (reuse the shared fn from the contacts migration)
create trigger event_types_set_updated_at
  before update on public.event_types
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.event_types enable row level security;

create policy event_types_select on public.event_types
  for select to anon, authenticated
  using (deleted_at is null);

create policy event_types_insert on public.event_types
  for insert to anon, authenticated
  with check (true);

create policy event_types_update on public.event_types
  for update to anon, authenticated
  using (deleted_at is null)
  with check (true);

-- No DELETE policy on purpose: soft-delete only, via the soft_delete_event_type RPC
-- (later migration). Hard DELETE stays unavailable to clients (database.md #4).

grant select, insert, update on public.event_types to anon, authenticated;
