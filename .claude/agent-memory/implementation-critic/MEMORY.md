# implementation-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring
> implementation deviations vs the approved plan for THIS project so future pre-commit reviews
> focus where builds actually drift. Curated at `/wrapup`.

## Recurring deviations (none logged yet)
_First run pending. Seed watch-items carried from the project's conventions:_
- After an `await` in a `State`, is there `if (!mounted) return` before touching `context`/`setState`?
- `startMin`/`endMin` math — right unit (minutes from midnight, `0..1439`), both null iff `allDay`?
- Nullable model fields dereferenced without a guard (`Event.startMin`/`endMin`/`type`, `Contact.dob`)?
- Repository/model signature change → is the hand-written `_FakeXRepo` in `test/` updated too?
- Fallbacks match sibling code (`EventType` bad-hex → `#888888`; `toWrite()` empty → null)?
- `FutureBuilder` screens keep the `_lastData` stale-guard (failed refresh keeps stale data)?
- **`toRpcParams` shape-change → stale sibling comment (WATCHING, count 1 — Task notes slice):** when
  a scalar field is added to `toRpcParams()`, the repo's `create()` doc-comment that quotes the OLD
  literal (`draft.toRpcParams() is exactly {p_title}`) goes stale in the SAME file as the change.
  Minor (SUGGESTION), but it's the doc-comment-sweep discipline in miniature — grep the entity's repo
  for a comment quoting the pre-change param literal whenever the create shape grows.
- **State-lift-vs-`widget.x` trap (WATCHING, count 1 — Decision 29 view-first Tasks):** a thin
  Scaffold host whose AppBar title/state claims (in a comment) to track the LIVE entity but reads
  `widget.task`/`widget.contact` (frozen at push) while the mutation lives in the child body via
  `onChanged`. If the host title has a state-dependent split (`'Task'`/`'Archived task'`), the host
  must seed `late _task` and `setState` it in `onChanged` — otherwise an in-place archive/restore
  flips the BODY (Restore-only) but leaves the AppBar stale, contradicting the comment. Const-title
  hosts (ContactDetailScreen = `'Contact'`) are immune, which is why the pattern was safe until a
  dynamic title was introduced.

## Positive signals (all clean pre-commit, 0 blocking — distilled lessons)
- **Scalar-field-add slice** (Task notes = Decision 27 follow-on): adding one optional `text` column
  end-to-end. Win condition traps, all verified clean here: (1) migration is drop-old-signature +
  create-or-replace-new for BOTH create+update (arity change → PGRST203 without the drop), bodies
  VERBATIM plus the field, `nullif(trim(p_notes),'')` normalization in both, grants re-issued on the
  NEW signatures (`create_task(text,text)`/`update_task(uuid,text,boolean,text)`), soft_delete/restore
  untouched so their grants stand. (2) The clear-path is the subtle one: form passes `_notes.text`
  (`''` when cleared) → `copyWith(notes:'')` OVERRIDES (empty string is non-null, so `notes ?? this.notes`
  keeps the `''`) → repo sends `p_notes:''` → server `nullif`→NULL → `_fetchOne` returns null → detail
  hides. The `notes ?? this.notes` keep-branch is only reached by `_toggleDone` (omits notes → null →
  kept). Both paths correct; the doc-comment on copyWith correctly states it can't represent an explicit
  clear and doesn't need to. (3) Keyed-remount stale-notes is a NON-issue: the detail `_edit` does
  in-place `setState(()=>_task=updated)` after the pushed form pops, so notes refresh regardless of the
  `id:isArchived:isDone` key (notes deliberately NOT in key — an edit that changes only notes needs no
  remount because setState already reseeded). (4) Every reconstructing test fake (create/archive/restore
  in the two `_StatefulTasksRepo`s) threads `notes` through; update fakes store the passed task verbatim.
  mounted-after-await present in `_save`.
- **Template-port slices** (contacts/event_types write-RPCs = Decision 26 Slices 1–2; event-comments
  section): when a slice ports a green template, diff the two side-by-side and confirm the divergences
  are only entity-specific — the security posture (`security definer`+`set search_path=public`,
  `deleted_at` guard + `no_data_found`, grant signatures matching param lists, NEW fn = no CREATE OR
  REPLACE chain) must be byte-for-byte. A verbatim copy of an existing green load pattern's
  `_lastData`/mounted checks tends to be right — verify the copy is faithful, don't re-derive.
