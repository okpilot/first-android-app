# CLEAN slices — verbose review detail

One-line pointers live in `MEMORY.md` → "Positive signals". Full traces here.

## Shared test-fakes consolidation (`test/support/fakes.dart`)
Behavior-preserving, tiers correct. Two local `_StatefulTasksRepo` merged into one SUPERSET
(`lastUpdated`+`archivedId`+`restoredId`); the tasks_list variant lacked archivedId/restoredId but
nothing referenced their absence, so the superset is safe. Comments inert-vs-seeded tiers mapped
right: task_detail's SEEDED local → `SeededCommentsRepo` (not downgraded to inert), tasks_list
default → inert `FakeCommentsRepo` + wide-pane test → `SeededCommentsRepo`. `FakeEventsRepo` gained
`lastCreated` (superset over calendar's local) — harmless. comments_section keeps its local full-CRUD
`_FakeCommentsRepo` (the one it exercises); all retained locals private-prefixed so no collision with
public shared names. Seed lists passed as mutable `[...]` so `add`/`_tasks.add` never hit a const
list — identical to the originals. Do NOT re-flag a fake-consolidation for tier/permissiveness drift
when the shared body is char-identical + superset capture fields.

## Idempotent create RPCs on client-minted id (issue #9 / Decision 41, `20260716120000`)
All 7 `create_*` gain trailing `p_id uuid default null`; `coalesce(p_id, gen_random_uuid())` +
`on conflict (id) do nothing` + `return v_id`. toRpcParams carries `p_id` for BOTH create AND update —
all 4 spread-update paths send a named key SET that EXACTLY equals the update_* signature (PostgREST
binds by name); task update stays explicit (has p_is_done, not in create). All 7 DROP signatures match
the pre-migration latest defs exactly (a wrong sig silently no-ops under IF EXISTS → stale overload →
PGRST203). create_task_comment restructure correct: `insert...select...where exists(task live)...on
conflict(id) do nothing` then post-`if not exists(id=v_id) raise` distinguishes archived/missing parent
(raise) vs idempotent replay (success); never lets a NEW comment onto an archived parent. `_pendingId`
lifecycle sound (5 pop-on-success forms `late final`; in-pane TaskEditView `ValueKey('new')` remounts;
CommentsSection field reset to `newEntityId()` only AFTER success). KNOWN ACCEPTED limit (not a bug):
changed-payload replay after a silently-committed attempt-1 keeps old scalars (first-write-wins) and
UNIONs junction rows — narrow window, `_fetchOne` reflects truth, correct idempotent-create semantic.
Do NOT re-flag as a race/lost-update.

## Task↔categories m2m link (Decision 40 Slice B, `d95f85b`)
Verbatim mirror of task_contacts join. copyWith `categories ?? this.categories` (toggle-safety) +
update() re-sends full `p_categories`: both list & detail `_toggleDone` hold. fromJson
`task_category_links`(to-many)→`task_categories`(to-one) null-skip = RLS-hidden soft-deleted category.
Migration drop targets `create_task(text,text,uuid[],smallint)` /
`update_task(uuid,text,boolean,text,uuid[],smallint)` MATCH add_importance's current sigs; new 5-/7-arg
revoke+grant match; create p_categories DEFAULTED / update REQUIRED (omitted arg → PGRST202 not silent
wipe). Embed cols `task_categories(id,name,color)` ↔ fromJson `json['color']`. mounted-guards in
`_openCategories`/`_save`; `_lastData` `identical` guard intact; colour never rides alone. Wiring
un-crossed.

## Task categories entity + Settings manager (Decision 39 Slice A, `9377a61`)
Byte-faithful port of the event_types system. All 3 RPC arities match `toRpcParams()` (create
`p_name,p_color`; update `+p_id`; soft-delete `p_id`); `_load` stale-guard (`identical`) +
`mounted`-after-await + messenger/navigator-captured-before-await all preserved verbatim; `fromJson`
`#888888` fallback + case-insensitive Dart sort mirror EventType; `update_task_category` raises
`no_data_found` like update_event_type. Post-lockdown table (SELECT-only RLS, RPC-only writes,
PUBLIC-revoke+anon-grant) — no direct write path ever shipped. TypeSwatch imported (not forked);
colour never rides alone. Do NOT re-flag.

## Pre-auth DB lockdown (Decision 36, `d549d45`)
Behavior-preserving. `create or replace` (no drop) PRESERVES the function ACL, so the PUBLIC-execute
revoke in part 2 survives the part-3 body replace regardless of order — NOT an ordering hazard. All 21
revoke signatures verified against each function's LATEST (post-drop-chain) definition; drop chains
contiguous so no stale overload retains PUBLIC execute. A wrong revoke signature ERRORs (aborts
migration), not silent no-op. Client writes RPC-only + reads direct (`.from(_table).select`
untouched). task_comment guard uses a correct correlated `exists(... tasks t where t.id =
task_comments.task_id ...)`. Do NOT re-flag.

## Task importance 0..3 scalar (Decision 38, `3bf48ea`)
Reusable **fixed-semantic-scale scalar on an RPC entity** shape (sibling of the notes scalar add,
Decision 31 `4d3d6b8`, but NOT colour-as-data — a fixed 0..3 mapped to a hue, so Decision 19 does
NOT apply). All invariants held: `copyWith(importance ?? this.importance)` preserves the marker
across BOTH complete-toggle paths (list circle `_toggleDone` + detail Complete/Reopen), each of which
`copyWith(isDone: !…)` WITHOUT importance — same load-bearing mechanism as `contacts`. Arity correct:
`update_task` map sends exactly its 6 params (`p_importance` REQUIRED no-default — an omitted arg
fails PGRST202 not a silent reset, the deliberate defensive choice); `create_task` via `toRpcParams`
sends 4, all defaulted server-side. Drops of the old 3-arg/5-arg overloads kill PGRST203 ambiguity
AND (correctly) re-issue the PUBLIC revoke + anon/authenticated grant on the NEW signatures (Decision
36 lockdown invariant honoured). Sort `is_done asc, importance desc, created_at desc, id`: the UI
`.where`-splits (active/completed/archived) preserve relative order, so importance-desc-within-group
renders as intended; archived group ordering by is_done-then-importance is a harmless collapsed-section
transient, NOT a bug. `ImportanceMarks`/`_ImportanceSegment` render nothing at level 0, mute for
done/archived, carry a `Semantics('Importance <name>')` label so the glyph never rides alone (a11y).
Picker state (`_importance` seeded in initState, `setState` on tap) is fully synchronous — no
mounted-after-await gap. LOW SUGGESTION only (unreachable given DB `check (0..3)` + `int?? 0`): the
three boundary helpers diverge above 3 — `importanceMarks` clamps to `!!!`, `importanceColor`→null,
`importanceName`→'None'; harmless but inconsistent if ever fed out-of-range.

## Tasks view-first (Decision 29, `cfbfe7f`)
The state-lift-vs-`widget.x` trap (impl-critic WATCHING) is RESOLVED: `TaskDetailScreen` host seeds
`late _task` AND `setState`s it in every `onChanged`, so the dynamic AppBar ('Task'/'Archived task')
can't go stale on in-place archive/restore. Desktop `_task`↔`_load()` consistency holds via the
compound pane key `id:isArchived:isDone` — a body archive/restore/complete flips its own `_task`
first (no flash while stale `_lastData` keeps the key unchanged), then `_load()` reseeds on remount.
`_openForm` create (push form → `_selectedId=saved.id` → `_load()`, NO optimistic `_lastData` patch)
is a byte-for-byte mirror of the accepted Contacts template — the removed `_onEditorChanged` patch
was only needed for the OLD in-pane create; the brief fall-to-`active.first` during the load window
is the same consistent-by-design transient Contacts already ships. Do NOT flag it. `_run` =
messenger-before-await + `mounted` re-check in both branches.

## Tasks in-pane create reintroduced, wide-only (Decision 29 amend, `acb0043`)
Wide "New" is now `_creatingNew` bool → `TaskEditView(key ValueKey('new'), onChanged: _onCreated)`
in the detail pane; narrow still pushes `TaskFormScreen` via `_openForm`. `_creatingNew` set true
ONLY in `_startNew`, cleared in BOTH `_onCreated` and `_selectTask` (row-select) — no wide path
strands it. `_startNew`/`_selectTask`/`_onCreated` are synchronous `setState` (no await before
setState) and `onChanged` fires from a mounted child ⇒ parent guaranteed mounted — no
`mounted`-after-`await` gap. `_onCreated` = setState(creating=false, `_selectedId=saved.id`) +
`unawaited(_load())`, NO optimistic `_lastData` patch — same accepted create→reload transient (pane
briefly falls to `active.first`, or first-task flashes the zero-state EmptyState during the load
window, exactly like Contacts). A background `_load()` during creation can't clobber the draft:
stable `ValueKey('new')` ⇒ no remount ⇒ text preserved. Do NOT flag any of this. NOTE: Tasks now
diverges from Contacts here — Contacts wide `onNew` still pushes the full form; only Tasks does
in-pane create. MetaLine extraction (`lib/widgets/meta_line.dart`) keeps the
`parts.isEmpty→SizedBox.shrink()` guard; contact call-site retains its own null guard.

## CommentsSection extraction (Slice 2a, `2717da9`) — behavior-preserving
`_CommentsSection` transplanted verbatim from `event_detail_screen.dart` to public
`lib/widgets/comments_section.dart` (only `fetchForEvent`→`fetchFor`, `eventId`→`parentId`). All
async invariants preserved: `_load()` triple `identical(future,_future)` stale-guard, `_lastData`
FutureBuilder fallback, `_busy` re-entrancy, `if(!mounted)return` after every await,
messenger-before-await. The PostgREST **select-only alias** `parent_id:event_id` in `_columns` is
correct: reads `.eq('event_id', parentId)` and `_fetchOne` `.eq('id', id)` use REAL column names;
`_columns` (with alias) is shared by list-read and `_fetchOne` so `Comment.fromJson` reads
`json['parent_id']` uniformly on both paths. RPC maps verified against binding migration
`20260712150000_comment_write_rpcs.sql`: `create_comment(p_event_id,p_body)` with `body.trim()`,
`update_comment(p_id,p_body)` body-only (edit can't reparent), `soft_delete_comment`/`restore_comment`
(p_id). `toRpcParams` moved model→repo. Do NOT flag the alias/real-column split — it's the deliberate
mechanism letting one `Comment` model serve both `*_comments` tables.

## Task `notes` scalar field add (Decision 31, `4d3d6b8`)
Reusable "add-a-nullable-scalar-to-an-RPC-written-entity" shape: (1) `copyWith({String? notes})` uses
`notes ?? this.notes` (null arg = keep) — the complete-toggle preserves notes untouched; the form
always passes `_notes.text` ('' when cleared), and CLEAR-via-`''`→server `nullif(trim(),'')`→NULL is
deliberate (no explicit-clear sentinel). (2) Migration drops OLD signatures, create-or-replaces with
prior body VERBATIM + notes, re-grants — correct PGRST203 dodge. (3) Detail-key `id:isArchived:isDone`
omits notes, but a notes-only edit does NOT strand stale display: `_edit`/`_run` do in-place
`setState(_task=updated)` (server re-fetch) BEFORE the keyless-for-notes `_load()` rebuild.
`_save` = messenger-before-await + `if(!mounted)return` in both branches.

## Task↔contacts link "People on a task" (`2b100b7`)
Reusable "link-contacts-to-a-parent-via-RPC-managed-join" shape, byte-faithful to event attendees.
The KEY invariant HOLDS: both complete-toggles (`tasks_list _toggleDone(task)` +
`TaskDetailView._toggleDone`) call `copyWith(isDone:!)` WITHOUT contacts; `copyWith` defaults
`contacts ?? this.contacts` (load-bearing) so the flip preserves the set, and `update` re-sends the
WHOLE `p_contacts` (delete-then-reinsert) from a source Task that always carries its embed —
`_columns` now embeds `task_contacts(contact_id, contacts(id,name,company))` on BOTH `fetchAll` and
`_fetchOne`, so every Task reaching `update()` carries full contacts. Do NOT flag the
delete-then-reinsert as a race. `Task.fromJson` embed-skip
(`if (c is Map<String,dynamic>) contacts.add(...)`) is identical to `Event.fromJson`; a soft-deleted
(RLS-hidden) contact → null `contacts` on the join row → skipped → a later update silently drops that
link — CORRECTLY LIMITED to the RLS-hidden case (a live contact always round-trips), exact parity
with events; accepted, do NOT flag. Migration drops OLD sigs, create-or-replaces with prior body
VERBATIM + People handling, re-grants — correct PGRST203 dodge. `unnest(NULL/'{}')`→zero rows makes
empty-People a safe no-op. `AttendeePickerScreen`→generalized `ContactPickerScreen(title: role-noun)`,
old file fully removed, no lingering refs; `_openPeople` = `mounted`-gated setState after await. Wide
detail key omits contacts but no stale display: pane `_edit` does in-place `setState(_task=updated)`
before the keyless-for-contacts `_load()`. Minor: repo `create` inline comment still says
`toRpcParams() is {p_title, p_notes}` — now also `p_contacts` (stale comment, code-reviewer's lane).

## Task comments repo/wiring (Slice 2b, `643bbeb`)
`SupabaseTaskCommentsRepository` is a byte-faithful twin of the event repo: `parent_id:task_id`
select-only alias + real-column `.eq('task_id')`/`.eq('id')`, `.single()` re-fetch (row always
readable under `using(true)`, incl. archived), RPC names+arity all match binding migration
`20260714140000` (`create_task_comment`(p_task_id,p_body) / `update_task_comment`,
`soft_delete_task_comment`,`restore_task_comment`(p_id)). Do NOT flag the alias split or the
non-atomic RPC-then-`_fetchOne`. Wiring is clean & un-crossed: main→app→HomeShell threads
`commentsRepository`(event)→Calendar and `taskCommentsRepository`(task)→TasksList→both
TaskDetailScreen (narrow) & TaskDetailView (desktop pane); both typed `CommentsRepository` so the
compiler wouldn't catch a swap — values verified correct by hand.

## Comments `_CommentsSection` (`3a87cc8`)
`identical(future,_future)` stale-guard holds through the initState-fetch-vs-user-add race; mutation
ops clear controllers/`_editingId` AFTER the await so a failed write preserves text + keeps edit mode
open; `_run` = capture messenger + `mounted` re-check + `busy` in `finally`. Reinforce this shape for
new list/mutation sections.

## D47 UI consistency pass (`72f33c1`)
Verified behaviourally, not by reading the hunks:
- **`ymd()` split holds.** `grep -rn "ymd(" lib/` → only `models/contact.dart:73` (`p_dob`),
  `models/event.dart:116` (`p_event_date`), and `calendar_screen.dart:257/263/1243` (day-grouping map
  keys). Zero display sites. Grouping is symmetric (writer 257/1243 + reader 263 all key through
  `ymd`), so no round-trip or grouping change is possible.
- **`longDate` is byte-identical** to both inlines it replaced (`event_detail._whenLabel`,
  `event_form._dateLabel`) — same template char-for-char. No spacing/comma/year drift.
- **Comment timestamp order flip** is display-only — `_timestamp` has no parser/sort/test consumer,
  and the `hhmm(t.hour * 60 + t.minute)` minutes-from-midnight trap is still avoided.
- **`chipTheme` blast radius contained** — only 3 Material chips exist (`event_form:470`,
  `task_form:407`, `task_form:461`). `tasks_list._CategoryChip` and `comments._archivedChip` are
  hand-rolled `Container` pills, untouched. Uses the neutral `secondaryContainer` token, so no type
  colour leaks into chrome (D19 holds).
- **TypeSwatch chip correctly gets NO ring** — it's a saturated user colour against
  `secondaryContainer` (doesn't dissolve) and always rides with its name label (D19). Bonus: its
  declared `size: 16` now renders nominally (contentSize 20 → 16 had been stretching it to 20).
- **AppBar `Save` removal loses no guard** — all four forms already had a bottom
  `FilledButton(onPressed: _saving ? null : _save)` INSIDE `AbsorbPointer(absorbing: _saving)`. The
  AppBar copy needed its own `_saving` guard only because it sat outside that AbsorbPointer.
- No new await paths, no `_lastData` rework ⇒ no `mounted`/stale-guard exposure.
