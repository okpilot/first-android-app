# plan-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring plan
> failure modes for THIS project so future reviews focus where plans actually go wrong.
> Curated at `/wrapup`.

## Recurring plan failure modes

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Plan reuses `format.dart` `hhmm(int minutes)` to render a timestamp/`DateTime` — but `hhmm` takes minutes-from-midnight, not a DateTime, and PostgREST `timestamptz` comes back UTC/offset (needs `.toLocal()`). | 2026-07-11 (event-comments) | 1 | 2026-07-11 | WATCHING — flag if a UI slice reuses `hhmm` on a `created_at`/`updated_at` |
| Plan proposes a new RPC's `set search_path` value/pattern that diverges from the 5 existing RPCs AND from `docs/database.md` rule #6 (`always SET search_path = public`) while claiming to "mirror create_event". Also mis-attributes search_path to issue #3 (which tracks auth.uid(), not search_path — search_path is already compliant everywhere). | 2026-07-12 (writes→RPC) | 1 | 2026-07-12 | WATCHING — when a plan sets a `SET search_path` value, diff it against rule #6 + existing RPCs |
| Plan says "document the new convention in database.md" but the change actually REVERSES an emphatically-worded existing rule (rule #2 "the *corrected* rule — NOT everything is RPC"; rule #4 event_comments exception; Decision 23) plus contradicts live repo doc-comments/migration headers — under-scoping the doc amendments and leaving contradictory prose. | 2026-07-12 (writes→RPC) | 2 | 2026-07-12 (contacts→RPC Slice 1) | RULE CANDIDATE — recurred: Slice-1 plan rewrote global rule #2 to "all writes via RPC" but left `event_types_repository` doc-comment "single-table CRUD goes direct… **like contacts**" contradicting it (event_types still direct until Slice 2). When a plan rewrites a GLOBAL DB rule mid-multi-slice migration, grep every repo doc-comment that cites that rule ("per docs/database.md", "like contacts"). |
| Plan removes a model write-method (`toWrite`) but its Tests section lists only the NEW tests — misses that `test/*_test.dart` has tests FOR the removed method AND that its only private helper (`_emptyToNull`) is orphaned (→ analyze `unused_element`) + a dangling `[toWrite]` dartdoc ref. | 2026-07-12 (contacts→RPC Slice 1) | 1 | 2026-07-12 | WATCHING — when a plan says "remove method X if unreferenced", grep test/ AND check for now-dead private helpers + dartdoc `[X]` links |

_Seed watch-items carried from the project's conventions (no recurrence yet):_
- Changing a model field or repository method → does the plan list the **test fake** in `test/`?
  (Injectable-repo hermetic tests mean a signature change usually needs a fake updated.)
  Plans get the fake-repo tests right (event-comments named both `widget_test.dart` +
  `calendar_screen_test.dart`), but the contacts→RPC Slice 1 plan MISSED the model-method unit
  tests (`test/contact_test.dart` tests `toWrite` directly) — see tracker row above.
- Touching `backend/migrations/` / an RPC / RLS → does the plan reference `docs/database.md`?
- Adding colour/labels → is it colour-**as-data** (Decision 19), not chrome?
- New table's FK: siblings (`event_attendees`) use `on delete cascade`; watch for FK on-delete parity
  (moot while parents are soft-delete-only, but a consistency smell).

## Positive signals
- **event-comments plan (2026-07-11):** verified the trickiest DB reasoning correctly — that
  archive/unarchive/edit can be plain direct PostgREST UPDATEs *because* the SELECT policy is
  `using (true)`, so the mutated row survives PostgREST's RETURNING re-check (the 42501 that forced
  `soft_delete_event_type` into a SECURITY DEFINER RPC does NOT recur here). Also correctly set the
  UPDATE policy `using (true)` (not `deleted_at is null`) so an archived row can be targeted to
  unarchive, and correctly claimed no existing model reads `deleted_at`. Named every breaking
  construction site. Accurate, well-validated plan.

## Known false-positive traps (do not flag these)
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a breaking change.
- Missing `auth.uid()` is expected pre-auth (issue #3) — not a plan defect.
