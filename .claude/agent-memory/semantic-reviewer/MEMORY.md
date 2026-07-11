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

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth (issue #3) — not a semantic defect,
  and DB-security is `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
