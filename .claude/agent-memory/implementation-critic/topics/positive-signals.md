# Positive signals — distilled per-slice-type win conditions

All were clean pre-commit (0 blocking). These record what "correct" looked like so future reviews
know where to look. Referenced one-line from MEMORY.md.

- **Scalar-field-add slice** (Task notes = Decision 27 follow-on): adding one optional `text` column
  end-to-end. Traps all verified clean: (1) migration is drop-old-signature + create-or-replace-new
  for BOTH create+update (arity change → PGRST203 without the drop), bodies VERBATIM plus the field,
  `nullif(trim(p_notes),'')` normalization in both, grants re-issued on the NEW signatures
  (`create_task(text,text)`/`update_task(uuid,text,boolean,text)`), soft_delete/restore untouched so
  their grants stand. (2) The clear-path is the subtle one: form passes `_notes.text` (`''` when
  cleared) → `copyWith(notes:'')` OVERRIDES (empty string is non-null, so `notes ?? this.notes` keeps
  the `''`) → repo sends `p_notes:''` → server `nullif`→NULL → `_fetchOne` returns null → detail hides.
  The `notes ?? this.notes` keep-branch is only reached by `_toggleDone` (omits notes → null → kept).
  (3) Keyed-remount stale-notes is a NON-issue: detail `_edit` does in-place `setState(()=>_task=updated)`
  after the pushed form pops, so notes refresh regardless of the `id:isArchived:isDone` key (notes
  deliberately NOT in key). (4) Every reconstructing test fake threads `notes`; update fakes store the
  passed task verbatim. mounted-after-await present in `_save`.
- **Template-port slices** (contacts/event_types write-RPCs = Decision 26 Slices 1–2; event-comments):
  when a slice ports a green template, diff the two side-by-side and confirm divergences are only
  entity-specific — the security posture (`security definer`+`set search_path=public`, `deleted_at`
  guard + `no_data_found`, grant signatures matching param lists, NEW fn = no CREATE OR REPLACE chain)
  must be byte-for-byte. A verbatim copy of a green load pattern's `_lastData`/mounted checks tends to
  be right — verify the copy is faithful, don't re-derive.
- **Shared-widget second-consumer slice** (task_comments = Decision 33 / Slice 2b): a brand-new entity
  delivered THROUGH an already-green shared widget + interface (2nd `CommentsRepository` impl, `readOnly`
  flag added to `CommentsSection`). Win condition = faithful twin + gating completeness: migration is
  table+4-RPCs in ONE file (new table, no direct-write history to convert), byte-for-byte the
  event_comments/comment_write_rpcs pair modulo entity names (RESTRICT FK, `using(true)` archived-readable
  SELECT, `set_updated_at` trigger reuse, SECURITY DEFINER +`search_path=public`, update guards
  `deleted_at is null` / restore guards `is not null` + `no_data_found`, grants on the NEW distinct
  signatures `create_task_comment(uuid,text)` etc. — no CR-chain since names are new); repo alias
  `parent_id:task_id` is select-only while `.eq()`/`_fetchOne` use REAL cols (`task_id`/`id`) and param
  maps use `p_task_id`; `readOnly` (default false → events untouched) suppresses composer + live
  Edit/Archive + archived Unarchive via `if(!widget.readOnly)...[]` spreads — AND must ALSO suppress the
  STATE-DEPENDENT inline editor: gate `(editing && !widget.readOnly)` + clear `_editingId` in
  `didUpdateWidget` on the false→true flip (Slice 2b initially left the open editor's Save live after
  archiving → semantic-reviewer ISSUE, fixed `adab034`; partial gating of only the always-visible
  controls is NOT a complete win condition — see design-principles "gate EVERY write affordance");
  wiring threads the SECOND
  repo end-to-end (main→app→home_shell→tasks_list→both task-detail sites) with NO cross-wiring (calendar
  keeps `widget.commentsRepository`, tasks get `taskCommentsRepository`); `readOnly:_isArchived` tracks
  the host `_task.isArchived` (in-place setState flips it; wide-pane `id:isArchived:isDone` key also
  remounts). CommentsSection is Columns-only (no nested scrollable), so embedding in the detail's outer
  scroll matches the proven event_detail ListView pattern.
