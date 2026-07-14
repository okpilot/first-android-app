# CLEAN slices — verbose review detail

One-line pointers live in `MEMORY.md` → "Positive signals". Full traces here.

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
