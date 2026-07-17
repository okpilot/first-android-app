# plan-critic — positive signals (detail)

> Plans that were accurate and well-validated, and *what specifically* they got right. Read on demand:
> these record the reasoning patterns that work here, so a review doesn't re-litigate settled ground or
> drift into over-caution. Curated in place at `/wrapup`.

## Slice A1 — UI-consistency pass (2026-07-17)
The *risky* classifications were all CORRECT and independently verified:
- **`ymd()` split exhaustive** — all 10 call sites accounted for; none is both display AND wire. Wire
  (`contact.dart:73` `p_dob`, `event.dart:116` `p_event_date`) and map-key
  (`calendar_screen.dart:257,263,1241`) correctly quarantined; the ISO map key is precisely what keeps
  day-grouping sortable.
- **`contact_form_screen.dart:220` genuinely display-only** — `_DobField` is a read-only
  `InkWell`+`InputDecorator` feeding a date picker ("poka-yoke: no free-text dates"); the text is never
  parsed back.
- **No import cycle** — `util/calendar.dart` has **zero** imports, so `format.dart`→`calendar.dart`
  can't drag Flutter into the models.
- **AppBar line numbers right, not backwards** — 260/243 are the editors' `TextButton('Save')`;
  221/204 are the delete-confirm `AlertDialog` Cancel/Delete. Both editors keep a body `FilledButton`
  with the spinner, so removal leaves a working save path.
- **`chipTheme` blast radius correctly scoped** to the 3 `InputChip`s (`event_form:477`,
  `task_form:407,453`) — `comments_section:412 _archivedChip()` and `tasks_list:636 _CategoryChip` are
  plain `Container`s, immune; none of the 3 sets a local `backgroundColor`/`shape` that would override
  the theme.

Misses were all **completeness, not correctness** (orphaned imports, an undefined helper, the a11y
Semantics label, driver-vs-assertion test fallout).

**v3 stability round (regression lens) — CLEAN, 0 APPLY findings.** Six independent regression probes
all confirmed the plan; recording them so a future round doesn't re-litigate:
- **`ymd()` map-key grouping is untouched AND untested** — `grep -rn ymd test/` returns **zero** hits, so
  the day-grouping has no regression net; but nothing in the slice perturbs it (the only
  `calendar_screen.dart` edit is the `:968–970` Semantics string, far from `:257,263,1241`).
- **`_timestamp` is display-only** — used at `comments_section.dart:281,395` and nowhere else; no test
  asserts the rendered string, and comment ordering sorts on `id` (`comments_section_test.dart:38`),
  never on the formatted text. The order flip is safe.
- **No keyboard/a11y save path dies with the 4 AppBar Saves** — `grep onFieldSubmitted lib/` returns
  nothing; the `TextInputAction.done` at `event_types_screen.dart:278` /
  `task_categories_screen.dart:261` only dismisses the keyboard. Every body `FilledButton` lives inside
  a scrollable `ListView`, so it is always reachable at runtime however short the window (the viewport
  problem is a *test*-only artifact of the fixed 800×600 surface). **`contact_form_screen_test.dart`
  does not exist** → contact form's removal has zero test fallout.
- **`chipTheme` reaches nothing in a dialog** — the app's entire Chip family is 3 `InputChip`s; the
  delete-confirm `AlertDialog`s use `TextButton`/`FilledButton`, and Flutter's date/time pickers contain
  no Chip.
- **`ring: true` is safe** — `InitialsAvatar` is never referenced in `test/`, has no golden, and no site
  passes a shared/const key.
- **`displayDate`/`displayDateNoYear`/`longDate` don't collide** — no such symbol exists in `lib/` or
  `test/`, and `calendar_test.dart` never touches `dayLabel`, so existing expectations are untouched.

**v3 second stability round (fresh-eyes lens, independent re-derivation) — CLEAN, 0 APPLY findings.**
Every classification re-derived from scratch matched the plan **exactly, including line numbers**:
- **`ymd()` table reproduced independently** — 9 call sites + the def; display (`meta_line:18,19`,
  `contact_detail:199`, `contact_form:220`) / wire (`contact:73`, `event:116`) / map-key
  (`calendar_screen:257,263,1241`) split is exhaustive. A whole-`lib/` sweep for date interpolation
  (`.year}`/`monthShort[`/`weekdayShort[`/`dayLabel(`/`periodLabel(`) turned up **no** display-date
  surface outside the plan's table + D-c's stated calendar-chrome skip.
