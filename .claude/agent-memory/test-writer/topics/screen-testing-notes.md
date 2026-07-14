# Per-slice screen testing notes (test-writer)

Read on demand. Durable "how to test THIS screen / what's a non-gap" notes, one section per slice.
MEMORY.md keeps one-line pointers here.

## `CommentsSection` (public shared widget, `lib/widgets/comments_section.dart`)
- Extracted from the old private `_CommentsSection` (event_detail_screen) in Slice 2a, commit
  `2717da9` — now **public + parent-agnostic** (`CommentsSection(repository, parentId)`). Canonical
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
- **`_busy` re-entrancy mid-write** IS testable despite a synchronously-resolving fake: add an optional
  `Completer<void>? archiveGate` to `_FakeCommentsRepo` (archive awaits `gate.future` when set) →
  tap Archive, `pump()` once to flush `setState(_busy=true)`, then assert `onPressed == null` on the
  composer `FilledButton('Comment')` (seed composer text first so only `_busy` can disable it) AND the
  tile's `Edit`/`Archive` `TextButton`s; `gate.complete()` + `pumpAndSettle` proves it resolves and
  re-enables. Covered 2026-07-14.
- **Inline-edit Cancel** (`_action('Cancel', … _cancelEdit)`, a `TextButton`): tap Edit, `enterText`
  a change into `TextField.last`, tap Cancel → assert `FilledButton('Save')` gone (view mode restored),
  the typed text `findsNothing`, the ORIGINAL body `findsOneWidget` (edit discarded, never persisted).
  Covered 2026-07-14.
- **Why no `_OrderedRepo` out-of-order test:** reloads run through `_run`, which sets `_busy=true` and
  disables every action button while a load is in flight, so two user-triggered reloads can't overlap.
  The stale-guard catch branch (`identical(future, _future)` + failed-refresh snackbar) is covered by
  the `throwOnFetch`-after-pump test; the success-branch out-of-order overwrite is covered on the
  shared pattern in `event_types_screen_test.dart`. Not a gap — do not flag it.

## `CommentsSection` read-only mode + task wiring (Slice 2b, 2026-07-14)
- New `readOnly` bool param (default false — event caller unaffected). Gates: composer row
  (`if (!widget.readOnly)`), `_viewBody` `Edit`/`Archive` actions, `_archivedTile` `Unarchive`.
  The live/archived split and "Show archived" toggle STILL work in read-only — assert bodies
  render but the mutating `TextButton`s are `findsNothing`; composer gone = `find.byType(TextField)`
  findsNothing AND `find.widgetWithText(FilledButton,'Comment')` findsNothing. Always pair with a
  `readOnly:false` contrast test (same seed) so the assertion proves the gate, not a missing seed.
  Standalone helper takes an optional `readOnly` param — reuse it, don't fork a second helper.
- **`taskCommentsRepository`** is now a SECOND required `CommentsRepository` on `ContactsApp` AND
  `HomeShell` (parallel to the event `commentsRepository`) — every call site of those two in tests
  needs BOTH. `TaskDetailScreen`/`TaskDetailView`/`TasksListScreen` gained a required
  `commentsRepository`. Inert fake (fetchFor→`const []`, add→draft, edit→arg, archive/unarchive→
  `Comment.draft(parentId:'',body:'')`) suffices where comments aren't exercised.
- Task detail wires `CommentsSection(readOnly: _isArchived)` below the actions: LIVE task → composer
  present (`FilledButton('Comment')` + one `TextField`); ARCHIVED task → section present, read-only,
  no composer. Seed the fake via `fetchFor` (filter by parentId == task.id) and assert the body shows.
- **`readOnly` keys ONLY off `_isArchived`, NOT `isDone`** — a COMPLETED-but-live task
  (`isDone:true, deletedAt:null`) STILL gets the composer (design: live/completed are commentable).
  Assert it: seed a done task + a comment, expect status pill `'Completed'` AND
  `FilledButton('Comment')` present. Added to `task_detail_screen_test` 2026-07-14.
