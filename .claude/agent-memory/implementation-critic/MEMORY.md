# implementation-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring
> implementation deviations vs the approved plan for THIS project so future pre-commit reviews
> focus where builds actually drift. Curated at `/wrapup`.

## Recurring deviations (none logged yet)
_First run pending. Seed watch-items carried from the project's conventions:_
- After an `await` in a `State`, is there `if (!mounted) return` before touching `context`/`setState`?
- `startMin`/`endMin` math — right unit (minutes from midnight, `0..1439`), both null iff `allDay`?
- Nullable model fields dereferenced without a guard (`Event.startMin`/`endMin`/`type`, `Contact.dob`)?
- Repository/model signature change → is the hand-written `_FakeXRepo` in `test/` updated too?
- Fallbacks match sibling code (`EventType` bad-hex → `#888888`; `toWrite()` empty → null)?
- `FutureBuilder` screens keep the `_lastData` stale-guard (failed refresh keeps stale data)?

## Positive signals (all clean pre-commit, 0 blocking — distilled lessons)
- **Template-port slices** (contacts/event_types write-RPCs = Decision 26 Slices 1–2; event-comments
  section): when a slice ports a green template, diff the two side-by-side and confirm the divergences
  are only entity-specific — the security posture (`security definer`+`set search_path=public`,
  `deleted_at` guard + `no_data_found`, grant signatures matching param lists, NEW fn = no CREATE OR
  REPLACE chain) must be byte-for-byte. A verbatim copy of an existing green load pattern's
  `_lastData`/mounted checks tends to be right — verify the copy is faithful, don't re-derive.
- **Divergent (rule-reversing) slice** (comment write-RPCs = Decision 26 Slice 3): win condition is
  doc-sweep completeness + per-entity divergences, NOT template-match — body-only `update` builds its
  param map EXPLICITLY (never spreads `toRpcParams()`, which would carry an extra arg → PGRST202);
  uuid-return soft-delete + `_fetchOne` (because `using(true)` keeps the archived row selectable);
  `restore` guards `deleted_at is NOT null` (inverse). Rule-reversal-sync sweep = every doc surface
  (database.md #2+#4, migration header, .coderabbit.yaml, README both surfaces, dated in-place
  Decision amendment).
- **New-entity-from-scratch slice** (Tasks v0 = Decision 27): even not-a-port, the win condition is the
  SAME per-project trap list — toRpcParams↔RPC arity (spread only the create shape; `update` builds
  params explicitly), mounted-after-await, `_lastData` stale-guard (PARTIAL: like contacts, no
  `identical(future,_future)` guard — a late older load can overwrite `_lastData`; known gap,
  log-&-watch), nested-gesture (circle `InkResponse` inside row `InkWell`; archived rows `onToggle:null`),
  migration `using(true)`+no-delete-grant. Not novel logic.
- **Infra / bash / SQL-only slices** (postgrest reload-after-migrate; DDL-watch triggers): trace quoting
  through every shell hop; confirm the NOTIFY channel/payload against PostgREST's contract; for event
  triggers confirm `returns event_trigger` + `execute function` + that `search_path=''` is safe ONLY when
  the body touches no objects. When a slice removes a "redundant" reload, check the cold-start/first-load
  path, not just steady state.
- **Config / asset slices** (app-icon): pixel-sample corner-vs-center alpha rather than trusting the
  PNG colortype / SVG header — that's what catches the transparent-glyph-vs-opaque-tile split.

## Durable, verified facts (load-bearing)
- **`CREATE EVENT TRIGGER` does NOT fire `ddl_command_end`** (proven locally on postgres:15/16:
  creating a second event trigger while `pgrst_ddl_watch` was active emitted no NOTICE; only
  `CREATE TABLE` did). Consequence: the `20260712120000_pgrst_ddl_watch.sql` migration emits ZERO
  `NOTIFY pgrst` during its OWN application. On a FRESH homebase where PostgREST is already up with
  an empty cache, applying all migrations does not reload it — every endpoint 404s until a
  `docker restart firstapp-postgrest` (or the next DDL). This is why `deploy-homebase.sh` keeps a
  single UNCONDITIONAL `notify pgrst` at the end as a cold-start net (the triggers own the
  running/steady-state + ad-hoc-psql case; the script one-liner owns fresh-DB cold start). General
  lesson: when a slice removes a "redundant" reload/refresh, check the cold-start/first-load path,
  not just the steady state.

## Known false-positive traps (do not flag these)
- An internal event-trigger / NOTIFY-only function pinning `set search_path = ''` (not `= public`)
  is CORRECT — rule #6's `= public` is for SECURITY DEFINER client-facing RPCs. Don't demand `=
  public` on a non-definer function that references no schema objects.
- Missing `auth.uid()` / login checks are expected pre-auth (issue #3) — not a defect.
- `with check (true)` policies and RPCs granted to `anon` are intentional pre-auth.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a dropped-function regression.
- Hard `DELETE` on the annotated `event_attendees` join is allowed; soft-delete is only required
  on mutable entity tables.