- **Divergent (rule-reversing) slice** (comment write-RPCs = Decision 26 Slice 3): win condition is
  doc-sweep completeness + per-entity divergences, NOT template-match — body-only `update` builds its
  param map EXPLICITLY (never spreads `toRpcParams()`, which would carry an extra arg → PGRST202);
  uuid-return soft-delete + `_fetchOne` (because `using(true)` keeps the archived row selectable);
  `restore` guards `deleted_at is NOT null` (inverse). Rule-reversal-sync sweep = every doc surface
  (database.md #2+#4, migration header, .coderabbit.yaml, README both surfaces, dated in-place Decision
  amendment).
- **New-entity-from-scratch slice** (Tasks v0 = Decision 27): even not-a-port, the win condition is the
  SAME per-project trap list — toRpcParams↔RPC arity (spread only the create shape; `update` builds
  params explicitly), mounted-after-await, `_lastData` stale-guard (initially copied contacts WITHOUT
  the `identical(future,_future)` guard; cloud-CR PR #30 flagged it → guard ADDED, now matches
  `event_types_screen`), nested-gesture (circle `InkResponse` inside row `InkWell`; archived rows
  `onToggle:null`), migration `using(true)`+no-delete-grant. Not novel logic.
- **Widget-extraction / master-detail slices** (Contacts master-detail = Decision 28 Slice B): a shared
  body widget (`ContactDetailView`, no Scaffold, `onChanged`/`onDeleted` callbacks, NEVER pops) + thin
  phone wrapper (owns Scaffold+PopScope+pop). Extraction must preserve every async-safety invariant
  verbatim: (1) `key: ValueKey(selected.id)` so a parent-driven selection swap REMOUNTS the pane
  (`_contact` seeded once in initState) — keyed by the resolved-selected id, not the raw param. (2)
  snackbar shown ONCE, in the body on the root messenger, host only navigates. (3) discarded_futures is
  context-sensitive: `discarded_futures: true` fires in SYNC bodies only (initState, `(_){…}` onDeleted
  closure → needs `unawaited(_load())`), NOT in async methods (`_openForm`/`_openDetail` bare `_load()`
  OK); an arrow `(_) => _load()` returns the future so it's not "discarded". (4) id-resolution stays
  dependency-free (no package:collection — `depend_on_referenced_packages` would fail the gate). (5)
  selection highlight = `primaryContainer`/`onSurface`/`onSurfaceVariant` theme tokens (chrome, not
  colour-as-data). Note: `_edit`'s `setState` after `await Navigator.push` has no `if(!mounted)return`
  but is PRE-EXISTING and provably safe (modal route over the whole tree, pane can't be disposed
  mid-await) — not a regression, do not cry-wolf.
  Tasks master-detail (Decision 28 Slice D) is the faithful sibling port: `TaskEditView` (Scaffold-less,
  `onChanged` never pops, `showHeader` for the pane) + thin `TaskFormScreen` StatelessWidget wrapper
  (`onChanged: (_) => Navigator.pop(true)` — setState-then-sync-pop in `_save` safe). Verified-clean:
  (a) both `_save` AND `_runMutation` reset `_saving=false` BEFORE `onChanged`; (b) pane key remounts on
  archive/restore because `archive`/`restore` `_fetchOne` the mutated row so `result.isArchived` flips →
  `_onEditorChanged` reselects that id. Cloud-CR #32 grew the key to `${id}:${isArchived}:${isDone}` so a
  list-toggled completion also remounts the open editor, AND made `_onEditorChanged` update `_lastData`
  optimistically (insert-if-new / replace-by-id) before `unawaited(_load())` — valid because `_load()`
  runs its sync prefix (sets `_future`) before rebuild. Key-contract trap: the BINDING key doc-comment
  lives on `TaskEditView` in `task_form_screen.dart`, NOT the list screen — a key change is a mini
  rule-reversal whose sibling doc-comment must sync in the SAME slice. (c) `_resolveSelected` =
  selected-if-present → first ACTIVE → null; stale `_selectedId` falls through safely; `_creatingNew`
  survives `_load()`. Plan-SANCTIONED minor (do NOT cry-wolf): selected-row highlight is
  `ColoredBox(primaryContainer)` wrapping the `InkWell`, so the tap ripple is masked on an already-selected
  row — cosmetic only, plan specced "ColoredBox/Ink". RefreshIndicator over the two-pane `Row` with two
  ListViews is the proven Contacts structure — no assertion.
