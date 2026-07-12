# semantic-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring semantic /
> behavioral bug patterns for THIS project so future reviews focus where logic actually breaks.
> Curated at `/wrapup`.

## Recurring semantic bugs
- **`setState(() => <expr that returns a Future>)`** (PROMOTED, count 2: Contacts `fa4fc45`,
  comments `3a87cc8`). The arrow discards the Future — async work fires but `setState` returns
  synchronously; `flutter analyze` did NOT flag it (legal void-context arrow) until the
  `discarded_futures` lint was enabled (`0e4a7af`) — that lint now mechanizes the catch. Fix =
  block body `setState(() { … })` and `await`/`unawaited` the call outside. Still worth a semantic
  flag on any new `setState(() => …)` whose callee returns a Future (belt-and-braces with the lint).

- **Form declares an entity read-only but leaves the write affordance live** (RESOLVED-WATCH,
  count 1, first seen Tasks `58b2b5d`; fixed & re-verified `258cb6c`). `TaskFormScreen` for an
  archived task used to hide the "Mark complete" toggle + swap in Restore but keep the title field
  editable and BOTH Save affordances (appBar + FilledButton) enabled → Save → `update_task` guarded
  to `deleted_at is null` → `no_data_found` → misleading "Couldn't save" (retry always fails). FIX
  (verified in `258cb6c`): both Save affordances gated `if (!_isArchived)`, title `readOnly:
  _isArchived`, `onFieldSubmitted` null when archived → `_save()` is now unreachable for an archived
  task, only Restore remains; test "an archived task is read-only…" asserts it. Keep watching new
  edit/detail forms that gate ONE affordance on a read-only flag but not the siblings (Save button +
  input field). Fix = gate ALL write affordances on the same flag.

_Seed watch-items carried from the project's conventions:_
- **`mounted`-after-`await`** — a new `await` in a `State` method that then touches `context` /
  `setState` must be followed by `if (!mounted) return;`. Watch every new await path.
- **`_lastData` stale-load race** — a late/stale `FutureBuilder` load must not overwrite newer data;
  a failed refresh keeps stale data. Check the guard survives any load rework.
- **`Event.fromJson` embeds** — `event_attendees[].contacts` and the `event_types` embed; a
  soft-deleted type → embed null → `type` null (must not crash). Attendees are `List<Contact>`;
  there is **no `EventAttendee` model**.
- **Minutes-from-midnight** — `startMin`/`endMin` both null iff `allDay`. Watch changes that break it.
- **RPC-only writes** — event writes go through `create_event`/`update_event`, deletes through
  `soft_delete_*`; check `toRpcParams()` passes the params the RPC signature expects.

