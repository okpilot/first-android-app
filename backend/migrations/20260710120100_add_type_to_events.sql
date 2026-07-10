-- 20260710120100_add_type_to_events.sql
-- Give an event an optional type. Forward-only. Conventions: docs/database.md.
--
-- Nullable FK, with NO on-delete action on purpose: types are soft-deleted, never hard
-- deleted, so the FK never actually fires. A soft-deleted type stays referenced here but
-- is hidden by its SELECT policy, so the events -> event_types embed comes back NULL and
-- the event reads as "No type" (non-destructive delete, no event rows rewritten).
--
-- Reads pick the type up via the event_types(...) embed added to the events select in
-- this same slice. The WRITE path (create_event / update_event gaining a p_type_id
-- param) lands in a later migration, with the assign slice.

alter table public.events
  add column type_id uuid references public.event_types(id);