- **Pure-refactor / widget-extraction slices** (CommentsSection extraction = Decision 2a): win condition
  = byte-equivalent BEHAVIOR, not a rewrite. Side-by-side diff removed private widget vs new public one:
  the ONLY deltas should be the rename axis (`eventId`→`parentId`, `fetchForEvent`→`fetchFor`,
  `Comment.draft(eventId:)`→`(parentId:)`, class made public + `super.key`). Every async invariant must
  survive verbatim — `_load()` triple `identical(future,_future)` stale-guard, `_run` re-entrancy `_busy`
  + messenger-captured-before-await + `if(!mounted)return`-after-await, `_lastData` fallback. Repo-side,
  a PostgREST select ALIAS (`parent_id:event_id`) is select-only: confirm `.eq()` and `_fetchOne` use the
  REAL column, and `_fetchOne` shares `_columns`. `add` builds its RPC param map INLINE once `toRpcParams`
  moves off the model — grep no dangling `toRpcParams`/`fetchForEvent`/old class name. A dangling dartdoc
  `[Comment.toRpcParams]` ref does NOT fail `flutter analyze` (comment_references off) — cosmetic.
- **Pure-UI / adaptive-layout slices** (desktop sidebar = Decision 28 Slice A): no async → `mounted`/
  `_lastData` N/A; win condition is theme-token fidelity. (1) every colour from
  `Theme.of(context).colorScheme` (no ad-hoc hex; `Colors.transparent` fine) and it's chrome, not entity
  data; (2) selection styling matches the sibling shipped theme tokens (sidebar `navigationRailTheme`:
  primaryContainer chip + onSurface/onSurfaceVariant + w600/w500); (3) no fixed height around a
  textScaler-growing Text (padding + `Flexible`+ellipsis; a fixed square OK ONLY with
  `TextScaler.noScaling` inside, as the `C⁺` brand glyph does); a non-`Flexible` Text in a fixed-width Row
  (`CRM+` wordmark) is a latent extreme-textScaler overflow — SUGGESTION, not a gate. `_TasksHeader`
  wraps title + count in `Flexible` inside the `Expanded` group (like Contacts' `_MasterHeader`) →
  overflow-safe. (4) index assumptions (Settings = `length-1`) safe vs the real `_destinations` +
  `IndexedStack` order. Passing a static-const list as a widget param instead of the plan's literal
  2-arg ctor is a harmless decoupling, not an item-10 signature break (no repo fake).
- **Infra / bash / SQL-only slices** (postgrest reload-after-migrate; DDL-watch triggers): trace quoting
  through every shell hop; confirm the NOTIFY channel/payload against PostgREST's contract; for event
  triggers confirm `returns event_trigger` + `execute function` + that `search_path=''` is safe ONLY when
  the body touches no objects. When a slice removes a "redundant" reload, check cold-start/first-load, not
  just steady state.
- **Config / asset slices** (app-icon): pixel-sample corner-vs-center alpha rather than trusting the PNG
  colortype / SVG header — catches the transparent-glyph-vs-opaque-tile split.
- **Join-table + picker-generalization slice** (People on a task = contacts↔tasks via `task_contacts`,
  mirroring event_attendees; Jul 14). Two moves in one slice, both clean. (A) The many-to-many mirror:
  new join table (composite PK, cascade FKs, reverse index on the non-PK col, RLS enabled), both write
  RPCs drop-old-signature + create-or-replace-new for the arity change (`create_task(text,text)` /
  `update_task(uuid,text,boolean,text)` — verified against the LATEST prior def in add_notes, not the
  original create), bodies VERBATIM + People handling, `delete from <join> where task_id=p_id` placed
  AFTER the not-found raise (so an unknown/archived id rolls back before any join mutation), reinsert via
  `unnest(p_contacts) on conflict do nothing`, grants re-issued on the NEW signatures. RLS divergence
  documented: `using(true)` NOT the parent-live EXISTS gate event_attendees uses, because archived tasks
  stay readable so their roster must too — header-annotated, correctly kept OFF database.md #4's list (no
  `deleted_at`, not self-soft-deletable). (B) The picker generalization: rename
  `AttendeePickerScreen`→`ContactPickerScreen` + a `title` role-noun param driving AppBar copy only;
  event caller passes `title:'attendees'` so its strings stay byte-identical (`Add attendees`/
  `Attendees · N`), grep confirms zero dangling old refs. THE LOAD-BEARING INVARIANT (a complete-toggle
  must not wipe links): verified on all THREE update paths — list `_toggleDone` + detail `_toggleDone`
  both `copyWith(isDone:!)` WITHOUT contacts, form `_save` passes `contacts:_contacts` — all preserved by
  `copyWith`'s `contacts: contacts ?? this.contacts` default, and every in-memory Task carries People
  because `_columns` embeds `task_contacts(contact_id, contacts(id,name,company))` on BOTH fetchAll and
  _fetchOne. `_openPeople` has the `if (result != null && mounted)` guard; `_save` has `if(!mounted)
  return`; `_PeopleList` null-guards `c.company`. The AppBar-title-vs-widget.x trap (MEMORY watch item)
  is handled: the detail host seeds `late _task=widget.task` and `setState`s it in `onChanged`, so the
  `'Task'`/`'Archived task'` split tracks the live entity. Every reconstructing test fake threads
  `contacts:` in create/archive/restore (both list + detail `_StatefulTasksRepo`); the exact-map
  toRpcParams assertion amended with `p_contacts:[]`; per-file private `_FakeContactsRepo` (no shared
  fake, per plan-critic).