## Positive signals
- **Desktop sidebar pure-UI slice (`home_shell.dart` `_Sidebar`, commit 4679504, Decision 28 Slice A)**
  — CLEAN. `NavigationRail` → stateless `_Sidebar`; `_index`/`_select` and the `IndexedStack` bodies
  are untouched, so tab state still round-trips (IndexedStack still owns the bodies). Selection index
  maps 1:1: `_destinations` order == `IndexedStack` child order (Contacts0·Calendar1·Tasks2·Settings3);
  Settings pinned via `lastIndex = length-1`, loop `for(i<lastIndex)` renders 0..2 then Settings —
  every `onSelect(i)` passes the right index. All colour from `colorScheme` (chrome, not entity data).
  No async → `mounted`/`_lastData` traps N/A. **Finder note (load-bearing, not a bug):** the test taps
  `find.text('Tasks')` while `TasksListScreen`'s AppBar title is ALSO `'Tasks'` — it works because that
  screen is the offstage `IndexedStack` child and `find.text` default `skipOffstage:true` drops it
  (verified: test passes). Correct but fragile — if a future test uses `skipOffstage:false` or the
  layout stops making non-selected children offstage, the tap breaks with "matched 2 widgets". Seeding
  one contact (avoids the empty-state button duplicating the FAB's 'New contact') is the right dedup.
- **Comments slice (`_CommentsSection`, commit 3a87cc8)** — the `_lastData` stale-guard
  (`identical(future, _future)`) holds even in the tricky initState-fetch-vs-user-add race (composer
  is enabled during the initial spinner, so a load can start before the first fetch resolves); the
  older fetch is correctly ignored. Mutation ops clear their controllers / null `_editingId` AFTER
  the `await` inside the op, so a failed write preserves the user's text and keeps edit mode open for
  retry. `_run` reuses the `_confirmDelete` idiom (capture messenger, `mounted` re-check, `busy` in
  `finally`). Reinforce this shape for new list/mutation sections.

## Watching
- **per-keystroke `setState`** — `_composer`/`_editController` listeners call a bare
  `setState((){})` that rebuilds the whole `FutureBuilder` + every tile + the `.where` live/archived
  filters on each keystroke. Cheap for small lists, idiomatic here; flag only if it recurs on a
  larger/perf-sensitive list. (WATCHING, count 1, first seen 3a87cc8.)
- **mutation entrypoints missing the `if (_busy) return` re-entrancy guard** — `_add`/`_saveEdit`
  guard `_busy` internally, but `_archive`/`_unarchive` rely solely on button-disable. Idempotent
  here (archive/unarchive just re-set `deleted_at`), so low risk. Watch for a non-idempotent mutation
  that takes this shape. (WATCHING, count 1, first seen 3a87cc8.)

## Positive signals (write-RPC ports)
- **Contacts write-RPC port (commit 1988e26, Decision 26 Slice 1)** — direct INSERT/UPDATE →
  `create_contact`/`update_contact` RPCs, verified behaviorally equivalent to the old `toWrite`
  path, not just structurally a port. The load-bearing checks for future `event_types`/`comments`
  ports: (1) server `nullif(trim(...),'')` reproduces the old client `_emptyToNull` **exactly** —
  both store the trimmed value or NULL, so no field silently changed normalization; (2) the RPC
  inserts/updates all 6 human columns the old map wrote — none dropped; (3) `id as String` cast is
  valid because the RPC `returns uuid` (scalar → JSON string); (4) `_fetchOne`'s `.single()` is
  correct (NOT a `maybeSingle` case): the just-written live row is visible under
  `contacts_select using (deleted_at is null)`, so 0 rows means something went wrong and SHOULD
  throw. Mirrors `SupabaseEventsRepository` byte-for-byte. When reviewing Slice 3, diff the new
  port against this shape and confirm the same 4 hold.
- **Event-types write-RPC port (commit 20970ea, Decision 26 Slice 2) — CONFIRMED, all 4 checks hold.**
  `create_event_type(p_name,p_color)` / `update_event_type(p_id,p_name,p_color)` are a single-def NEW
  migration (no CREATE OR REPLACE chain). Repo/model/screen structurally identical to contacts:
  `id as String` cast valid (RPC `returns uuid`); `update` refetches by input `type.id` not the RPC
  return; `_fetchOne` selects `_columns='id, name, color'` == `EventType.fromJson` field set exactly;
  `_save` catches → mounted-guard → `_saving=false` → snackbar, so `no_data_found` on a soft-deleted
  update row surfaces sensibly. Entity-specific deltas vs contacts (all legitimate): fewer params, no
  `nullif`/`_emptyToNull` normalization (event_types has no optional text fields), explicit column
  list vs contacts' bare `.select()`. `toWrite`→`toRpcParams` swept; only remaining `toWrite` is
  `Comment` (Slice 3, unconverted). Third straight clean port — reinforce the shape for Slice 3.
- **Comments write-RPC port (commit 3296258, Decision 26 Slice 3 — FINAL) — CONFIRMED clean, all 4
  checks hold, fourth straight clean port.** `create_comment(p_event_id,p_body)` /
  `update_comment(p_id,p_body)` (body-only, no `p_event_id` → an edit can't move a comment) /
  `soft_delete_comment(p_id)` / `restore_comment(p_id)` — all single-def NEW migration
  (`20260712150000`), no CREATE OR REPLACE chain. `id as String` cast valid (create_comment
  `returns uuid`); `_fetchOne` selects `_columns='id, event_id, body, created_at, updated_at,
  deleted_at'` == `Comment.fromJson` field set exactly (incl. `deleted_at` → `isArchived`); screen
  (`event_detail_screen.dart`) NOT in diff — interface unchanged, UI + fakes untouched. Guards match
  UI exactly: update/soft_delete guard `deleted_at is null` (UI edits/archives live tiles only),
  restore guards `deleted_at is not null` (UI unarchives archived tiles only); `no_data_found` raised
  before `_fetchOne` runs → thrown → surfaced by `_run`'s catch→snackbar.
- **KEY DELTA vs contacts/event_types (why `.single()` is safe here for a DIFFERENT reason):** under
  event_comments' `using (true)` SELECT policy an archived row STAYS selectable, so `_fetchOne`
  round-trips `isArchived` correctly on archive/unarchive AND the row can never vanish from
  `_fetchOne`'s view — strictly safer than the contacts/event_types ports (where a concurrent
  soft-delete could make `.single()` throw). So the "non-atomic re-fetch could throw on a concurrent
  soft-delete" caveat does NOT apply to comments — under `using(true)` no concurrent soft/restore can
  hide the just-written row from the re-select. Do NOT flag `.single()` here.
- **Non-atomic re-fetch is by-design, not a race bug** — RPC-then-`_fetchOne` is two round-trips
  (vs the old single `insert…returning`). A concurrent soft-delete between the two would make
  `.single()` throw instead of returning the row — but that is the correct error signal, matches
  the events repo, and is deliberate. Do NOT flag it as a stale-load/race finding.

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth (issue #3) — not a semantic defect,
  and DB-security is `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
