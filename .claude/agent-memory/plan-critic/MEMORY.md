# plan-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring plan
> failure modes for THIS project so future reviews focus where plans actually go wrong.
> Curated at `/wrapup`.

## Recurring plan failure modes

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Plan reuses `format.dart` `hhmm(int minutes)` to render a timestamp/`DateTime` — but `hhmm` takes minutes-from-midnight, not a DateTime, and PostgREST `timestamptz` comes back UTC/offset (needs `.toLocal()`). | 2026-07-11 (event-comments) | 1 | 2026-07-11 | WATCHING — flag if a UI slice reuses `hhmm` on a `created_at`/`updated_at` |
| Plan proposes a new RPC's `set search_path` value/pattern that diverges from the 5 existing RPCs AND from `docs/database.md` rule #6 (`always SET search_path = public`) while claiming to "mirror create_event". Also mis-attributes search_path to issue #3 (which tracks auth.uid(), not search_path — search_path is already compliant everywhere). | 2026-07-12 (writes→RPC) | 1 | 2026-07-12 | WATCHING — when a plan sets a `SET search_path` value, diff it against rule #6 + existing RPCs |
| Plan says "document the new convention in database.md" but the change actually REVERSES an emphatically-worded existing rule (rule #2 "the *corrected* rule — NOT everything is RPC"; rule #4 event_comments exception; Decision 23) plus contradicts live repo doc-comments/migration headers — under-scoping the doc amendments and leaving contradictory prose. | 2026-07-12 (writes→RPC) | 3 | 2026-07-12 (comments→RPC Slice 3) | PROMOTED → CLAUDE.md "How we work" (rule-reversal-sync). Recurred AGAIN Slice 3: plan listed database.md #2/#4 + comment.dart + comments_repo + create_event_comments.sql header + .coderabbit.yaml + README *Verify* block — but MISSED (a) README.md 2nd surface, the "Conventions in play" summary block (~146-149) still "plain direct UPDATEs — no soft_delete_* RPC", and (b) **docs/decisions.md Decision 23** (line ~203 "No soft-delete RPC needed") needs a dated in-place amendment (append-only ledger — NOT a rewrite). RULE: on a reversal sweep, grep the WHOLE of each touched file (a file has >1 stale surface) AND the decisions ledger. |
| Plan removes a model write-method (`toWrite`) but its Tests section lists only the NEW tests — misses that `test/*_test.dart` has tests FOR the removed method AND that its only private helper (`_emptyToNull`) is orphaned (→ analyze `unused_element`) + a dangling `[toWrite]` dartdoc ref. | 2026-07-12 (contacts→RPC Slice 1) | 1 | 2026-07-12 | WATCHING — when a plan says "remove method X if unreferenced", grep test/ AND check for now-dead private helpers + dartdoc `[X]` links |
| Plan swaps a screen's pane widget type / removes a UI affordance (e.g. wide pane `TaskEditView`→`TaskDetailView`, drops the "Mark complete" Switch) and its Tests section enumerates only SOME of the tests that assert the old affordance — misses SIBLING tests that use that same affordance (`find.text('Mark complete')`, `find.byType(Switch)`) as an incidental proxy for "the editable pane is here". Those tests break `flutter test` even though the plan never named them. | 2026-07-14 (tasks view-first) | 1 | 2026-07-14 | WATCHING — when a plan removes a widget/affordance, grep the WHOLE test file for that text/type, not just the tests the plan renamed |

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
- **tasks view-first plan (2026-07-14):** accurate on the hard parts — verified `Task.copyWith(title:)`
  preserves `isDone`+`deletedAt` (title-only edit safe); correctly kept the compound pane key
  `id:isDone:isArchived` (still needed so a LIST-circle toggle of the selected task remounts the
  read-only detail); correctly reasoned the read-only detail's own `setState(_task=result)` removes the
  need for `_onEditorChanged`'s optimistic `_lastData` patch (no control-set flash on archive/restore
  because a stale `_lastData` keeps the key unchanged → no remount during the reload). Correctly chose
  body-Edit over prototype's AppBar-Edit (both layouts share one control set; desktop pane has no
  AppBar). Correctly confirmed no fallout in widget_test/home_shell/contacts_master_detail (repo
  interface unchanged; no test asserts the contact-detail pencil). Only gap: Step 5 wide-test coverage
  (see tracker).
- **comments→RPC Slice 3 plan (2026-07-12):** nailed the tricky per-entity DIVERGENCES from the
  contacts/event_types template: (1) `update_comment` is body-only and the repo builds `{p_id,p_body}`
  explicitly rather than spreading `toRpcParams()` (spreading would send `p_event_id` to a fn that lacks
  it → PGRST202) — verified the UI never edits an archived comment (Edit action is only on live tiles,
  `_archivedTile` offers only Unarchive), so the `deleted_at is null` guard is safe; (2) `soft_delete_comment`
  /`restore_comment` `returns uuid`+`_fetchOne` (not `void` like contacts `softDelete`) — correct, because
  `using(true)` keeps the archived row selectable and the interface returns `Comment`; (3) FK/body CHECK fire
  naturally through the RPC. Correctness was clean; only the doc-sweep completeness slipped (see tracker).
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
