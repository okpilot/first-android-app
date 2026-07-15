# plan-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring plan
> failure modes for THIS project so future reviews focus where plans actually go wrong.
> Curated at `/wrapup`.

## Recurring plan failure modes

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Plan reuses `format.dart` `hhmm(int minutes)` to render a timestamp/`DateTime` — but `hhmm` takes minutes-from-midnight, not a DateTime, and PostgREST `timestamptz` comes back UTC/offset (needs `.toLocal()`). | 2026-07-11 (event-comments) | 1 | 2026-07-11 | WATCHING — flag if a UI slice reuses `hhmm` on a `created_at`/`updated_at` |
| Plan proposes a new RPC's `set search_path` value/pattern that diverges from the 5 existing RPCs AND from `docs/database.md` rule #6 (`always SET search_path = public`) while claiming to "mirror create_event". Also mis-attributes search_path to issue #3 (which tracks auth.uid(), not search_path — search_path is already compliant everywhere). | 2026-07-12 (writes→RPC) | 1 | 2026-07-12 | WATCHING — when a plan sets a `SET search_path` value, diff it against rule #6 + existing RPCs |
| Plan says "document the new convention in database.md" but the change actually REVERSES an emphatically-worded existing rule (rule #2 "the *corrected* rule — NOT everything is RPC"; rule #4 event_comments exception; Decision 23) plus contradicts live repo doc-comments/migration headers — under-scoping the doc amendments and leaving contradictory prose. | 2026-07-12 (writes→RPC) | 3 | 2026-07-15 (Decision 36 preauth lockdown, d549d45) | PROMOTED → CLAUDE.md "How we work" (rule-reversal-sync). **Recurred AGAIN 2026-07-15 (d549d45):** plan's reversal sweep initially missed 2nd/3rd stale LEDGER surfaces — decisions.md D33 (L390-391) + plan.md L41/L67-68 — AND proposed SKIPPING stale migration headers that Slices 2/3 had already corrected in-slice; caught this pass (REVISE). Same SECONDARY-surface-within-a-touched-file mechanism as the refinement learner tracked at count 2 (3296258→d549d45). **NOW PROMOTED (d549d45):** the "grep the WHOLE of each touched file + every decisions-ledger subsection, not just the first citation" refinement was folded into the binding CLAUDE.md "How we work" rule-reversal paragraph — the plan author now reads it there, not just in doc-updater's post-commit memory. Recurred AGAIN Slice 3: plan listed database.md #2/#4 + comment.dart + comments_repo + create_event_comments.sql header + .coderabbit.yaml + README *Verify* block — but MISSED (a) README.md 2nd surface, the "Conventions in play" summary block (~146-149) still "plain direct UPDATEs — no soft_delete_* RPC", and (b) **docs/decisions.md Decision 23** (line ~203 "No soft-delete RPC needed") needs a dated in-place amendment (append-only ledger — NOT a rewrite). RULE: on a reversal sweep, grep the WHOLE of each touched file (a file has >1 stale surface) AND the decisions ledger. **Same family, ADD variant (Slice 2b):** the plan had NO docs step at all — adding a third `using(true)` table (`task_comments`) leaves database.md #4's exception list ("`event_comments` and `tasks`", line 18) stale, and skips the backend/README per-entity Verify block + decisions.md append. RULE EXTENSION: a new soft-delete-viewable table is also a #4-exception-list edit (not just reversals); on ANY new `*_comments`/viewable-soft-delete table, check database.md #4 list + README Verify parity even when nothing is being reversed. **Same family, OPERATIVE-NUMBER variant (2026-07-14, issue #40 review-bar rebalance):** plan changed the fleet round floor/ceiling (2/3→3/4, ceiling 4→6) + CR-local M across agent-workflow.md + 3 agent defs + Decision 7 — but MISSED `.claude/commands/wrapup.md:47` which restates the number ("ceiling (4 for plan/semantic/code)"). RULE EXTENSION: a change to an operative RULE-NUMBER (round floor/ceiling, M) is also a cross-reference sweep — `grep -rn 'ceiling\|floor\|N=\|M='` the WHOLE of `.claude/commands/` + `.claude/agents/` for files that RESTATE the number, not just the rule's home file. (wrapup.md and coderabbit.md both restate ceilings.) |
| Plan removes a model write-method (`toWrite`) but its Tests section lists only the NEW tests — misses that `test/*_test.dart` has tests FOR the removed method AND that its only private helper (`_emptyToNull`) is orphaned (→ analyze `unused_element`) + a dangling `[toWrite]` dartdoc ref. | 2026-07-12 (contacts→RPC Slice 1) | 1 | 2026-07-12 | WATCHING — when a plan says "remove method X if unreferenced", grep test/ AND check for now-dead private helpers + dartdoc `[X]` links |
| Plan renames a repo method + a model factory-param (`fetchForEvent`→`fetchFor`, `Comment.draft(eventId:)`→`(parentId:)`) but the Tests step under-enumerates the widget-test fakes: it named a NON-EXISTENT file (`event_detail_screen_test.dart`) and only 1 of 3 `_FakeCommentsRepo`s — MISSED `widget_test.dart` + `calendar_screen_test.dart` fakes (both implement the renamed method + call the renamed factory → won't compile). Also: `fromJson` unit tests feed raw `'event_id'` JSON keys that must become `'parent_id'` (separate from the Dart-identifier rename), and the renamed prod class (`SupabaseCommentsRepository`→`...Event...`) has a caller in `main.dart` the step list omitted. | 2026-07-14 (CommentsSection extract) | 1 | 2026-07-14 | WATCHING — on ANY repo-method/factory-param rename, `grep -rn <method>\|<factory>( test/` for EVERY fake (don't trust the plan's file list; verify the named test files exist), and check `main.dart` for the prod instantiation |
| Plan adds a model field but its Tests step is generic and misses that (a) fake repos which RECONSTRUCT the entity from scratch — `_StatefulTasksRepo.create/archive/restore` rebuild `Task(id,title,isDone[,notes,deletedAt])` — silently DROP the new field (so a test asserting the field survives archive/render fails), and (b) an exact-map assertion on `toRpcParams()` (`expect(p, {'p_title': ...})`) breaks the moment a param is added. Also: a CREATE OR REPLACE that recreates an RPC to add a param must re-carry the WHOLE prior body (SECURITY DEFINER, SET search_path=public, guards, `if not found raise`, `trim`). | 2026-07-14 (task notes Slice 1) | 2 | 2026-07-14 (task↔contacts) | RULE CANDIDATE (count 2) — SAME mechanism recurred adding `List<Contact> contacts`: `_StatefulTasksRepo` (in tasks_list_screen_test AND task_detail_screen_test) rebuilds Task w/o contacts; `task_test.dart:95` exact-map `expect(p,{'p_title':..,'p_notes':null})` breaks on `p_contacts`. RULE: when a plan adds a model field, grep test/ for fakes that CONSTRUCT the entity (not just pass through) + exact-map assertions on toRpcParams; when it recreates an RPC, demand the full prior body preserved |
| Plan says "reuse the shared fake ContactsRepository from event tests" — but the fleet's fakes are PRIVATE per-file (`_FakeContactsRepo` in calendar_screen_test.dart / event_form_screen_test.dart; `_FakeRepo` in widget_test/home_shell_test) and NOT importable. A screen gaining a new required repo param needs a NEW fake added to EACH test file that builds it (here: task_detail/form/list tests had none) + the param threaded into every screen-instantiation helper. | 2026-07-14 (task↔contacts) | 1 | 2026-07-14 | WATCHING — when a plan says "reuse the existing/shared fake", verify the fake is a public/importable class, not a private `_Fake*` per-file |
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
- **task-people plan (2026-07-14, DB lens):** signature-change chain EXACTLY right — dropped the CURRENT
  binding sigs `create_task(text,text)` / `update_task(uuid,text,boolean,text)` (from the add_notes
  migration, not the original create_tasks), re-granted the new `(text,text,uuid[])` /
  `(uuid,text,boolean,text,uuid[])`, drop-before-recreate dodges PGRST203, timestamp 20260714160000 > latest
  (20260714140000_create_task_comments). unnest/on-conflict/delete-then-reinsert atomic (single plpgsql txn),
  mirrors update_event; delete placed AFTER the not-found raise (won't wipe People for a missing/archived task).
  Load-bearing insight it got RIGHT: `task_contacts` SELECT must be `using(true)` (NOT event_attendees'
  parent-live EXISTS) precisely so an ARCHIVED task's embed still returns its People — the archived-detail
  roster depends on it. Arity clean: create spreads {p_title,p_notes,p_contacts}; update builds explicit
  {p_id,p_title,p_is_done,p_notes,p_contacts}. Only doc nit: `task_contacts` is a NEW `using(true)` table but
  NOT a database.md #4 "viewable-soft-delete" exception (no deleted_at; its using(true) is parent-gate
  divergence, not view-archived) — header annotation is the right home, don't force it into #4's list.
- **task-comments Slice 2b plan (2026-07-14):** code/DB reasoning clean — cloned event_comments+comment_write_rpcs correctly (table+4 RPCs in ONE migration, matching the create_tasks.sql precedent, not the split event_comments used); FK `on delete restrict` to soft-delete-only `tasks(id)` right; parallel `taskCommentsRepository` threaded ContactsApp→HomeShell→TasksListScreen without disturbing the event `commentsRepository`; explicit RPC param maps (no toRpcParams spread — correct per database.md #2); `readOnly` default-false keeps event callers compiling; correctly saw CommentsSection.build is a Column (safe in TaskDetailView's ListView) and that readOnly needs only widget-gating, no controller suppression. Named the right test FILES (no missed file). Only gap: NO docs step (database.md #4 exception list + README Verify + decisions.md) — see tracker.
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
