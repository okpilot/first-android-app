# test-writer — memory

> Transition tracker, curated in place (never a dated session log). Records durable test
> conventions for THIS project + false-positive traps so future runs write correct tests fast.
> Curated at `/wrapup`.

## The fake pattern (durable — this project's whole test approach)
- **Hand-written private fake repos**, injected via the screen/widget **constructor**. NO mockito,
  NO mocktail, NO build_runner, NO generated mocks, NO `__tests__/` folder.
- **Reusable fakes now live in `test/support/fakes.dart`** (extracted, commit after `ee50b55`) —
  PUBLIC classes `FakeContactsRepo` / `FakeEventsRepo` (has `lastCreated`) / `FakeEventTypesRepo` /
  `FakeTaskCategoriesRepo` / `FakeTasksRepo` (inert) / `StatefulTasksRepo` (mutating, captures
  `lastUpdated`/`archivedId`/`restoredId`) / `ThrowingTasksRepo` (all writes throw) / `FakeCommentsRepo`
  (inert) / `SeededCommentsRepo` (fetchFor filters by parentId, add round-trips `c0/c1…`). A fake
  belongs here once its body duplicates across ≥2 test files. **Import `'support/fakes.dart'` and reuse
  before writing a new local fake.** Single-file specials — load-error (`_Failing*Repo`), ordering
  (`_OrderedRepo`), full-CRUD recording (`_RecordingTasksRepo`, `_FlakyRecordingTasksRepo`), gated —
  stay LOCAL to the one test. Seeds are positional (`FakeXRepo(seed)`); capture fields are public.
- A fake `implements` the abstract repo interface and overrides all **four** methods
  (`fetchAll` / `create` / `update` / `softDelete`). Unused methods may `throw UnimplementedError()`
  but the `@override` must exist. Canonical shapes live in `test/support/fakes.dart`,
  `test/calendar_screen_test.dart` and `test/event_types_screen_test.dart` — copy them verbatim.
- Concurrency/failure fakes: **`_RefreshFailsRepo`** (call-counter: data on call 0, `throw` after →
  stale-keeps + failure banner) and **`_OrderedRepo`** (fresh `Completer` per fetch → out-of-order
  resolution proves stale load can't overwrite newer `_lastData`). A throw-on-`fetchAll`
  `_FailingRepo` drives the initial-load error state.
- Widget tests: `MaterialApp(theme: AppTheme.light, home: <screen with injected fakes>)`. Model/util
  tests: bare `test(...)` / `group(...)`, no `MaterialApp`. Imports: `package:first_android_app/...`.
- Run before finishing: `~/flutter/bin/flutter test <file>` (flutter NOT on PATH). Leave it GREEN.

## Verified literals (READ source before asserting — extend this list, never re-guess)
- `EventType` invalid-hex fallback: **`#888888`**.
- Calendar initial-load error copy: **`"Couldn't load events"`**; Retry is an `OutlinedButton`.
- Contacts initial-load error copy: **`"Couldn't load contacts"`**; Retry `OutlinedButton`.
- Empty contact-detail field placeholder: **`"Not added"`** (rendered per empty field, both layouts).
- Refresh-failure banner (list screens): **`"Couldn't refresh — showing saved data"`**.
- `CommentsSection` inline load error: **`"Couldn't load comments."`** (trailing period); Retry is an
  inline `TextButton` (not the list-screen `OutlinedButton`). Refresh-failure snackbar:
  **`"Couldn't refresh comments — showing saved data"`** (has "comments", unlike the list screens).
- Comment composer/edit buttons are `FilledButton` labelled **`Comment`** / **`Save`**; both gate on
  `!_busy && controller.text.trim().isNotEmpty` → assert `.onPressed == null` when empty/whitespace.
- **`ContactPickerScreen`** (renamed from `event_picker_screen.dart`) role-noun AppBar: `title` is the
  lowercase noun (`'people'` / `'attendees'`). Copy = `n==0 ? 'Add $noun' : '$nounCap · $n'` →
  **`"Add people"`** empty, **`"Attendees · 2"`** capitalized-with-count. Rows are `CheckboxListTile`;
  Done is a `TextButton`. A `_FailingContactsRepo.fetchAll` MUST be `async` (a bare `=> throw` throws
  synchronously in initState and crashes the build instead of yielding a rejected Future).
- **M3 `InputChip` delete icon is `Icons.clear`** (U+0E168), NOT `Icons.cancel` — to tap a People/
  attendee chip's delete: `find.descendant(of: widgetWithText(InputChip, name), matching:
  byIcon(Icons.clear))`, and `ensureVisible` it first (the People section sits low on the form).
- **Importance (Decision 38)** literals: `importanceName` → `0`=**None** / `1`=**Low** / `2`=**Medium** /
  `3`=**High** (out-of-range → None). `importanceMarks`: `''` at ≤0, else `'!'*level` clamped to 3.
  `importanceColor` returns null for level 0 / out-of-range; light≠dark per level (tuned). Marker
  glyphs: `'!'` / `'!!'` / `'!!!'`. Form picker segment 0 label is **`None`**; picking a `!`/`!!`/`!!!`
  seg then save carries the level. `ImportanceMarks` renders `SizedBox.shrink` (no Text) at level 0;
  `muted:true` (done/archived rows) halves the glyph color alpha (`.a`≈0.5, same r/g/b) — assert via
  `tester.widget<Text>(...).style!.color!.a` with `closeTo`. **`ImportanceMarks` a11y label**
  `"Importance <name>"` MERGES with the child glyph's own semantics (Semantics not `excludeSemantics`)
  → match with `find.bySemanticsLabel(RegExp('Importance High'))`, NOT an exact-string label. Active-
  task sort by importance is **server-side** (`tasks_repository` PostgREST `.order('importance', desc)`),
  NOT re-sorted in Dart → out of the interface-fake convention, no unit test (the fake returns the list
  as-given). Standalone widget test: `test/importance_marks_test.dart`.
- **TaskCategory / TaskCategoriesScreen (Slice A, commit `9377a61`)** — parallel of EventType/
  EventTypesScreen. Model: `fromJson` valid `#RRGGBB` / invalid-hex fallback **`#888888`** (8-digit
  ARGB, shorthand, non-string, null, absent key all fall back); `toRpcParams()` = `{p_name (trimmed),
  p_color}` no id; `copyWith(name, colorHex)`. Screen load-error copy **`"Couldn't load task
  categories"`** + Retry `OutlinedButton`; refresh banner reused **`"Couldn't refresh — showing saved
  data"`**; save-failure snackbar **`"Couldn't save — please try again"`**; delete-failure
  **`"Couldn't delete — please try again"`**. Editor FilledButton label = `Add category` (new) /
  `Save changes` (edit); AppBar `Save` TextButton. Swatch grid = `_SwatchGrid` reusing
  `kEventTypePalette`; tap a colour with **`find.bySemanticsLabel('<PaletteName>')`** (Blue/Teal/Green/
  Amber/Orange/Red/Purple/Pink) — the `Semantics(label: s.name)` wraps the InkWell. `hexFromColor`
  emits **lowercase** alpha-stripped (Teal `#2fa090`, NOT `#2FA090`) — assert lowercase on recolour.
  Test file: `test/task_categories_screen_test.dart` (fakes: `_FakeCategoriesRepo`, `_RefreshFailsRepo`,
  `_OrderedRepo`, added `_FailingCategoriesRepo` + `_CreateFailsRepo`).