- **F11 (orphaned import) fully dodged** — per-file symbol counts confirm the "swap" vs "both stay"
  column is right in all 6 rows: `meta_line`/`contact_detail`/`contact_form` use format.dart for `ymd`
  ONLY (→ swap, and none already imports calendar.dart, so no dup); `comments_section`/`event_detail`
  keep calendar.dart live via the NEW helper and format.dart via `hhmm`; `event_form` keeps calendar
  via `dayOnly` (2×) regardless of `_dateLabel`'s deletion.
- **#3 is provably exhaustive** — sweeping EVERY `actions: [` in `lib/`, the only AppBar `Text('Save')`s
  are the plan's 4. All other `actions:` are Cancel (delete-confirm dialogs), Done (pickers) or Today
  (calendar). **`task_form_screen.dart:40` already has an actions-less AppBar** — it is the in-tree
  precedent the slice generalises, not a missed 5th site.
- **The `'Save'` grep widened beyond the plan's pattern still yields 7** — no test taps Save via bare
  `find.text('Save')`/`byType(TextButton)`. All 7 are create-mode (each reached via a `New …` FAB or a
  no-`existing:` `_form()`) → `Add type`/`Add category`/`Add event` is the right retarget.
  `task_categories_screen_test.dart:241` taps a body `FilledButton, 'Save changes'` at the DEFAULT
  surface, which is live proof the editor pin is genuinely unnecessary (D's scope-the-pin call).
- **"Zero test coverage for display dates" is true** — nothing in `test/` asserts a rendered date; every
  ISO literal is wire, and the plan's cited line numbers (`event_test:15,42,58,78,92,110,118,146`,
  `contact_test:10,54`, `contact_picker:57,64,69,74,77` + `147–165`, `calendar_test:49,55`,
  `calendar_screen_test:51,109`) are each **exact**.
- **D-g's collision is real, not theoretical** — `initials_avatar.dart:29` fills with
  `secondaryContainer`; `theme.dart:91,96,99` alias primary/secondary/tertiaryContainer all onto the one
  `chip` token. `ring: true` (`initials_avatar.dart:42–50`) is the atom's own built-in escape hatch.
  Bonus consistency the plan didn't claim: `_archivedChip` fills with `primaryContainer` = the same
  `chip` token, so the new chip fill *matches* it rather than clashing.
- **No new same-screen format clash** — `event_detail` has **no** `MetaLine` (only `contact_detail:233` +
  `task_detail:274` do), so `longDate` never sits beside `displayDate`; and `labelMedium`'s `inkSoft`
  == today's M3 default chip label colour, so #6 fixes the *scale* without shifting the colour.

## DetailField extraction (2026-07-16, #10 item 2)
Pure-UI widget extraction — accurate and complete.
- Correctly identified the superset merge (contact `value:String?` + "Not added" placeholder vs event
  `value XOR child` + `selectable` + TypeLabel child), and that the relaxed assert
  `child==null||value==null` (both-null allowed) is safe for BOTH callers.
- Verified pixel-identity: both originals share the exact same tree (padding bottom 20, icon size 20
  `onSurfaceVariant`, SizedBox 16/2, labelMedium label, bodyLarge value); contact's non-empty
  `copyWith(color:null)` is a no-op vs event's plain bodyLarge → no flattening diff.
- Call-site counts exact (5 contact @195-207, 4 event @142-163), all keyword args → mechanical
  `_Field(`→`DetailField(` rename is safe; no positional/renamed param.
- Imports: no orphan after removing local `_Field`; `DetailField` needs NO TypeLabel import (child
  passed in).
- Tests: correctly named `contacts_master_detail_test` (L66-74 exercises `find.text('Not added')`) +
  `comments_section_test`; no test refs `_Field` by type.