- **Scalar-field-add, 2nd occurrence** (Task importance = Decision 38, Jul 15; the Task-notes entry
  above is occurrence 1 — the trap list held). Additions distinct to this one: the **lockdown
  invariant** — a `create or replace` of an RPC hands back default PUBLIC execute, so an arity change
  must RE-ISSUE Decision 36's `revoke execute … from public` + `grant … to anon, authenticated` on
  the NEW signatures, not just the drop+recreate; `p_importance` REQUIRED (no default) on the 6-arg
  update = fail-loud PGRST202 on a stale caller, DEFAULTED on create; `.order('importance', desc)`
  correctly sits BETWEEN `is_done` and `created_at`; the new colour is a FIXED semantic scale =
  **chrome, NOT Decision 19 colour-as-data** (the slice framed it correctly, which is the finding
  that would otherwise fire); `ImportanceMarks` carries a Semantics label so neither colour nor the
  `!` glyph rides alone. Test fakes threaded the field through create + archive + restore, not only
  update. Full dartdoc sweep clean.
- **Full-stack new-entity mirror of an existing entity** (task_categories Slice A = Decision 39,
  Jul 15; clean, 0 blocking). The win condition for a NEW table created POST-lockdown: it ships
  RPC-only from day one — SELECT-only policy `using (deleted_at is null)` + `grant select`, and
  **no** insert/update policy or grant at all (not "add then revoke"); 3 SECURITY DEFINER RPCs each
  `set search_path = public` with `revoke execute … from public` + `grant … to anon, authenticated`
  on the exact typed signatures. RPC arity matched `toRpcParams` 1:1 (create 2 `p_name`/`p_color`,
  update 3 adds `p_id` via the repo spread, soft_delete 1). Model mirrors EventType: `_validHex` →
  `#888888` fallback, draft ctor empty id, pure-Dart (no `dart:ui`). Screen IMPORTS `TypeSwatch` via
  `show` rather than redefining it, reuses `kEventTypePalette`/`colorFromHex`/`hexFromColor`; the new
  colour IS user-data swatches (Decision 19 applies, correctly) + a Semantics label so colour never
  rides alone; `_lastData` stale-guard AND `identical(future, _future)` both present; mounted-after-
  await on every path; messenger/navigator captured pre-await. All 4 hand-fakes (calendar, home_shell,
  widget ×2) threaded, both ContactsApp sites updated. NO Slice-B leak (no Task/create_task/tasks-repo
  /join touched) — a scope check worth repeating on any A-then-B split.
