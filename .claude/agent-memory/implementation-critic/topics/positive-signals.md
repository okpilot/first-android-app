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
