# semantic-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring semantic /
> behavioral bug patterns for THIS project so future reviews focus where logic actually breaks.
> Curated at `/wrapup`. Verbose per-slice review detail lives in `topics/*.md`.

## Recurring semantic bugs
- **`setState(() => <expr that returns a Future>)`** (PROMOTED, count 2: Contacts `fa4fc45`,
  comments `3a87cc8`). The arrow discards the Future — async work fires but `setState` returns
  synchronously; `flutter analyze` did NOT flag it (legal void-context arrow) until the
  `discarded_futures` lint was enabled (`0e4a7af`), which now mechanizes the catch. Fix = block body
  `setState(() { … })` and `await`/`unawaited` outside. Still worth a semantic flag on any new
  `setState(() => …)` whose callee returns a Future (belt-and-braces with the lint).
- **Form/section declares an entity read-only but leaves a write affordance live** (RULE CANDIDATE,
  count 2: Tasks `58b2b5d` fixed `258cb6c`; **CommentsSection `643bbeb`**). **learner promoted this
  at `adab034` → proposed a written convention in `docs/design-principles.md` (gate EVERY write
  affordance, incl. state-dependent inline editors, on the read-only flag). Once the main session
  writes it, mark PROMOTED → docs/design-principles.md.** Slice 2b: `readOnly`
  gates the composer + per-comment Edit/Archive/Unarchive, but NOT the inline-edit branch
  `editing ? _editBody(c) : _viewBody(c)` (line 243) — `_editBody`'s TextField + live Save
  (`_saveEdit`→`repository.edit`) render on `_editingId` ALONE. Reachable: open a LIVE task, tap a
  comment's Edit (sets `_editingId`), then tap the TASK's Archive → in-place `setState(_task=result)`
  rebuilds CommentsSection with `readOnly=true` but NO remount (no key) ⇒ `_editingId` survives ⇒
  Save stays live; DB `update_task_comment` guards `deleted_at is null` on the COMMENT (still live),
  so the write SUCCEEDS on a supposedly-frozen archived-task log. **FIXED & re-verified CLEAN
  (`adab034`)** with BOTH belt-and-braces layers: (a) `_liveTile` renders
  `(editing && !widget.readOnly) ? _editBody : _viewBody` so the editor can't render read-only, and
  (b) `didUpdateWidget` sets `_editingId = null` on the false→true readOnly flip (no setState — a
  rebuild is already in flight, correct). The two cooperate on the phone in-place path (TaskDetailView
  persists, CommentsSection keyless ⇒ didUpdateWidget fires): (a) blocks the render, (b) ensures the
  editor does NOT reappear on a later Restore (readOnly true→false is a no-op for the clear, but
  `_editingId` was already nulled). Desktop path remounts via the host key so state is fresh anyway.
  Stale `_editController.text` is harmless — `_startEdit` resets it on the next edit. Leak CLOSED.
  Same root lesson: gate ALL write affordances — incl. STATE-dependent ones (an open inline editor) —
  on the read-only flag, not just the always-rendered buttons. Archived `TaskFormScreen` hid the complete toggle
  but kept the title editable + BOTH Save affordances live → Save → `update_task` guarded
  `deleted_at is null` → `no_data_found` → misleading "Couldn't save" (retry always fails). Fix =
  gate ALL write affordances (Save button + input field + `onFieldSubmitted`) on the same read-only
  flag. Watch new edit/detail forms that gate ONE affordance but not its siblings. Decision 29
  (view-first Tasks, `cfbfe7f`) removes the whole risk STRUCTURALLY: the archived-readonly branch is
  gone from `TaskEditView` (title-only form, live-only) and an archived task can no longer reach the
  form at all — the read-only detail drops Edit/Complete and offers Restore only. Preferred shape.

_Seed watch-items carried from the project's conventions:_
- **`mounted`-after-`await`** — a new `await` in a `State` method that then touches `context` /
  `setState` must be followed by `if (!mounted) return;`. Watch every new await path.
- **`_lastData` stale-load race** — a late/stale `FutureBuilder` load must not overwrite newer data;
  a failed refresh keeps stale data. Check the guard survives any load rework.
- **`Event.fromJson` embeds** — `event_attendees[].contacts` and the `event_types` embed; a
  soft-deleted type → embed null → `type` null (must not crash). Attendees are `List<Contact>`;
  there is **no `EventAttendee` model**.
- **Minutes-from-midnight** — `startMin`/`endMin` both null iff `allDay`. Watch changes that break it.
- **RPC-only writes** — event writes go through `create_event`/`update_event`, deletes through
  `soft_delete_*`; check `toRpcParams()` passes the params the RPC signature expects.