- **Tasks ↔ task_categories M2M (Slice B, commit `d95f85b`, Decision 40)** — mirrors task↔contacts
  People. `Task.categories` = `List<TaskCategory>` (full embed); `copyWith` preserves (toggle-safety),
  `fromJson` skips a null/RLS-hidden category, `toRpcParams` adds `p_categories` (id-list). Form
  `_CategoriesSection` mirrors `_PeopleSection`: seed chips, `InputChip` delete icon = `Icons.clear`
  (ensureVisible first — section sits low), removal drops the id from the save; picker button label
  **`Add categories`** (`OutlinedButton`), picker rows `CheckboxListTile` + `Done` `TextButton`.
  Detail `_CategoriesList` header **`CATEGORIES · N`**, rendered ONLY when non-empty (parallels
  `PEOPLE · N`). List `_toggleDone` = `copyWith(isDone:)` → carries categories through (widget-level
  proof mirrors the People toggle test). Coverage gaps I filled this session: form category
  remove-chip, detail no-CATEGORIES-when-empty, list toggle-preserves-categories (+3 → 222 green).
- **Tasks (v0)** literals: list load-error copy **`"Couldn't load tasks"`** + Retry `OutlinedButton`;
  list toggle-failure snackbar **`"Couldn't update — please try again"`**; active-empty-with-history
  inline note **`"All clear — no active tasks."`** (only when `completed`/`archived` non-empty — full
  `EmptyState` "No tasks yet" only when ALL three groups empty). Form titles: `New task` /
  `Edit task` / `Archived task`; form snackbars `"Couldn't save — please try again"` /
  `"Couldn't archive — please try again"` / `"Couldn't restore — please try again"`. Archived tile
  `onToggle:null` (not completable) — tap the row title → form in Restore mode.

## Recurring coverage gaps (watch-items)
- New stateful screen without a **stale-load** (`_OrderedRepo`) or **refresh-failure**
  (`_RefreshFailsRepo`) test.
- New model nullable branch (soft-deleted embed → `type == null`) without a null-case assertion.
- New util helper without a boundary / bad-input test.
- New **shared/extracted widget** whose purpose is cross-parent reuse, mounted only through one host —
  add a direct standalone mount with a NON-default parentId (see topic file).