- **Join-table 2nd occurrence — m2m link + copy-not-generalize picker** (task↔task_categories =
  Slice B / Decision 40, Jul 15; clean, 0 blocking). Near-verbatim mirror of `task_contacts` (entry
  above). Migration: join table composite-PK (no id/timestamps/`deleted_at`), both FKs
  `on delete cascade`, reverse index, RLS `using (true)` SELECT + `grant select` only (no write
  policy/grant — RPC-only). Both task-write RPCs drop+CR on the arity change, and **the drop targets
  matched the CURRENT (latest-in-chain) signatures** — `create_task(text,text,uuid[],smallint)` /
  `update_task(uuid,text,boolean,text,uuid[],smallint)` from add_importance, not the original
  create. `p_categories` DEFAULTED on create / REQUIRED on update = fail-loud on a stale caller;
  `security definer` + `set search_path = public` verbatim; Decision-36 lockdown re-issued on the NEW
  5-/7-arg sigs. Model: `copyWith` categories defaults to `this.categories` (toggle-preservation),
  `fromJson` skips a null embed (soft-deleted category → null → skip), `toRpcParams` sends the
  `p_categories` id-list, doc-comment swept. Screen: the new picker was CLONED not generalized —
  consistent with Slice A's copy-not-refactor call, so not a finding; mounted-guard after await;
  colour never rides alone (row chip + detail row + picker tile + InputChip all carry `Text(name)`).
  Threaded through all 4 tasks_list sites + detail (screen + view + forward-to-form) + home_shell.
  Tests: the exact `toRpcParams` map got `p_categories:[]`; reconstructing fakes threaded categories
  through create/archive/restore in BOTH stateful-fake files — the **4th recurrence** of the
  field-vanishes-in-a-fake pattern (notes → contacts → importance → categories); the new picker test
  covers load/search/select/return/empty/error.
- **Cross-cutting RPC-arity retrofit** (idempotent `create_*` = Decision 41 / issue #9, Jul 16;
  clean, 0 blocking). All 7 `create_*` gain a trailing `p_id uuid default null` in ONE drop+recreate
  migration. Win conditions verified: every DROP matched the CURRENT (latest-in-chain) old signature;
  every revoke+grant listed the NEW signature (the D38 lockdown invariant, re-issued on the
  recreate); the two-trailing-defaulted-uuid `create_event (…, uuid, uuid)` = `p_type_id` then
  `p_id`, both correct and in order. `create_task_comment`'s replay-vs-archived-parent split is
  sound: `insert … select … where exists (live parent) … on conflict do nothing` plus a post-insert
  `if not exists (id = v_id) then raise no_data_found` — which correctly covers all three cases
  (idempotent replay, archived-first, and created-live-then-parent-archived-then-retried). Client:
  a single mint point `lib/util/ids.dart`; `.draft` const-ctor → id-minting factory (drops the
  `id=''` sentinel); `p_id` rides in `toRpcParams`, so the 4 SPREAD-update repos correctly DROP their
  now-redundant explicit `p_id` while task update (an explicit map) is rightly untouched; 5
  pop-on-success forms use `late final _pendingId`, and `CommentsSection`'s mutable `_pendingId` is
  reset AFTER success inside the op — throw-before-reset means a retry reuses the id, which is the
  actual dedupe payoff. Zero empty-id sentinels left in `lib/`; full doc-comment + database.md rule
  #2 + Decision 41 sweep clean (no stale "server owns id" / "DB assigns" prose).
