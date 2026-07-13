# Desktop-adaptive slices (Decision 28) — semantic review detail

All three were reviewed CLEAN. Shared invariant across the master-detail work: the detail
`selected` resolves by id against the **full** contacts list (`where(id==_selectedId).isEmpty ?
first : first` — total, empty guarded upstream), never against a filtered/derived list.

## Slice A — desktop sidebar (`home_shell.dart` `_Sidebar`, commit 4679504)
`NavigationRail` → stateless `_Sidebar`; `_index`/`_select` + `IndexedStack` bodies untouched, so
tab state round-trips. Selection maps 1:1: `_destinations` order == `IndexedStack` child order
(Contacts0·Calendar1·Tasks2·Settings3); Settings pinned via `lastIndex = length-1`, loop
`for(i<lastIndex)` renders 0..2 then Settings. All colour from `colorScheme` (chrome, not data).
No async → `mounted`/`_lastData` N/A. **Finder note (fragile, not a bug):** test taps
`find.text('Tasks')` while `TasksListScreen`'s AppBar title is ALSO `'Tasks'`; works only because
that screen is the offstage `IndexedStack` child and `find.text` defaults `skipOffstage:true`. A
future `skipOffstage:false` or a layout that stops offstaging non-selected children breaks it
("matched 2 widgets").

## Slice B — master-detail extraction (`contact_detail_screen.dart` + list, commit 16ed89e)
`ContactDetailScreen` split into a thin phone Scaffold+PopScope wrapper (owns `_dirty`, pops) + a
Scaffold-less `ContactDetailView` that NEVER pops, reports up via `onChanged`/`onDeleted`.
(1) `key: ValueKey(selected.id)` → parent selection swap remounts the pane (initState re-seeds
`_contact`/`_deleting`); an in-place `_edit` keeps the same id → no remount → view's `_contact` is
the single source of truth (no double-source vs the reloaded list). (2) snackbar shown ONCE in
`_confirmDelete` on the ROOT messenger before `onDeleted`; both hosts' `onDeleted` navigate only →
no double/missing toast; survives host close. (3) `_lastData` stale-guard preserved. (4)
`mounted`-after-`await` on every path incl. the newly guarded `_edit`. Phone imperative `pop(true)`
after delete is safe under `canPop:false` because `onPopInvokedWithResult`'s `if(didPop)return`
short-circuits the imperative pop.

## Slice C — desktop-top / search (`contacts_list_screen.dart`, commit 194ff12)
Wide header (`_MasterHeader` title+count+New over a live `TextField`) replaces AppBar/FAB; search
live-filters list rows only. (1) `selected` resolves against FULL `contacts`; `filtered` is a
SEPARATE derived list for rows — searching never mutates the detail pane, a filtered-out selection
stays shown, auto-select-first still works. (2) a filtered-out row can't be selected (not rendered);
`onTap` fires only for visible rows. (3) `_NoMatches` shows iff a non-empty query matches nothing.
(4) `build()` lifted to a top-level LayoutBuilder → Scaffold(appBar/FAB null on wide only) →
RefreshIndicator → FutureBuilder, all 3 states + `_lastData` stale-guard preserved. (5) `_search` is
a State-owned controller (dispose'd) so the ✕-clear and after-New reset update the VISIBLE box;
`_openForm` success does `setState{_selectedId=saved.id; _search.clear();}` then `_load()`. (6) no
new await paths; `mounted` guards intact, `onDeleted` `unawaited(_load())`.

## Consistent-by-design transients across B/C (NOT ISSUEs — do NOT escalate)
The `_lastData` no-spinner-flash stale-guard means the cached list lingers for one reload window.
Manifestations, all self-healing: (B) after a desktop delete, if the deleted contact was
`contacts.first` the pane briefly re-shows it until the fetch drops the row; (C-after-New)
`_selectedId` falls back to old-first until the new row arrives; (C-search) fresh wide screen, no
prior selection, searching a NON-first contact shows `contacts.first` in the detail until a filtered
row is tapped ("resolve against full list + auto-select-first" contract). Also benign in C:
`hasQuery` uses raw (untrimmed) text so a spaces-only query shows the ✕ but filters nothing (`q` is
trimmed); per-keystroke `setState(() {})` rebuilds the FutureBuilder subtree with the SAME `_future`
(no refetch) — cheap-for-small-lists, same class as the comments-slice watch item.
