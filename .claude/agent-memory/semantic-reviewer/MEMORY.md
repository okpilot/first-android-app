# semantic-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring semantic /
> behavioral bug patterns for THIS project so future reviews focus where logic actually breaks.
> Curated at `/wrapup`. Verbose per-slice review detail lives in `topics/*.md`.

## Recurring semantic bugs
- **`setState(() => <expr that returns a Future>)`** (PROMOTED, count 2: Contacts `fa4fc45`,
  comments `3a87cc8`). The arrow discards the Future — async work fires but `setState` returns
  synchronously; `flutter analyze` did NOT flag it (legal void-context arrow) until the
  `discarded_futures` lint was enabled (`0e4a7af`), which now mechanizes the catch. Fix = block body
  `setState(() { … })` and `await`/`unawaited` outside. Still worth a semantic flag on any new
  `setState(() => …)` whose callee returns a Future (belt-and-braces with the lint).
- **Form declares an entity read-only but leaves a write affordance live** (RESOLVED-WATCH, count 1,
  Tasks `58b2b5d`; fixed & re-verified `258cb6c`). Archived `TaskFormScreen` hid the complete toggle
  but kept the title editable + BOTH Save affordances live → Save → `update_task` guarded
  `deleted_at is null` → `no_data_found` → misleading "Couldn't save" (retry always fails). Fix =
  gate ALL write affordances (Save button + input field + `onFieldSubmitted`) on the same read-only
  flag. Watch new edit/detail forms that gate ONE affordance but not its siblings.

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

## Watching
- **per-keystroke `setState((){})`** — a bare `setState` rebuilds the whole `FutureBuilder` + tiles +
  `.where` filters on each keystroke. Cheap for small lists, idiomatic here; flag only if it recurs on
  a larger/perf-sensitive list. (WATCHING, count 2: comments `3a87cc8`, contacts search `194ff12`.)
- **mutation entrypoints missing an `if (_busy) return` re-entrancy guard** — some ops guard `_busy`
  internally, others (`_archive`/`_unarchive`) rely solely on button-disable. Idempotent so far.
  Watch for a NON-idempotent mutation that takes this shape. (WATCHING, count 1, first seen 3a87cc8.)

## Positive signals (reviewed CLEAN — detail in topics)
- **Desktop-adaptive slices (Decision 28 A/B/C: sidebar 4679504, master-detail 16ed89e, desktop-top
  search 194ff12)** — [topics/desktop-adaptive-slices.md](topics/desktop-adaptive-slices.md). Detail
  `selected` always resolves by id against the FULL list; B/C `_lastData` lingers are
  consistent-by-design transients, NOT ISSUEs.
- **Decision 26 write-RPC ports (contacts 1988e26, event-types 20970ea, comments 3296258)** —
  [topics/write-rpc-ports.md](topics/write-rpc-ports.md). Reusable 4-check port shape; `.single()`
  and the non-atomic RPC-then-`_fetchOne` re-fetch are correct by design — do NOT flag as races.
- **Comments `_CommentsSection` (3a87cc8)** — `identical(future,_future)` stale-guard holds through
  the initState-fetch-vs-user-add race; mutation ops clear controllers/`_editingId` AFTER the await
  so a failed write preserves text + keeps edit mode open; `_run` = capture messenger + `mounted`
  re-check + `busy` in `finally`. Reinforce this shape for new list/mutation sections.

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth (issue #3) — DB-security is
  `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