- **Divergent (rule-reversing) slice** (comment write-RPCs = Decision 26 Slice 3): win condition is
  doc-sweep completeness + per-entity divergences, NOT template-match — body-only `update` builds its
  param map EXPLICITLY (never spreads `toRpcParams()`, which would carry an extra arg → PGRST202);
  uuid-return soft-delete + `_fetchOne` (because `using(true)` keeps the archived row selectable);
  `restore` guards `deleted_at is NOT null` (inverse). Rule-reversal-sync sweep = every doc surface
  (database.md #2+#4, migration header, .coderabbit.yaml, README both surfaces, dated in-place
  Decision amendment).
- **New-entity-from-scratch slice** (Tasks v0 = Decision 27): even not-a-port, the win condition is the
  SAME per-project trap list — toRpcParams↔RPC arity (spread only the create shape; `update` builds
  params explicitly), mounted-after-await, `_lastData` stale-guard (initially copied contacts WITHOUT
  the `identical(future,_future)` guard; cloud-CR PR #30 flagged it → guard ADDED, now matches
  `event_types_screen`), nested-gesture (circle `InkResponse` inside row `InkWell`; archived rows `onToggle:null`),
  migration `using(true)`+no-delete-grant. Not novel logic.
- **Widget-extraction / master-detail slices** (Contacts master-detail = Decision 28 Slice B): a
  shared body widget (`ContactDetailView`, no Scaffold, `onChanged`/`onDeleted` callbacks, NEVER pops)
  + thin phone wrapper (owns Scaffold+PopScope+pop). Win condition = the extraction preserves every
  async-safety invariant verbatim: (1) the plan-critic CRITICAL was `key: ValueKey(selected.id)` so a
  parent-driven selection swap REMOUNTS the pane (`_contact` seeded once in initState) — confirm the key
  is present and keyed by the resolved-selected id, not the raw param. (2) snackbar shown ONCE, in the
  body on the root messenger, host only navigates — no double/missing toast. (3) discarded_futures
  handling is context-sensitive: `discarded_futures: true` fires in SYNC bodies only (initState, the
  `(_){…}` onDeleted closure → needs `unawaited(_load())`), NOT in async methods (`_openForm`/`_openDetail`
  bare `_load()` OK — `unawaited_futures` not enabled); an arrow `(_) => _load()` returns the future so
  it's not "discarded". (4) id-resolution stays dependency-free `where(...).isEmpty ? first : first`
  (no package:collection — `depend_on_referenced_packages` would fail the gate). (5) selection highlight
  = `primaryContainer`/`onSurface`/`onSurfaceVariant` theme tokens (chrome, not colour-as-data). Note:
  `_edit`'s `setState` after `await Navigator.push` has no `if(!mounted)return` but is PRE-EXISTING and
  provably safe (the pushed form is a modal route over the whole tree, so the pane can't be disposed mid-await) — not a regression, do not cry-wolf.
  Tasks master-detail (Decision 28 Slice D) is the faithful sibling port: `TaskEditView` (Scaffold-less,
  `onChanged` never pops, `showHeader` for the pane) + thin `TaskFormScreen` StatelessWidget wrapper
  (`onChanged: (_) => Navigator.pop(true)` — setState-then-sync-pop in `_save` is safe: setState runs while
  mounted before the pop). Verified-clean traps: (a) both `_save` AND `_runMutation` reset `_saving=false`
  BEFORE `onChanged` (pane-freeze fix); (b) pane key remounts on archive/restore because
  the `archive`/`restore` repo methods `_fetchOne` the mutated row so `result.isArchived` actually flips →
  `_onEditorChanged` reselects that id. Cloud-CR #32 grew the key to `${id}:${isArchived}:${isDone}` so a
  list-toggled completion also remounts the open editor, AND made `_onEditorChanged` update `_lastData`
  optimistically (insert-if-new / replace-by-id) before `unawaited(_load())` — valid because `_load()` runs
  its sync prefix (sets `_future`) before the rebuild, so the FutureBuilder waiting-branch renders the
  optimistic `_lastData`, then the newest future reconciles to server truth via the `identical` guard.
  Key-contract trap: the BINDING key doc-comment lives on `TaskEditView` in `task_form_screen.dart`, NOT the
  list screen — a key change is a mini rule-reversal whose sibling doc-comment must sync in the SAME slice
  (watch for it still citing a stale 2-part `id:isArchived` key); (c) `_resolveSelected` = selected-if-present → first ACTIVE → null
  (never auto-opens completed/archived), stale `_selectedId` falls through safely; `_creatingNew` survives
  `_load()` (untouched by it). Plan-SANCTIONED minor (do NOT cry-wolf): the selected-row highlight is
  `ColoredBox(primaryContainer)` wrapping the `InkWell` (not Contacts' `ListTile selected:`), so the tap ripple
  is masked on an ALREADY-selected row — cosmetic only (re-tapping a selected row is a no-op; unselected rows
  ripple fine); the plan explicitly specced "ColoredBox/Ink". RefreshIndicator over the two-pane `Row` with two
  ListViews is the proven Contacts structure — no assertion.
- **Pure-UI / adaptive-layout slices** (desktop sidebar = Decision 28 Slice A): no async → `mounted`/
  `_lastData` traps are N/A; the win condition is theme-token fidelity, not repo/SQL posture. Checklist:
  (1) every colour from `Theme.of(context).colorScheme` (no ad-hoc hex; `Colors.transparent` is fine) and
  it's chrome, not entity data (colour-as-data is only about EventType colours); (2) selection styling
  matches the sibling shipped theme tokens it claims to mirror — for the sidebar, `navigationRailTheme`:
  primaryContainer chip + onSurface/onSurfaceVariant + w600/w500; (3) no fixed height around a
  textScaler-growing Text (padding + `Flexible`+ellipsis is the pattern; a fixed square is OK ONLY with
  `TextScaler.noScaling` inside, as the `C⁺` brand glyph does); watch for a non-`Flexible` Text in a
  fixed-width Row (e.g. the `CRM+` wordmark) as a latent extreme-textScaler horizontal overflow —
  SUGGESTION, not a gate (wide area is ≥640, so realistic overflow needs an extreme scaler).
  `_TasksHeader` already wraps both its title and numeric active count in `Flexible` inside the
  `Expanded` group (like Contacts' `_MasterHeader`), so it's overflow-safe. (4) index assumptions (Settings = `length-1`) safe vs the real `_destinations`
  order + the `IndexedStack` body order. Passing a static-const list as a widget param instead of the
  plan's literal 2-arg ctor is a harmless decoupling, not an item-10 signature break (no repo fake).
- **Infra / bash / SQL-only slices** (postgrest reload-after-migrate; DDL-watch triggers): trace quoting
  through every shell hop; confirm the NOTIFY channel/payload against PostgREST's contract; for event
  triggers confirm `returns event_trigger` + `execute function` + that `search_path=''` is safe ONLY when
  the body touches no objects. When a slice removes a "redundant" reload, check the cold-start/first-load
  path, not just steady state.
- **Config / asset slices** (app-icon): pixel-sample corner-vs-center alpha rather than trusting the
  PNG colortype / SVG header — that's what catches the transparent-glyph-vs-opaque-tile split.

## Durable, verified facts (load-bearing)
- **`CREATE EVENT TRIGGER` does NOT fire `ddl_command_end`** (proven locally on postgres:15/16:
  creating a second event trigger while `pgrst_ddl_watch` was active emitted no NOTICE; only
  `CREATE TABLE` did). Consequence: the `20260712120000_pgrst_ddl_watch.sql` migration emits ZERO
  `NOTIFY pgrst` during its OWN application. On a FRESH homebase where PostgREST is already up with
  an empty cache, applying all migrations does not reload it — every endpoint 404s until a
  `docker restart firstapp-postgrest` (or the next DDL). This is why `deploy-homebase.sh` keeps a
  single UNCONDITIONAL `notify pgrst` at the end as a cold-start net (the triggers own the
  running/steady-state + ad-hoc-psql case; the script one-liner owns fresh-DB cold start). General
  lesson: when a slice removes a "redundant" reload/refresh, check the cold-start/first-load path,
  not just the steady state.

## Known false-positive traps (do not flag these)
- An internal event-trigger / NOTIFY-only function pinning `set search_path = ''` (not `= public`)
  is CORRECT — rule #6's `= public` is for SECURITY DEFINER client-facing RPCs. Don't demand `=
  public` on a non-definer function that references no schema objects.
- Missing `auth.uid()` / login checks are expected pre-auth (issue #3) — not a defect.
- `with check (true)` policies and RPCs granted to `anon` are intentional pre-auth.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a dropped-function regression.
- Hard `DELETE` on the annotated `event_attendees` join is allowed; soft-delete is only required
  on mutable entity tables.
