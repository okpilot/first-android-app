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
- **Form declares an entity read-only but leaves a write affordance live** (RESOLVED-WATCH, count 1,
  Tasks `58b2b5d`; fixed & re-verified `258cb6c`). Archived `TaskFormScreen` hid the complete toggle
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
- **Tasks view-first (Decision 29, `cfbfe7f`)** — the state-lift-vs-`widget.x` trap
  (impl-critic WATCHING) is RESOLVED: `TaskDetailScreen` host seeds `late _task` AND `setState`s it in
  every `onChanged`, so the dynamic AppBar ('Task'/'Archived task') can't go stale on in-place
  archive/restore. Desktop `_task`↔`_load()` consistency holds via the compound pane key
  `id:isArchived:isDone` — a body archive/restore/complete flips its own `_task` first (no flash while
  stale `_lastData` keeps the key unchanged), then `_load()` reseeds on remount. `_openForm` create
  (push form → `_selectedId=saved.id` → `_load()`, NO optimistic `_lastData` patch) is a byte-for-byte
  mirror of the accepted Contacts template — the removed `_onEditorChanged` patch was only needed for
  the OLD in-pane create; the brief fall-to-`active.first` during the load window is the same
  consistent-by-design transient Contacts already ships. Do NOT flag it. `_run` =
  messenger-before-await + `mounted` re-check in both branches.
- **Tasks in-pane create reintroduced, wide-only (Decision 29 amend, `acb0043`) — CLEAN.** Wide "New"
  is now `_creatingNew` bool → `TaskEditView(key ValueKey('new'), onChanged: _onCreated)` in the
  detail pane; narrow still pushes `TaskFormScreen` via `_openForm`. `_creatingNew` set true ONLY in
  `_startNew`, cleared in BOTH `_onCreated` and `_selectTask` (row-select) — no wide path strands it.
  `_startNew`/`_selectTask`/`_onCreated` are synchronous `setState` (no await before setState) and
  `onChanged` fires from a mounted child ⇒ parent guaranteed mounted — no `mounted`-after-`await` gap.
  `_onCreated` = setState(creating=false, `_selectedId=saved.id`) + `unawaited(_load())`, NO optimistic
  `_lastData` patch — same accepted create→reload transient (pane briefly falls to `active.first`, or
  first-task flashes the zero-state EmptyState during the load window, exactly like Contacts). A
  background `_load()` during creation can't clobber the draft: stable `ValueKey('new')` ⇒ no remount ⇒
  text preserved. Do NOT flag any of this. Dartdoc key-order nit RESOLVED (`id:isArchived:isDone` now
  matches real key). NOTE: Tasks now diverges from Contacts here — Contacts wide `onNew` still pushes
  the full form; only Tasks does in-pane create. MetaLine extraction (`lib/widgets/meta_line.dart`)
  keeps the `parts.isEmpty→SizedBox.shrink()` guard; contact call-site retains its own null guard —
  behaviorally faithful merge.
- **CommentsSection extraction (Slice 2a, `2717da9`) — CLEAN, behavior-preserving.** `_CommentsSection`
  transplanted verbatim from `event_detail_screen.dart` to public `lib/widgets/comments_section.dart`
  (only `fetchForEvent`→`fetchFor`, `eventId`→`parentId`, and a `_run` doc-comment losing its
  now-irrelevant `_confirmDelete`-idiom aside). All async invariants preserved: `_load()` triple
  `identical(future,_future)` stale-guard, `_lastData` FutureBuilder fallback, `_busy` re-entrancy,
  `if(!mounted)return` after every await, messenger-before-await. The PostgREST **select-only alias**
  `parent_id:event_id` in `_columns` is correct: reads `.eq('event_id', parentId)` and `_fetchOne`
  `.eq('id', id)` use REAL column names; `_columns` (with alias) is shared by list-read and `_fetchOne`
  so `Comment.fromJson` reads `json['parent_id']` uniformly on both paths. RPC maps verified against the
  binding migration (`20260712150000_comment_write_rpcs.sql`): `create_comment(p_event_id,p_body)` with
  `body.trim()` preserved, `update_comment(p_id,p_body)` body-only (no `p_event_id` ⇒ edit can't reparent),
  `soft_delete_comment(p_id)`/`restore_comment(p_id)`. `toRpcParams` moved model→repo (repo now owns the
  `p_event_id` vs future `p_task_id` divergence). Do NOT flag the alias/real-column split as a bug — it's
  the deliberate mechanism letting one `Comment` model serve both `*_comments` tables. Minor coverage
  note (test-writer's lane): the removed `Comment.toRpcParams` unit test means create-body-trim is no
  longer model-unit-tested, but `_add` pre-trims and the repo re-trims — functionally covered.
- **Task `notes` scalar field add (Decision 31, `4d3d6b8`) — CLEAN.** Reusable
  "add-a-nullable-scalar-to-an-RPC-written-entity" shape: (1) `copyWith({String? notes})` uses
  `notes ?? this.notes` (null arg = keep) — the complete-toggle (`copyWith(isDone:...)`, list circle
  + detail button) preserves notes untouched; the form always passes `_notes.text` ('' when cleared),
  and CLEAR-via-`''`→server `nullif(trim(),'')`→NULL is deliberate (no explicit-clear sentinel
  needed). (2) Migration drops OLD signatures (`create_task(text)`, `update_task(uuid,text,boolean)`),
  create-or-replaces with prior body VERBATIM + notes, re-grants NEW signatures — correct PGRST203
  dodge, do NOT flag. (3) Detail-key `id:isArchived:isDone` omits notes, but a notes-only edit does
  NOT strand stale display: `_edit`/`_run` do in-place `setState(_task=updated)` (updated = server
  re-fetch, so '' already normalized to NULL) BEFORE the keyless-for-notes `_load()` rebuild; State
  persists with the fresh value. `_save` = messenger-before-await + `if(!mounted)return` in both
  branches. Reinforce this shape for the next scalar-field-add slice.
- **Comments `_CommentsSection` (3a87cc8)** — `identical(future,_future)` stale-guard holds through
  the initState-fetch-vs-user-add race; mutation ops clear controllers/`_editingId` AFTER the await
  so a failed write preserves text + keeps edit mode open; `_run` = capture messenger + `mounted`
  re-check + `busy` in `finally`. Reinforce this shape for new list/mutation sections.

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth (issue #3) — DB-security is
  `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
