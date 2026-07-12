-- 20260710120000_create_event_types.sql
-- Event types (categories) with a colour. Forward-only; never edit after it has run
-- somewhere — add a new migration instead. Conventions: docs/database.md.
--
-- When this shipped, create/rename/recolor were plain direct-under-RLS insert/update and
-- only the soft-delete used a SECURITY DEFINER RPC. Decision 26 (2026-07-12) since routed
-- ALL writes through RPCs: create_event_type / update_event_type (migration
-- 20260712140000) replaced the direct writes; the insert/update policies + grants below are
-- left in place (closing the direct path is auth hardening, issue #3). The soft-delete RPC
-- (a direct REST UPDATE of deleted_at fails PostgREST's RETURNING re-check, 42501) ships in
-- a later migration.
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