- **Same-State readOnly flip regression** (the in-place-archive editor leak, fixed 2b): the tile gates
  the editor on `(editing && !widget.readOnly)` AND `didUpdateWidget` clears `_editingId` on a
  false→true readOnly flip. To drive it you need the SAME `CommentsSection` State to survive the flip
  (a key-swap remount would reset `_editingId` for free and prove nothing). Use a tiny host
  `StatefulWidget` that holds `bool _readOnly` in ITS state and rebuilds the section in place on a
  `setState` (no key change → element reused → `didUpdateWidget` fires). Open the editor, tap the host's
  flip button, assert `Save`/editor `TextField` GONE + body still shows. This test goes RED against
  the pre-fix `child: editing ? _editBody : _viewBody` — verified 2026-07-14. In `comments_section_test.dart`.
- **Wide tasks pane comments** (`tasks_list_screen_test`): the existing `_screen`/`_pumpWide` helpers
  hardcoded an inert comments repo — thread an optional `CommentsRepository?` through both and add a
  seedable `_SeededCommentsRepo` (fetchFor filters by parentId) to prove the pane's embedded
  `CommentsSection` loads. First ACTIVE task auto-selects → live composer; selecting an ARCHIVED row
  (expand `ARCHIVED`, tap it) remounts the pane read-only via its `ValueKey('$id:$isArchived:$isDone')`
  → composer gone. Import `widgets/comments_section.dart` for the `find.byType`.

