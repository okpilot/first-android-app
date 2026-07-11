-- 20260711120000_create_event_comments.sql
-- Comments on an event. Forward-only; never edit after it has run somewhere — add a new
-- migration instead. Conventions: docs/database.md.
--
-- Single-table entity, so writes go DIRECT under RLS (like contacts / event_types), NOT
-- through an RPC. Soft-delete only ("archive") per database.md #4 — no hard DELETE.
--
-- The one deliberate divergence from every other table: the SELECT policy is `using (true)`,
-- NOT `using (deleted_at is null)`. Archived (deleted_at IS NOT NULL) comments stay READABLE
-- — that is the feature ("see archived comments"). A happy consequence: because an archived
-- row survives PostgREST's RETURNING re-check against this SELECT policy, archive / unarchive /
-- edit are all plain direct UPDATEs — no SECURITY DEFINER soft-delete RPC is needed here (the
-- reason soft_delete_event_type / soft_delete_contact needed one — a 42501 on the RETURNING
-- re-check against `using (deleted_at is null)` — does not apply).

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
