# Screen & widget testing notes (per-slice)

On-demand detail moved out of MEMORY.md. Durable per-screen traps and adequate-coverage calls.

## `CommentsSection` (public shared widget, `lib/widgets/comments_section.dart`)
- Extracted from the old private `_CommentsSection` (event_detail_screen) in Slice 2a, commit
  078d03c — now **public + parent-agnostic** (`CommentsSection(repository, parentId)`). Canonical
  test file `test/comments_section_test.dart` drives it two ways:
  - (a) **through host `EventDetailScreen`** — 3 inert repo fakes + a real `_FakeCommentsRepo` with a
    `throwOnFetch` toggle: flip it AFTER the initial pump for a failed *refresh*, set true before pump
    for a failed *initial load*. No separate `_RefreshFailsRepo`/`_OrderedRepo` needed here.
  - (b) **standalone** — mounted directly in `MaterialApp > Scaffold > SingleChildScrollView` with an
    arbitrary task-shaped `parentId` ('task-42'), proving parent-agnosticism ahead of Slice 2b's task
    reuse. Assert the `parentId` flows through `Comment.draft` into the persisted row via
    `fetchFor(parentId)`, and that a sibling parent's comment ('e1') does NOT leak in.
- **Rule:** when a shared widget's whole reason for extraction is cross-parent reuse, add a direct
  standalone mount with a NON-default parentId — host-only tests can't prove it isn't secretly coupled.
- **Why no `_OrderedRepo` out-of-order test:** reloads run through `_run`, which sets `_busy=true` and
  disables every action button while a load is in flight, so two user-triggered reloads can't overlap.
  The stale-guard catch branch (`identical(future, _future)` + failed-refresh snackbar) is covered by
  the `throwOnFetch`-after-pump test; the success-branch out-of-order overwrite is covered on the
  shared pattern in `event_types_screen_test.dart`. Not a gap — do not flag it.

## `tasks_list_screen` stale-guard — RESOLVED (cloud-CR PR #30, 2026-07-12)
- `TasksListScreen._load` HAS the `identical(future, _future)` guard (matching `event_types_screen`) —
  added in response to a cloud CodeRabbit finding. A late older load can't overwrite `_lastData`.
- Still NO "showing saved data" refresh banner: a failed refresh shows the FULL `_ErrorState` (unlike
  `event_types`, which keeps stale + snackbars). So the `event_types` `_RefreshFailsRepo` test would go
  RED here — do NOT port it. Only the success-path `_OrderedRepo` stale-guard test is portable.

## `task_detail_screen` view-first (Decision 29)
- Two classes: `TaskDetailView` (shared read-body, no Scaffold, reports up via `onChanged`) and
  `TaskDetailScreen` (thin phone wrapper = AppBar + `PopScope`). The VIEW is covered exhaustively
  (read/Complete↔Reopen/Archive→Restore/Edit-pushes-form/failure snackbars) in the same file.
- The WRAPPER's distinct behaviour was the real gap: (1) its `PopScope` `_dirty` back-signal —
  `canPop:false` + a deferred `Future.microtask(navigator.pop(_dirty))` — pops **true** only after an
  `onChanged` fired, **false** otherwise; (2) the lifted `_task` retitles the AppBar 'Task'→'Archived
  task' on in-place archive. To test the pop RESULT: push `TaskDetailScreen` from a Builder host,
  `await Navigator.push<Object?>` into a captured var, then `tester.tap(find.byType(BackButton))` +
  pumpAndSettle (the microtask settles) and assert the captured result. Added 3 wrapper tests (cfbfe7f).
- `SubtleButton` (lib/widgets/) is a pure presenter atom — no test (DO NOT #3); both branches
  (`icon==null` → `FilledButton`, else `FilledButton.icon`) are exercised through the detail tests.

## `home_shell` sidebar (Decision 28, adaptive nav)
- `HomeShell` puts all four screens in an `IndexedStack`; finders skip non-selected children (offstage),
  so a screen's own content text is `findsNothing` until that destination is selected — use that to
  disambiguate a sidebar label from the destination's own content of the same word.
- `_Sidebar` renders the **first N-1 destinations in a loop** but **Settings (last) separately** after a
  `Spacer()`, wired to `onSelect(lastIndex)` — a DISTINCT code path from the looped items. Worth its own
  test: tap "Settings" sidebar label → assert the Settings screen's "Event types" row appears.
- Adequate coverage = wide-shows-sidebar+switch, narrow-shows-NavigationBar, pinned-Settings-selects.
  The `primaryContainer` selected fill is pure styling — do NOT assert (DO NOT #4); a Calendar tap is
  redundant with Tasks (same loop path) — do NOT pad with it.

## `contacts` master-detail (Decision 28 Slice B)
- Two panes keyed off content width `kTwoPaneBreakpoint` (640). Drive layout with
  `tester.binding.setSurfaceSize(const Size(1100, 800))` (wide) / `Size(360, 800)` (narrow) +
  `addTearDown(() => tester.binding.setSurfaceSize(null))`. Wide = in-place `ContactDetailView`
  (no Scaffold, reports via `onChanged`/`onDeleted`); narrow = tap pushes `ContactDetailScreen` (thin
  Scaffold+PopScope wrapper). Disambiguate: `find.byType(ContactDetailView)` vs `ContactDetailScreen`.
- Identity trap: a contact's **name** and **company** render in BOTH the list tile subtitle and the
  pane. Use a **detail-only** field — `remarks` renders only in the pane. Absence of contact #2's remark
  on load pins auto-select to `contacts.first`; presence after tapping #2 pins the keyed remount.
- Adequate coverage = wide-auto-select-first + wide-in-place-swap-no-push + wide-"Not added" +
  narrow-push. The `ListTile.selected` highlight is pure styling — do NOT assert. The in-place-swap test
  already covers "selecting a different contact updates the pane" — do NOT add a second remount test.

## `contacts` desktop-top search header (Decision 28 Slice C)
- Wide drops the phone AppBar+FAB; the master pane grows a `_MasterHeader` (title + live `count` + "New"
  `FilledButton` + a `TextField`). Verified literals: `_NoMatches` = `EmptyState` title **`"No matches"`**,
  message `"No contacts match your search."`; ✕-clear = an `IconButton` with **tooltip `"Clear"`**
  (`find.byTooltip('Clear')`) shown only when the box is non-empty; header button label **`New`**.
- Search (`_matches`) filters ONLY the list rows (name/company/email, null-guarded); the pane resolves
  its selection against the FULL list, so filtering never changes the pane. To prove the filter use a
  **list-only** field — Alan's email renders only in his row subtitle (he isn't the auto-selection), so
  its disappearance on `enterText('Ada')` pins the filter.
- `_NoMatches` identity trap: when `filtered.isEmpty` the `_ContactsList` is gone, so the auto-selected
  contact's **name** now renders ONLY in the pane — `find.text('Ada Lovelace')` findsOneWidget proves
  the pane kept its selection while the list shows "No matches".
- Adequate coverage = wide-header-replaces-chrome + search-filters-rows-not-detail + ✕-clear-restores +
  no-match-shows-_NoMatches-pane-holds-selection + narrow-unchanged. The clear-search-on-New reset is
  real but NOT worth a test (driving the full `ContactFormScreen` re-tests form plumbing) — skip.