## `tasks_list_screen` stale-guard — RESOLVED (cloud-CR PR #30, 2026-07-12)
- `TasksListScreen._load` HAS the `identical(future, _future)` guard, matching `event_types_screen`
  (a late older load can't overwrite `_lastData`). Added per a cloud CodeRabbit finding.
- Screen still has NO "showing saved data" refresh banner: a failed refresh shows the FULL
  `_ErrorState` (unlike `event_types`, which keeps stale + snackbars). So the `event_types`
  `_RefreshFailsRepo` test would go RED here — do NOT port it. Only the success-path `_OrderedRepo`
  stale-guard test is portable, if coverage of the guard is wanted later.

## `task_detail_screen` view-first (Decision 29)
- Two classes: `TaskDetailView` (shared read-body, no Scaffold, reports up via `onChanged`) and
  `TaskDetailScreen` (thin phone wrapper = AppBar + `PopScope`). The VIEW is covered exhaustively
  (read/Complete↔Reopen/Archive→Restore/Edit-pushes-form/failure snackbars) in the same file.
- WRAPPER's distinct behaviour was the real gap: (1) its `PopScope` `_dirty` back-signal —
  `canPop:false` + a deferred `Future.microtask(navigator.pop(_dirty))` — pops **true** only after an
  `onChanged` fired (so the phone list reloads), **false** otherwise; (2) the lifted `_task` retitles
  the AppBar 'Task'→'Archived task' on in-place archive. To test the pop RESULT: push
  `TaskDetailScreen` from a Builder host, `await Navigator.push<Object?>` into a captured var, then
  `tester.tap(find.byType(BackButton))` + pumpAndSettle (the microtask settles), assert the capture.
  Added 3 wrapper tests (2026-07-14, commit cfbfe7f).
- `SubtleButton` (lib/widgets/) is a pure presenter atom — no test (DO NOT #3); both branches
  (`icon==null` → `FilledButton`, else `FilledButton.icon`) are exercised through the detail tests
  (Edit has no icon; Complete/Archive/Restore do). Do not pad a widget test for it.

## Task `notes` (optional freeform scalar, commit `4d3d6b8`)
- Model/form/detail/list coverage shipped in the commit is thorough. The one real add: a widget test
  that a **Complete toggle keeps notes visible** end-to-end (the shipped "Complete marks it done"
  test used a task WITHOUT notes, so the `_toggleDone → copyWith(isDone:) → update echo → re-seed
  _task → re-render notes` chain wasn't guarded as a composite). Added to `task_detail_screen_test`.
- NON-gaps (do not pad): **multi-line** notes = `Text(_task.notes!)` renders `\n` natively, no
  behavioral diff from the single-line assertion. **Wide desktop pane** notes = the SAME shared
  `TaskDetailView` body + identical `if (_task.notes != null && isNotEmpty)` block regardless of host.
  **Archived-notes read-only** already covered ("an archived task still shows its notes").

## `home_shell` sidebar (Decision 28, adaptive nav)
- `HomeShell` puts all four screens in an `IndexedStack`; finders skip non-selected children (offstage),
  so a screen's own content text (e.g. `ContactsListScreen` "New contact", `SettingsScreen`
  "Event types") is `findsNothing` until that destination is selected. Use that to disambiguate a
  sidebar label from the destination's own AppBar/content of the same word.
- `_Sidebar` renders the **first N-1 destinations in a loop** but **Settings (last) separately** after
  a `Spacer()`, wired to `onSelect(lastIndex)`. That pinned-at-bottom index math is a DISTINCT code
  path — a Tasks/Calendar tap does NOT cover it. Own test: tap "Settings" sidebar label → assert the
  Settings screen's "Event types" row appears. (Added.)
- Adequate coverage = wide-shows-sidebar+switch, narrow-shows-NavigationBar, pinned-Settings-selects.
  The `primaryContainer` selected-state fill is pure styling — do NOT assert (DO NOT #4); a Calendar
  tap is redundant with Tasks (same loop path) — do NOT pad.

## `contacts` master-detail (Decision 28 Slice B)
- Two panes keyed off content width `kTwoPaneBreakpoint` (640). Drive layout with
  `tester.binding.setSurfaceSize(const Size(1100, 800))` (wide) / `Size(360, 800)` (narrow) +
  `addTearDown(() => tester.binding.setSurfaceSize(null))`. Wide = in-place `ContactDetailView`
  (reports up via `onChanged`/`onDeleted`); narrow = tap pushes `ContactDetailScreen` (thin wrapper).
  Disambiguate: `find.byType(ContactDetailView)` (embedded pane) vs `find.byType(ContactDetailScreen)`
  (route pushed).
- Identity trap: a contact's **name**/**company** render in BOTH the list tile (subtitle =
  `company · email`) and the pane, so they can't prove WHICH contact the pane shows. Use a
  **detail-only** field — e.g. `remarks` ("Bombe.") only renders in the pane. Absence of contact #2's
  remark on load pins auto-select to `contacts.first`; presence after tapping #2 pins the keyed
  remount (`ValueKey(selected.id)` → `_contact` re-seeded in initState).
- Adequate coverage = wide-auto-select-first + wide-in-place-swap-no-push + wide-"Not added" +
  narrow-push. `ListTile.selected`/`selectedTileColor` highlight is pure styling — do NOT assert
  (DO NOT #4). "Selecting a different contact updates the pane" is covered by the in-place-swap test
  — do NOT add a second remount test.

## `contacts` desktop-top search header (Decision 28 Slice C)
- Wide drops the phone AppBar+FAB; the master pane grows a `_MasterHeader` (title + live `count` +
  "New" `FilledButton` + a `TextField`). Verified literals: `_NoMatches` = `EmptyState` title
  **`"No matches"`**, message `"No contacts match your search."`; ✕-clear = an `IconButton` with
  **tooltip `"Clear"`** (`find.byTooltip('Clear')`) shown only when the box is non-empty; header
  button label **`New`** (`find.widgetWithText(FilledButton, 'New')`).
- Search (`_matches`) filters ONLY the list rows (name/company/email, null-guarded); the detail pane
  resolves its selection against the FULL list, so filtering never changes the pane. To prove the
  filter, use a **list-only** field — Alan's email `alan@bletchley.uk` renders only in his row
  subtitle (he isn't the auto-selection), so its disappearance on `enterText('Ada')` pins the filter.
- `_NoMatches` identity trap: when `filtered.isEmpty` the `_ContactsList` is gone, so the
  auto-selected contact's **name** now renders ONLY in the pane — `find.text('Ada Lovelace')`
  findsOneWidget proves the pane kept its selection while the list shows "No matches".
- Adequate coverage = wide-header-replaces-chrome + search-filters-rows-not-detail + ✕-clear-restores
  + no-match-shows-_NoMatches-pane-holds-selection + narrow-unchanged. The clear-search-on-New reset
  (`_openForm` → `_search.clear()`) is NOT worth a test: driving the full `ContactFormScreen`
  push/fill/save re-tests form plumbing more than the search behaviour — skip, not a gap.
