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

## Verified literals (cross-cutting — READ source before asserting; per-slice detail → topic file)
- `EventType` / `TaskCategory` invalid-hex fallback: **`#888888`**. `hexFromColor` emits **lowercase**.
- Initial-load error copy + Retry `OutlinedButton`: events **`"Couldn't load events"`**, contacts
  **`"Couldn't load contacts"`**, tasks **`"Couldn't load tasks"`**, task categories **`"Couldn't
  load task categories"`**.
- Refresh-failure banner (list screens): **`"Couldn't refresh — showing saved data"`**.
- Empty contact-detail field placeholder: **`"Not added"`** (rendered per empty field, both layouts).
- **M3 `InputChip` delete icon is `Icons.clear`** (U+0E168), NOT `Icons.cancel` — tap via
  `find.descendant(of: widgetWithText(InputChip, name), matching: byIcon(Icons.clear))`;
  `ensureVisible` it first (People/Categories sections sit low on the form).
- Per-slice literal blocks (DetailField, ContactPicker, Importance, TaskCategory, Tasks M2M, Tasks v0,
  Comments) → [verified-literals](topics/verified-literals.md). Read before testing any of those.

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
- [Verified literals](topics/verified-literals.md) — verbose per-slice literal blocks (DetailField,
  ContactPicker, Importance, TaskCategory, Tasks M2M/v0, Comments).
- [Screen & widget testing notes](topics/screen-testing-notes.md) — per-slice traps & adequate-coverage
  calls: CommentsSection, tasks_list stale-guard, task_detail view-first, home_shell sidebar, contacts
  master-detail + search header.
