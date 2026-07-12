# test-writer — memory

> Transition tracker, curated in place (never a dated session log). Records durable test
> conventions for THIS project + false-positive traps so future runs write correct tests fast.
> Curated at `/wrapup`.

## The fake pattern (durable — this project's whole test approach)
- **Hand-written private fake repos**, injected via the screen/widget **constructor**. NO mockito,
  NO mocktail, NO build_runner, NO generated mocks, NO `__tests__/` folder.
- A fake `implements` the abstract repo interface and overrides all **four** methods
  (`fetchAll` / `create` / `update` / `softDelete`). Unused methods may `throw UnimplementedError()`
  but the `@override` must exist. Canonical shapes live in `test/calendar_screen_test.dart` and
  `test/event_types_screen_test.dart` — copy them verbatim.
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
- Refresh-failure banner (list screens): **`"Couldn't refresh — showing saved data"`**.
- `_CommentsSection` (event_detail_screen.dart) inline load error: **`"Couldn't load comments."`**
  (note trailing period); Retry is a `TextButton` (inline, not the list-screen `OutlinedButton`).
- `_CommentsSection` refresh-failure snackbar: **`"Couldn't refresh comments — showing saved data"`**
  (distinct copy from the list screens — has the word "comments").
- Comment composer/edit buttons are `FilledButton` labelled **`Comment`** / **`Save`**; both gate on
  `!_busy && controller.text.trim().isNotEmpty` → assert `.onPressed == null` when empty/whitespace.

## Recurring coverage gaps (none logged yet)
_First run pending. Seed watch-items from conventions:_
- New stateful screen without a **stale-load** (`_OrderedRepo`) or **refresh-failure**
  (`_RefreshFailsRepo`) test.
- New model nullable branch (soft-deleted embed → `type == null`) without a null-case assertion.
- New util helper without a boundary / bad-input test.

## Positive signals
- **Tests backstop the `setState(() => Future)` trap** — they caught it in both `fa4fc45` and
  `3a87cc8` when `flutter analyze` still missed it. The `discarded_futures` lint (enabled `0e4a7af`)
  is now the primary mechanical catch; keep the load/refresh-failure + button-gating branches
  covered on every new stateful section as regression coverage. (PROMOTED, count 2.)
- `_CommentsSection` (private widget in event_detail_screen.dart) is tested through its host
  `EventDetailScreen` with 3 inert repo fakes + a real `_FakeCommentsRepo` (has a `throwOnFetch`
  toggle — flip it AFTER the initial pump to drive a failed *refresh*, or set it true before pump
  for a failed *initial load*). No separate `_RefreshFailsRepo`/`_OrderedRepo` needed here.
- **Design note (why no `_OrderedRepo` out-of-order test for `_CommentsSection`):** its reloads run
  through `_run`, which sets `_busy=true` and disables every action button while a load is in flight,
  so two user-triggered reloads can't overlap. The stale-guard's catch branch (`identical(future,
  _future)` + failed-refresh snackbar) IS covered by the `throwOnFetch`-after-pump test; the
  success-branch out-of-order overwrite is already covered on the shared pattern in
  `event_types_screen_test.dart`. Not a gap — do not flag it.

## Repo internals are NOT faked at the SupabaseClient level (do not force a test)
- Repos (`Supabase*Repository`) are faked at the **interface** for screen tests, never at the
  `SupabaseClient` level. So an RPC-write swap inside a real repo impl (e.g. `create`/`update` →
  `_client.rpc(...)` + a `_fetchOne` re-select, as in `contacts_repository.dart` commit `1988e26`)
  has **no in-convention unit test** — the `_fetchOne` re-select path can only be exercised against
  real Postgres (done in the migration verification), not `flutter test`. Correct to say "out of
  convention, not written" rather than invent a SupabaseClient fake. Interface unchanged → existing
  screen/`widget_test.dart` fakes still hold and need no edit.
- `Contact.toRpcParams()` (replaced `toWrite()`): trims `p_name` client-side; sends `p_email`/
  `p_phone`/`p_company`/`p_remarks` **raw** (server `nullif(trim(...))` owns empty→null); `p_dob` via
  `ymd()` or null; omits id + server timestamps (repo adds `p_id` for updates). When testing a
  `toRpcParams`/`toWrite` map, assert the **full key set** and every optional passthrough — a dropped
  or mis-keyed field (e.g. `p_phone`) otherwise slips through.

## Known false-positive traps (do not flag / do not do)
- Pure presenter widgets in `lib/widgets/` (`EmptyState`, `TypeLabel`, `InitialsAvatar`) need no
  tests — do not flag them as missing coverage.
- There is **NO `EventAttendee` model** — attendees are `List<Contact>`; don't test a type that
  doesn't exist.
- Don't add a mock dependency or edit `lib/` to make a test pass — fakes only; flag untestable code.
