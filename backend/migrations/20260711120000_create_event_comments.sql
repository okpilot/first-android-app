-- 20260711120000_create_event_comments.sql
-- Comments on an event. Forward-only; never edit after it has run somewhere — add a new
-- migration instead. Conventions: docs/database.md.
--
-- When this shipped, writes went DIRECT under RLS and there was no soft-delete RPC. Decision 26
-- (2026-07-12, Slice 3) since routed ALL writes through RPCs: create_comment / update_comment /
-- soft_delete_comment / restore_comment (migration 20260712150000) replaced the direct writes;
-- the insert/update policies + grants below are left in place (closing the direct path is auth
-- hardening, issue #3). Soft-delete only ("archive") per database.md #4 — no hard DELETE.
--
-- The one deliberate divergence from every other table is a READ policy, and it still holds:
-- the SELECT policy is `using (true)`, NOT `using (deleted_at is null)`. Archived
-- (deleted_at IS NOT NULL) comments stay READABLE — that is the feature ("see archived
-- comments"). NOTE: that `using (true)` also means an archived row survives PostgREST's RETURNING
-- re-check, so the comment write RPCs above are for UNIFORMITY, not to dodge a 42501 (unlike
-- soft_delete_contact / soft_delete_event_type, which genuinely need SECURITY DEFINER) — a direct
-- write would have worked here.

create table public.event_comments (
  id          uuid        primary key default gen_random_uuid(),
  -- RESTRICT, not CASCADE: comments are retained content (history), unlike the ephemeral
  -- event_attendees join rows (which cascade). Events are soft-deleted only, so this never
  -- fires today — but if a hard-delete of events is ever added, RESTRICT blocks it rather
  -- than silently erasing archived comment history.
  event_id    uuid        not null references public.events(id) on delete restrict,
  body        text        not null check (length(trim(body)) > 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz                        -- archive marker; NULL = live. NOT hidden by RLS.
);

-- Comments are always queried by their event, so index the FK.
create index event_comments_event_id_idx on public.event_comments (event_id);

-- keep updated_at honest on every mutation (reuse the shared fn from the contacts migration)
create trigger event_comments_set_updated_at
  before update on public.event_comments
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.event_comments enable row level security;

-- using (true), NOT (deleted_at is null): archived comments must stay readable so the app can
-- show them under a "Show archived" toggle (and so archive survives the RETURNING re-check).
create policy event_comments_select on public.event_comments
  for select to anon, authenticated
  using (true);

create policy event_comments_insert on public.event_comments
  for insert to anon, authenticated
  with check (true);

-- One update policy covers edit (body), archive (set deleted_at) AND unarchive (clear it).
-- using (true), NOT (deleted_at is null): an already-archived row must be targetable to restore it.
create policy event_comments_update on public.event_comments
  for update to anon, authenticated
  using (true)
  with check (true);

-- No DELETE policy on purpose: soft-delete (archive) only. Hard DELETE stays unavailable to
-- clients (database.md #4).
grant select, insert, update on public.event_comments to anon, authenticated;