- **Superset-merge widget extraction** (`DetailField` from two `_Field`s = issue #10 item 2 /
  Decision 43, Jul 16; clean, 0 blocking). Merging two variant private widgets into one shared
  superset — the trap is a PIXEL or BEHAVIOUR diff between the two originals surviving the merge.
  Verified: both `_Field` trees were byte-identical (pad-bottom 20, icon 20 `onSurfaceVariant`,
  SizedBox 16/2, `labelMedium` label, `bodyLarge` value), and contact's non-empty
  `copyWith(color:null)` == event's plain `bodyLarge` (no flatten diff). The RELAXED assert
  `child == null || value == null` (both-null ALLOWED, both-non-null forbidden) is both required and
  safe: contact's dob passes value=null/no-child (both-null — the OLD event assert would have tripped
  it), and no call site passes both. Behavioural-drift check: the merged widget adds an
  empty→"Not added" branch the event original lacked, but every event caller guards non-empty
  (`if location!.isNotEmpty` / `if notes!.isNotEmpty`), `_whenLabel` always returns non-empty, and
  Type uses `child` → the empty branch is unreachable for events, so no blank→"Not added" drift.
  New `super.key` idiomatic; no identity-dependent call site. 5 contact + 4 event sites are all
  keyword args → mechanical rename; grep confirmed 0 leftover `_Field`; the new file imports only
  `material.dart` (child/TypeLabel passed by caller); no orphaned imports in either screen.
- **Rules/config CR-scoping slice** (`.coderabbit.yaml` `path_filters` + doc-updater lifecycle rule =
  Decision 44, Jul 16; clean, 0 blocking). No app code. Win conditions: `path_filters` sits under
  `reviews:` at 2-space indent alongside its siblings; negation-ONLY globs (`!**/*.md` +
  `!.claude/**`) mean exclude-those-keep-everything-else — the CR idiom, which does NOT collapse to
  exclude-all (the finding that would otherwise fire); `path_instructions` untouched. doc-updater's
  DO-NOT renumbered #9→#10 with a #5-vs-#10 cross-link (whether-to-doc vs which-word); the lifecycle
  verify-command table is accurate for a squash-merge repo (`git ls-remote --heads`, `gh pr view
  --json state` = MERGED, `git log origin/main --grep '(#N)'`). Decision 44's gap-over-43 carries an
  HTML comment naming the concurrent branch (PR #51) — sane, transient, outside the diff's control.
  Stale-surface sweep: the "authoritative gate" / "reviews the PR" lines are about WHICH-PR not
  WHICH-FILES, so they aren't contradicted; only CLAUDE.md:53 needed the scoping clause.
- **Docs-only verify-curl backfill** (soft-delete non-destructiveness = issue #19 / Decision 45,
  Jul 17; REVISE — 2 ISSUEs, both doc-sync stale surfaces, zero findings in the curls/SQL/decision
  text). The SQL-and-shell half is the reusable win condition. Annotations must match real output
  **including the cast**: `-tA` psql of `select id, deleted_at is not null` prints `t`, but a
  `(deleted_at is not null)::text` in a union prints `true` — the slice got both right, which is
  exactly where an annotation copied from the `task_categories` precedent would have been wrong.
  Payload arity checked against the LATEST signature in the chain: `create_event`'s first 8 params
  are required (only `p_type_id`/`p_id` default), and `events_time_valid` forces
  `p_all_day:true` ⇒ both times null — the plan flagged both as "silently break every check" traps
  because the `EID=$(curl … | tr -d '"')` idiom swallows a 400 error body into the variable, so a
  mis-built payload yields a block that runs green and proves nothing; the fix is an `echo "$ETID /
  $EID"` uuid sanity assertion, which was present. Standalone-ness: each new block re-declares its
  `ANON=`/`REST=` preamble and mints its own ids rather than borrowing a var from an earlier block
  (the events block mints its own contact instead of reusing a `$NID` that an earlier block
  soft-deletes — which would have quietly gutted the "anon sees the attendee rows" annotation).
  Decision 45 itself: append-only, correctly numbered after D44, and reinforces rather than
  contradicts D36/D37. The general lesson: **a verification check must be able to fail** — an anon
  read against a policy that hides the row can't tell survival from erasure, so a privileged psql
  read is the only honest witness.