## Watching
- **per-keystroke `setState((){})`** — a bare `setState` rebuilds the whole `FutureBuilder` + tiles +
  `.where` filters on each keystroke. Cheap for small lists, idiomatic here; flag only if it recurs on
  a larger/perf-sensitive list. (WATCHING, count 2: comments `3a87cc8`, contacts search `194ff12`.)
- **mutation entrypoints missing an `if (_busy) return` re-entrancy guard** — some ops guard `_busy`
  internally, others (`_archive`/`_unarchive`) rely solely on button-disable. Idempotent so far.
  Watch for a NON-idempotent mutation that takes this shape. (WATCHING, count 1, first seen 3a87cc8.)

## Positive signals (reviewed CLEAN — detail in topics)
- **Desktop-adaptive slices (Decision 28 A/B/C: sidebar 4679504, master-detail 16ed89e, desktop-top
  search 194ff12)** — [topics/desktop-adaptive-slices.md](topics/desktop-adaptive-slices.md). Detail
  `selected` always resolves by id against the FULL list; B/C `_lastData` lingers are
  consistent-by-design transients, NOT ISSUEs.
- **Decision 26 write-RPC ports (contacts 1988e26, event-types 20970ea, comments 3296258)** —
  [topics/write-rpc-ports.md](topics/write-rpc-ports.md). Reusable 4-check port shape; `.single()`
  and the non-atomic RPC-then-`_fetchOne` re-fetch are correct by design — do NOT flag as races.
- **CLEAN slice traces** (one line each; full detail → [topics/clean-slices.md](topics/clean-slices.md)):
  - Shared test-fakes consolidation (`test/support/fakes.dart`) — behavior-preserving; two
    `_StatefulTasksRepo` merged into one superset, comments inert-vs-seeded tiers mapped right,
    seeds mutable. Do NOT re-flag a fake-consolidation when the shared body is char-identical + superset.
  - Idempotent create RPCs on client-minted id (issue #9 / Decision 41, `20260716120000`) — 7 `create_*`
    get `p_id default null` + `coalesce`+`on conflict do nothing`; toRpcParams carries `p_id` both ways;
    first-write-wins replay is ACCEPTED, not a race.
  - Task↔categories m2m link (Decision 40 Slice B, `d95f85b`) — verbatim task_contacts mirror; copyWith
    toggle-safety + full `p_categories` re-send; null-skip = RLS-hidden category.
  - Task categories entity + Settings manager (Decision 39 Slice A, `9377a61`) — byte-faithful
    event_types port; RPC arities match toRpcParams; post-lockdown table, no direct write path.
  - Pre-auth DB lockdown (Decision 36, `d549d45`) — `create or replace` preserves the ACL so revoke
    survives; 21 revoke sigs verified vs latest defs; wrong sig ERRORs not no-ops.
  - Tasks view-first (Decision 29, `cfbfe7f`) — state-lift trap RESOLVED; `id:isArchived:isDone` key.
  - Tasks in-pane create wide-only (Decision 29 amend, `acb0043`) — `_creatingNew`+`ValueKey('new')`;
    synchronous setStates, draft survives background `_load()`.
  - `DetailField` superset-merge extraction (Decision 43, `780c930`) — merging two divergent `_Field`s;
    `copyWith(color:null)` is a no-op (`color ?? this.color`) so contact non-empty == plain bodyLarge;
    relaxed assert `child==null||value==null` allows both-null (contact dob) forbids both-non-null;
    `_whenLabel` always returns non-empty so event never reaches the empty→"Not added" branch. CLEAN.
  - CommentsSection extraction (Slice 2a, `2717da9`) — verbatim transplant; select-only alias deliberate.
  - Task `notes` scalar add (Decision 31, `4d3d6b8`) — nullable-scalar-on-RPC-entity shape; `''`→NULL clear.
  - Task `importance` 0..3 scalar (Decision 38, `3bf48ea`) — fixed-semantic-scale (NOT colour-as-data);
    `p_importance` REQUIRED-no-default on update; ImportanceMarks never rides colour-alone.
  - Task↔contacts "People on a task" (`2b100b7`) — toggles preserve contacts; soft-deleted drop LIMITED
    to RLS-hidden case (parity with events).
  - Task comments repo/wiring (Slice 2b, `643bbeb`) — byte-faithful event-repo twin; wiring un-crossed.
  - Comments `_CommentsSection` (`3a87cc8`) — `identical` guard; controllers cleared AFTER await.

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth (issue #3) — DB-security is
  `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
