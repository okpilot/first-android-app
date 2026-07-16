# Verified literals — per-slice detail

> READ source before asserting; extend, never re-guess. MEMORY.md keeps the cross-cutting one-liners
> + a pointer here; this file holds the verbose per-slice blocks.

## DetailField (`lib/widgets/detail_field.dart`, extracted shared row for Contact/Event detail)
Four branches in priority order — `child` slot wins, else empty(`value==null||isEmpty`)→muted
**`"Not added"`**, else `selectable`→`SelectableText`, else plain `Text`. Ctor `assert(child==null ||
value==null)` (both → `throwsAssertionError`, test with a bare `test()` not `testWidgets`). Only
"Not added" was covered transitively (contacts_master_detail); selectable + XOR-assert had zero
coverage → direct `test/detail_field_test.dart` (7 tests) written per the `importance_marks_test`
precedent (shared widget mounted only through hosts → standalone mount). Not a presenter false-
positive: it's logic-bearing (branch selection + guard).

## ContactPickerScreen (renamed from `event_picker_screen.dart`)
Role-noun AppBar: `title` is the lowercase noun (`'people'` / `'attendees'`). Copy = `n==0 ? 'Add
$noun' : '$nounCap · $n'` → **`"Add people"`** empty, **`"Attendees · 2"`** capitalized-with-count.
Rows are `CheckboxListTile`; Done is a `TextButton`. A `_FailingContactsRepo.fetchAll` MUST be `async`
(a bare `=> throw` throws synchronously in initState and crashes the build instead of yielding a
rejected Future).

## Importance (Decision 38)
`importanceName` → `0`=**None** / `1`=**Low** / `2`=**Medium** / `3`=**High** (out-of-range → None).
`importanceMarks`: `''` at ≤0, else `'!'*level` clamped to 3. `importanceColor` returns null for
level 0 / out-of-range; light≠dark per level (tuned). Marker glyphs: `'!'` / `'!!'` / `'!!!'`. Form
picker segment 0 label is **`None`**; picking a `!`/`!!`/`!!!` seg then save carries the level.
`ImportanceMarks` renders `SizedBox.shrink` (no Text) at level 0; `muted:true` (done/archived rows)
halves the glyph color alpha (`.a`≈0.5, same r/g/b) — assert via `tester.widget<Text>(...).style!.
color!.a` with `closeTo`. **`ImportanceMarks` a11y label** `"Importance <name>"` MERGES with the
child glyph's own semantics (Semantics not `excludeSemantics`) → match with `find.bySemanticsLabel(
RegExp('Importance High'))`, NOT an exact-string label. Active-task sort by importance is
**server-side** (`tasks_repository` PostgREST `.order('importance', desc)`), NOT re-sorted in Dart →
out of the interface-fake convention, no unit test (the fake returns the list as-given). Standalone
widget test: `test/importance_marks_test.dart`.

## TaskCategory / TaskCategoriesScreen (Slice A, commit `9377a61`)
Parallel of EventType/EventTypesScreen. Model: `fromJson` valid `#RRGGBB` / invalid-hex fallback
**`#888888`** (8-digit ARGB, shorthand, non-string, null, absent key all fall back); `toRpcParams()`
= `{p_name (trimmed), p_color}` no id; `copyWith(name, colorHex)`. Screen load-error copy **`"Couldn't
load task categories"`** + Retry `OutlinedButton`; refresh banner reused **`"Couldn't refresh —
showing saved data"`**; save-failure snackbar **`"Couldn't save — please try again"`**; delete-failure
**`"Couldn't delete — please try again"`**. Editor FilledButton label = `Add category` (new) / `Save
changes` (edit); AppBar `Save` TextButton. Swatch grid = `_SwatchGrid` reusing `kEventTypePalette`;
tap a colour with **`find.bySemanticsLabel('<PaletteName>')`** (Blue/Teal/Green/Amber/Orange/Red/
Purple/Pink) — the `Semantics(label: s.name)` wraps the InkWell. `hexFromColor` emits **lowercase**
alpha-stripped (Teal `#2fa090`, NOT `#2FA090`) — assert lowercase on recolour. Test file:
`test/task_categories_screen_test.dart` (fakes: `_FakeCategoriesRepo`, `_RefreshFailsRepo`,
`_OrderedRepo`, added `_FailingCategoriesRepo` + `_CreateFailsRepo`).

## Tasks ↔ task_categories M2M (Slice B, commit `d95f85b`, Decision 40)
Mirrors task↔contacts People. `Task.categories` = `List<TaskCategory>` (full embed); `copyWith`
preserves (toggle-safety), `fromJson` skips a null/RLS-hidden category, `toRpcParams` adds
`p_categories` (id-list). Form `_CategoriesSection` mirrors `_PeopleSection`: seed chips, `InputChip`
delete icon = `Icons.clear` (ensureVisible first — section sits low), removal drops the id from the
save; picker button label **`Add categories`** (`OutlinedButton`), picker rows `CheckboxListTile` +
`Done` `TextButton`. Detail `_CategoriesList` header **`CATEGORIES · N`**, rendered ONLY when
non-empty (parallels `PEOPLE · N`). List `_toggleDone` = `copyWith(isDone:)` → carries categories
through (widget-level proof mirrors the People toggle test).

## Tasks (v0)
List load-error copy **`"Couldn't load tasks"`** + Retry `OutlinedButton`; list toggle-failure
snackbar **`"Couldn't update — please try again"`**; active-empty-with-history inline note **`"All
clear — no active tasks."`** (only when `completed`/`archived` non-empty — full `EmptyState` "No tasks
yet" only when ALL three groups empty). Form titles: `New task` / `Edit task` / `Archived task`; form
snackbars `"Couldn't save — please try again"` / `"Couldn't archive — please try again"` / `"Couldn't
restore — please try again"`. Archived tile `onToggle:null` (not completable) — tap the row title →
form in Restore mode.

## Comments
`CommentsSection` inline load error: **`"Couldn't load comments."`** (trailing period); Retry is an
inline `TextButton` (not the list-screen `OutlinedButton`). Refresh-failure snackbar: **`"Couldn't
refresh comments — showing saved data"`** (has "comments", unlike the list screens). Composer/edit
buttons are `FilledButton` labelled **`Comment`** / **`Save`**; both gate on `!_busy &&
controller.text.trim().isNotEmpty` → assert `.onPressed == null` when empty/whitespace.
