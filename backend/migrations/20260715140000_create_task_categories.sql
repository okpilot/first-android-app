-- 20260715140000_create_task_categories.sql
-- Task categories (user-owned tags) with a colour. Decision 39, Slice A.
-- Forward-only; never edit the executable SQL after it has run somewhere — add a new migration.
-- Conventions: docs/database.md.
--
-- A separate taxonomy from event_types (the user chose independent lists): tasks get their OWN
-- category set, so a task tag never clutters the event Type picker and vice versa. This slice
-- stands up the entity + its Settings manager only — nothing links a task to a category yet; the
-- task↔category join table + the form picker are Slice B.
--
-- Colour is a 6-digit #RRGGBB hex (DB-authoritative, portable); the client maps it to a Flutter
-- Color and reuses the shared event-type palette. Non-destructive delete: a soft-deleted category
-- is hidden by the SELECT policy (its embed will come back NULL once Slice B links it), so no rows
-- are rewritten.
--
-- POST-LOCKDOWN POSTURE (Decision 36): this table is created AFTER the lockdown, so it ships
-- RPC-only writes from day one — there is NO direct insert/update RLS policy and NO insert/update
-- grant to ever close later (cleaner than event_types, which shipped direct writes and closed them
-- in 20260715120000). Writes go exclusively through the 3 SECURITY DEFINER RPCs below; reads stay
-- direct-under-RLS. Each RPC gets the lockdown grant discipline (database.md rule #2): PUBLIC execute
-- revoked, anon/authenticated granted.
--
-- (No auth.uid() ownership checks: there is NO auth — single-user + tailnet-only, login is WON'T-DO,
-- Decision 37. Same posture as every sibling RPC.)

create table public.task_categories (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null check (length(trim(name)) > 0),
  color       text        not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz                        -- soft-delete: NULL = live row
);

-- keep updated_at honest on every mutation (reuse the shared fn from the contacts migration)
create trigger task_categories_set_updated_at
  before update on public.task_categories
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.task_categories enable row level security;

create policy task_categories_select on public.task_categories
  for select to anon, authenticated
  using (deleted_at is null);

-- No insert/update/delete policies on purpose: post-lockdown, writes go ONLY through the SECURITY
-- DEFINER RPCs below (which run as the table owner and bypass RLS). Hard DELETE stays unavailable to
-- clients — soft-delete only, via soft_delete_task_category (database.md #4).

-- Reads only for clients; the RPCs own every write.
grant select on public.task_categories to anon, authenticated;

-- create -------------------------------------------------------------------
create or replace function public.create_task_category(
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
  -- trim(p_name) drives the table's check (length(trim(name)) > 0): a blank name raises a check
  -- violation. p_color is a clean #RRGGBB built by the client from the palette; the table's color
  -- check re-validates it.
  insert into public.task_categories (name, color)
  values (trim(p_name), p_color)
  returning id into v_id;

  return v_id;
end;
$$;

-- update -------------------------------------------------------------------
create or replace function public.update_task_category(
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
  update public.task_categories set
    name  = trim(p_name),
    color = p_color
  where id = p_id
    and deleted_at is null;

  -- Bail (rolling back the call) if the id is unknown or already soft-deleted — otherwise we'd
  -- silently succeed on a hidden/absent row and return an id that wasn't actually updated.
  if not found then
    raise exception 'task category % not found or already deleted', p_id
      using errcode = 'no_data_found';
  end if;

  return p_id;
end;
$$;

-- soft-delete --------------------------------------------------------------
-- A single-table write, but still SECURITY DEFINER: a direct REST UPDATE that sets deleted_at fails
-- PostgREST's RETURNING re-check against the SELECT policy (42501). Non-destructive — once Slice B
-- links tasks, they keep their category_id and the category simply reads as "no category".
create or replace function public.soft_delete_task_category(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.task_categories
     set deleted_at = now()
   where id = p_id
     and deleted_at is null;
$$;

-- Lock the new signatures (database.md rule #2): revoke Postgres's default PUBLIC execute, grant to
-- the app roles. Both are needed — the revoke asserts the Decision 36 lockdown, the grant keeps the
-- app working.
revoke execute on function public.create_task_category(text, text)      from public;
revoke execute on function public.update_task_category(uuid, text, text) from public;
revoke execute on function public.soft_delete_task_category(uuid)        from public;

grant execute on function public.create_task_category(text, text)      to anon, authenticated;
grant execute on function public.update_task_category(uuid, text, text) to anon, authenticated;
grant execute on function public.soft_delete_task_category(uuid)        to anon, authenticated;