- Naming/location right (`lib/widgets/detail_field.dart`, matching InitialsAvatar/TypeLabel).
- Only nit: doc-comment merge left unspecified (SUGGESTION).

## task-people (2026-07-14, DB lens)
Signature-change chain EXACTLY right — dropped the CURRENT binding sigs `create_task(text,text)` /
`update_task(uuid,text,boolean,text)` (from the add_notes migration, **not** the original
create_tasks), re-granted the new `(text,text,uuid[])` / `(uuid,text,boolean,text,uuid[])`;
drop-before-recreate dodges PGRST203; timestamp 20260714160000 > latest.
- unnest/on-conflict/delete-then-reinsert atomic (single plpgsql txn), mirrors `update_event`; delete
  placed AFTER the not-found raise (won't wipe People for a missing/archived task).
- **Load-bearing insight it got right:** `task_contacts` SELECT must be `using(true)` (NOT
  event_attendees' parent-live EXISTS) precisely so an ARCHIVED task's embed still returns its People.
- Doc nit: `task_contacts` is a NEW `using(true)` table but NOT a database.md #4 "viewable-soft-delete"
  exception (no `deleted_at`; its `using(true)` is parent-gate divergence) — header annotation is the
  right home; don't force it into #4's list.

## task-comments Slice 2b (2026-07-14)
Cloned event_comments + comment_write_rpcs correctly (table + 4 RPCs in ONE migration, matching the
create_tasks.sql precedent, not the split event_comments used); FK `on delete restrict` to
soft-delete-only `tasks(id)` right; parallel `taskCommentsRepository` threaded
ContactsApp→HomeShell→TasksListScreen without disturbing the event `commentsRepository`; explicit RPC
param maps (no `toRpcParams` spread — correct per database.md #2); `readOnly` default-false keeps event
callers compiling; correctly saw `CommentsSection.build` is a Column (safe in TaskDetailView's
ListView) and that `readOnly` needs only widget-gating, no controller suppression. Named the right test
FILES. Only gap: NO docs step (see F3 ADD variant).

## tasks view-first (2026-07-14)
Accurate on the hard parts — verified `Task.copyWith(title:)` preserves `isDone`+`deletedAt`; correctly
kept the compound pane key `id:isDone:isArchived` (still needed so a LIST-circle toggle of the selected
task remounts the read-only detail); correctly reasoned the read-only detail's own
`setState(_task=result)` removes the need for `_onEditorChanged`'s optimistic `_lastData` patch (no
control-set flash on archive/restore, because a stale `_lastData` keeps the key unchanged → no remount
during the reload). Correctly chose body-Edit over the prototype's AppBar-Edit (both layouts share one
control set; the desktop pane has no AppBar). Only gap: Step 5 wide-test coverage (see F8).

## comments→RPC Slice 3 (2026-07-12)
Nailed the tricky per-entity DIVERGENCES from the contacts/event_types template:
1. `update_comment` is body-only and the repo builds `{p_id,p_body}` explicitly rather than spreading
   `toRpcParams()` (spreading would send `p_event_id` to a fn that lacks it → PGRST202) — and verified
   the UI never edits an archived comment (Edit is only on live tiles; `_archivedTile` offers only
   Unarchive), so the `deleted_at is null` guard is safe.
2. `soft_delete_comment`/`restore_comment` `returns uuid` + `_fetchOne` (not `void` like contacts
   `softDelete`) — correct, because `using(true)` keeps the archived row selectable and the interface
   returns `Comment`.
3. FK/body CHECK fire naturally through the RPC.
Correctness clean; only the doc-sweep completeness slipped (see F3).

## event-comments (2026-07-11)
Verified the trickiest DB reasoning correctly — archive/unarchive/edit can be plain direct PostgREST
UPDATEs *because* the SELECT policy is `using (true)`, so the mutated row survives PostgREST's
RETURNING re-check (the 42501 that forced `soft_delete_event_type` into a SECURITY DEFINER RPC does NOT
recur here). Also correctly set the UPDATE policy `using (true)` (not `deleted_at is null`) so an
archived row can be targeted to unarchive, and correctly claimed no existing model reads `deleted_at`.
Named every breaking construction site.
