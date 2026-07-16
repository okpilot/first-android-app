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
- **CLEAN slice traces** (full detail → [topics/clean-slices.md](topics/clean-slices.md)):
  - Idempotent create RPCs on client-minted id (issue #9 / Decision 41, `20260716120000`) — CLEAN.
    All 7 create_* gain trailing `p_id uuid default null`; `coalesce(p_id, gen_random_uuid())` +
    `on conflict (id) do nothing` + `return v_id`. **toRpcParams now carries `p_id` for BOTH create
    AND update** — verified all 4 spread-update paths (event/contact/event_type/task_category) send a
    named key SET that EXACTLY equals the update_* signature (PostgREST binds by name, order/trailing
    irrelevant); task update stays explicit (has p_is_done, not in create) — correct. All 7 DROP
    signatures match the pre-migration latest defs exactly (a wrong sig would silently no-op under IF
    EXISTS → leave old overload → PGRST203) — checked each. **create_task_comment restructure is
    correct**: folded `insert...select...where exists(task live)...on conflict(id) do nothing` then
    post-`if not exists(id=v_id) raise` distinguishes the two zero-row causes — archived/missing parent
    (new id absent → raise) vs idempotent replay (row present → success); never lets a NEW comment onto
    an archived parent, correctly treats "created live, parent archived between attempts, retried" as
    success. `_pendingId` lifecycle sound: 5 pop-on-success forms use `late final` (fresh State per
    open, edit uses `existing.id ?? _pendingId` so edit never touches it); in-pane TaskEditView
    (`ValueKey('new')`) is unmounted by `_onCreated` → fresh State → fresh id per create; CommentsSection
    field is mutable, reset to `newEntityId()` only AFTER a successful add (inside `_run`, guarded by
    `_busy`). Forms rely on button-disable/AbsorbPointer (one-frame gap) but idempotency now CLOSES the
    double-tap window by design. KNOWN, ACCEPTED design limit (not a bug): a changed-payload replay with
    the same id after a silently-committed attempt-1 keeps old scalars (first-write-wins) and UNIONs
    junction rows (attendees/contacts/categories add, never remove) — window is narrow (commit + dropped
    response + user edit + re-Save), the returned `_fetchOne` reflects truth (not silent corruption), and
    first-write-wins is the correct idempotent-create semantic. Do NOT re-flag as a race/lost-update.
  - Task↔categories m2m link (Decision 40 Slice B, `d95f85b`) — verbatim mirror of task_contacts
    join. copyWith `categories ?? this.categories` (toggle-safety) + update() re-sends full
    `p_categories`: both list & detail `_toggleDone` hold. fromJson `task_category_links`(to-many)→
    `task_categories`(to-one) null-skip = RLS-hidden soft-deleted category. Migration drop targets
    `create_task(text,text,uuid[],smallint)`/`update_task(uuid,text,boolean,text,uuid[],smallint)`
    MATCH add_importance's current sigs; new 5-/7-arg revoke+grant match; create p_categories
    DEFAULTED / update REQUIRED (omitted arg → PGRST202 not silent wipe). Embed cols
    `task_categories(id,name,color)` ↔ fromJson `json['color']` (DB col is `color`). mounted-guards
    in `_openCategories`/`_save`; `_lastData` `identical` guard intact; colour never rides alone
    (row/detail/picker/form all dot+name). Wiring un-crossed.
  - Task categories entity + Settings manager (Decision 39 Slice A, `9377a61`) — byte-faithful
    port of the event_types system (model/repo/screen/migration). All 3 RPC arities match
    `toRpcParams()` (create `p_name,p_color`; update `+p_id`; soft-delete `p_id`); `_load` stale-guard
    (`identical(future,_future)`) + `mounted`-after-await + messenger/navigator-captured-before-await
    all preserved verbatim from event_types_screen; `fromJson` `#888888` fallback + case-insensitive
    Dart sort mirror EventType; `update_task_category` raises `no_data_found` like update_event_type,
    soft-delete idempotent void like sibling. Post-lockdown table (SELECT-only RLS, RPC-only writes,
    PUBLIC-revoke+anon-grant) — no direct write path ever shipped. TypeSwatch imported (not forked) so
    no regression to event-types; colour never rides alone (TypeSwatch always + `Text(name)`). Do NOT re-flag.
  - Pre-auth DB lockdown (Decision 36, `d549d45`) — behavior-preserving. `create or replace` (no drop)
    PRESERVES the function ACL, so the PUBLIC-execute revoke in part 2 survives the part-3 body
    replace regardless of order — NOT an ordering hazard. All 21 revoke signatures verified against
    each function's LATEST (post-drop-chain) definition; drop chains are contiguous so no stale
    overload retains PUBLIC execute. A wrong revoke signature would ERROR (abort migration), not
    silently no-op. Client writes RPC-only + reads direct (`.from(_table).select` untouched), so
    closing the direct write path breaks nothing. task_comment guard uses a correct correlated
    `exists(... tasks t where t.id = task_comments.task_id ...)` — `if not found` cannot fire on a
    live-task flow (UI blocks writes on archived tasks anyway). Do NOT re-flag.
  - Tasks view-first (Decision 29, `cfbfe7f`) — state-lift trap RESOLVED; `id:isArchived:isDone`
    key + host `setState(_task)` keep the AppBar/pane consistent; create transient is by-design.
  - Tasks in-pane create wide-only (Decision 29 amend, `acb0043`) — `_creatingNew`+`ValueKey('new')`;
    synchronous setStates, no `mounted` gap, draft survives background `_load()`. Diverges from Contacts.
  - CommentsSection extraction (Slice 2a, `2717da9`) — verbatim transplant; `parent_id:event_id`
    select-only alias is deliberate (real cols on `.eq`), all async invariants preserved.
  - Task `notes` scalar add (Decision 31, `4d3d6b8`) — reusable nullable-scalar-on-RPC-entity shape;
    `copyWith(notes ?? this.notes)`, `''`→NULL clear, keyless-for-notes but no stale display.
  - Task `importance` 0..3 scalar (Decision 38, `3bf48ea`) — fixed-semantic-scale-on-RPC-entity shape
    (NOT colour-as-data; Decision 19 N/A). `copyWith(importance ?? this.importance)` preserves the
    marker across both complete-toggles; `p_importance` REQUIRED-no-default on update (PGRST202 not
    silent reset); overload drops re-issue the lockdown revoke+grant; `.where`-split preserves the
    importance-desc sort; `ImportanceMarks` never rides colour-alone (Semantics label). Do NOT re-flag.
  - Task↔contacts "People on a task" (`2b100b7`) — KEY invariant HOLDS: toggles `copyWith(isDone:!)`
    preserve contacts via `contacts ?? this.contacts`; `_columns` embeds on both reads; soft-deleted
    contact drop is CORRECTLY LIMITED to the RLS-hidden case (parity with events). Do NOT flag.
  - Task comments repo/wiring (Slice 2b, `643bbeb`) — byte-faithful event-repo twin; alias split +
    non-atomic re-fetch by design; main→HomeShell wiring un-crossed, verified by hand.
  - Comments `_CommentsSection` (`3a87cc8`) — `identical(future,_future)` guard; controllers cleared
    AFTER await so a failed write preserves text; `_run` = messenger + `mounted` + `busy` finally.

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth (issue #3) — DB-security is
  `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