## Positive signals
- **Tests backstop the `setState(() => Future)` trap** — caught it in `fa4fc45` and `3a87cc8` when
  `flutter analyze` still missed it. The `discarded_futures` lint (enabled `0e4a7af`) is now the
  primary mechanical catch; keep the load/refresh-failure + button-gating branches covered on every
  new stateful section as regression coverage. (PROMOTED, count 2.)

## Repo internals are NOT faked at the SupabaseClient level (do not force a test)
- Repos (`Supabase*Repository`) are faked at the **interface** for screen tests, never at the
  `SupabaseClient` level. So an RPC-write swap inside a real repo impl (e.g. `create`/`update` →
  `_client.rpc(...)` + a `_fetchOne` re-select, as in `contacts_repository.dart` commit `1988e26`)
  has **no in-convention unit test** — the `_fetchOne` re-select path can only be exercised against
  real Postgres (migration verification), not `flutter test`. Say "out of convention, not written"
  rather than invent a SupabaseClient fake. Interface unchanged → existing fakes hold, no edit.
- RPC param maps now live in the **repos** (each knows its own signature, `p_event_id` vs `p_task_id`),
  not the model — `Comment` dropped `toRpcParams()` in Slice 2a (commit `2717da9`), so there's no
  model-level param test for comments; the repo builds `{p_event_id, p_body}` inline.
- `Contact.toRpcParams()` (replaced `toWrite()`): trims `p_name` client-side; sends `p_email`/
  `p_phone`/`p_company`/`p_remarks` **raw** (server `nullif(trim(...))` owns empty→null); `p_dob` via
  `ymd()` or null; **includes `p_id`** (client-minted, Decision 41 — no longer omitted); omits server
  timestamps. When testing a `toRpcParams`/`toWrite` map, assert the **full key set** and every
  optional passthrough — a dropped or mis-keyed field (e.g. `p_phone`) otherwise slips through.

## Client-minted ids / idempotency (issue #9, Decision 41) — how to test
- Every model's **`.draft` is now a `factory` that mints a v4 uuid** via `newEntityId()` (`lib/util/
  ids.dart`) and accepts an optional `id` to reuse across a retry. The **5 entity-model**
  `toRpcParams()` maps now carry **`p_id`** (was omitted pre-Decision 41); `Comment` has NO
  `toRpcParams()` (dropped in Slice 2a) — its repos build `p_id` inline in `add()`. `create_*` RPCs
  insert it `on conflict (id) do nothing`, so a retry with the same id is a no-op, not a dup.
- Model-level: assert `Model.draft(...).id` is `isNotEmpty` AND `toRpcParams()['p_id'] == draft.id`
  (capture the instance — the id is random, can't hardcode). `test/util/ids_test.dart` proves
  `newEntityId` is a canonical v4 uuid + distinct across 1000 calls (uuid must be real or Postgres
  `uuid` col rejects it). WATCH: a model gaining `p_id` easily ships with the p_id assertion missing
  (Event shipped this way in Decision 41 — no event_test change in the diff; I added it).
- Form `_pendingId` reuse (the idempotency payoff): pop-on-success forms hold `late final _pendingId
  = newEntityId()`. Widget-test with a **flaky recording repo** (`create` records `draft.id` into a
  list, throws on call 0, succeeds on call 1): enter title → tap save (snackbar, stays) → tap save
  again → assert the two recorded ids are **equal** + non-empty. Mechanism identical across all 5
  forms; task_form covers it — testing every form would be padding.
- CommentsSection composer stays mounted, so its `_pendingId` is **mutable** and reset after each
  successful add. Test the reset with a repo recording `draft.id` per `add`: two back-to-back adds →
  assert the ids **differ** (else the 2nd collides + is conflict-skipped). Both comments must persist.

## Per-slice screen testing notes → [screen-testing-notes](topics/screen-testing-notes.md)
How to test / what's a non-gap, one section per slice: `CommentsSection` (shared, Slice 2a +
Slice 2b `readOnly`/task-wiring + `taskCommentsRepository` 2nd repo), `tasks_list_screen` stale-guard
(RESOLVED), `task_detail_screen` wrapper, task `notes`, `home_shell` sidebar, `contacts` master-detail
+ search header. Read it before testing any of those screens.

## Known false-positive traps (do not flag / do not do)
- Pure presenter widgets in `lib/widgets/` (`EmptyState`, `TypeLabel`, `InitialsAvatar`, `SubtleButton`)
  need no tests — do not flag them as missing coverage.
- There is **NO `EventAttendee` model** — attendees are `List<Contact>`; don't test a type that
  doesn't exist.
- Don't add a mock dependency or edit `lib/` to make a test pass — fakes only; flag untestable code.

## Topic pointers
- [Screen & widget testing notes](topics/screen-testing-notes.md) — per-slice traps & adequate-coverage
  calls: CommentsSection, tasks_list stale-guard, task_detail view-first, home_shell sidebar, contacts
  master-detail + search header.
