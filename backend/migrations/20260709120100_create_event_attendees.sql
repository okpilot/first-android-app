-- 20260709120100_create_event_attendees.sql
-- Join table linking events to their attendee contacts (many-to-many). Forward-only.
--
-- Membership is managed ONLY by the event-write RPCs (create_event / update_event) —
-- a multi-table atomic write per database.md #1. So anon gets SELECT only, which powers
-- the embedded read:
--   events?select=...,event_attendees(contact_id, contacts(id,name,company))
--
-- Both events and contacts are soft-deleted, so the ON DELETE CASCADE FKs are a safety
-- net, not the normal path: a soft-delete just sets deleted_at; the join row survives,
-- and a hidden contact is filtered out of the embed by the contacts SELECT policy
-- (which the client must tolerate as a null `contacts` on the join row).

create table public.event_attendees (
  event_id   uuid not null references public.events(id)   on delete cascade,
  contact_id uuid not null references public.contacts(id) on delete cascade,
  primary key (event_id, contact_id)
);

-- The PK already indexes the (event_id, …) direction (event -> attendees). Add the
-- reverse so "which events is this contact on?" doesn't scan.
create index event_attendees_contact_id_idx on public.event_attendees(contact_id);

alter table public.event_attendees enable row level security;

-- Only expose a join row while its parent event is live — otherwise a soft-deleted
-- event's attendee list stays readable via this table even though the event itself is
-- hidden (the embed path is already covered by the events SELECT policy; a direct query
-- on this table is not). Read policies filter deleted_at (database.md #4).
create policy event_attendees_select on public.event_attendees
  for select to anon, authenticated
  using (
    exists (
      select 1 from public.events e
      where e.id = event_attendees.event_id
        and e.deleted_at is null
    )
  );

-- No write policy/grant: membership is set only by the SECURITY DEFINER RPCs.

grant select on public.event_attendees to anon, authenticated;
