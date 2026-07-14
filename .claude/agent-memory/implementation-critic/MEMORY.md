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
- **`toRpcParams` shape-change → stale sibling comment (WATCHING, count 1 — Task notes slice):** when
  a scalar field is added to `toRpcParams()`, the repo's `create()` doc-comment that quotes the OLD
  literal (`draft.toRpcParams() is exactly {p_title}`) goes stale in the SAME file as the change.
  Minor (SUGGESTION), but it's the doc-comment-sweep discipline in miniature — grep the entity's repo
  for a comment quoting the pre-change param literal whenever the create shape grows.
- **State-lift-vs-`widget.x` trap (WATCHING, count 1 — Decision 29 view-first Tasks):** a thin
  Scaffold host whose AppBar title/state claims (in a comment) to track the LIVE entity but reads
  `widget.task`/`widget.contact` (frozen at push) while the mutation lives in the child body via
  `onChanged`. If the host title has a state-dependent split (`'Task'`/`'Archived task'`), the host
  must seed `late _task` and `setState` it in `onChanged` — otherwise an in-place archive/restore
  flips the BODY (Restore-only) but leaves the AppBar stale, contradicting the comment. Const-title
  hosts (ContactDetailScreen = `'Contact'`) are immune, which is why the pattern was safe until a
  dynamic title was introduced.

## Positive signals (all clean pre-commit, 0 blocking) — one line each; full lessons in topic file
See [positive-signals](topics/positive-signals.md) for the per-slice-type win conditions. Index:
- **Scalar-field-add** (Task notes, Dec 27): drop+CR both RPCs on arity change; `nullif(trim,'')`
  clear-path; `copyWith(notes:'')` overrides via non-null empty string; test fakes thread the field.
- **Template-port** (contacts/event_types/event-comments write-RPCs, Dec 26 S1–2): diff vs green
  template; security posture must be byte-for-byte; new fn = no CR-chain.
- **Shared-widget second-consumer** (task_comments, Dec 33 / Slice 2b): faithful twin of
  event_comments (table+4 RPCs in one file) + `readOnly` gating (default false → events untouched);
  alias `parent_id:task_id` select-only; second repo threaded end-to-end, NO cross-wiring.
- **Divergent (rule-reversing)** (comment write-RPCs, Dec 26 S3): `update` builds params EXPLICITLY
  (no spread → PGRST202); restore guards `is NOT null`; full rule-reversal doc-sweep.
- **New-entity-from-scratch** (Tasks v0, Dec 27): same per-project trap list; `_lastData` needs the
  `identical(future,_future)` guard (cloud-CR #30 caught its absence).
- **Widget-extraction / master-detail** (Contacts Dec 28 S-B; Tasks S-D): shared Scaffold-less body +
  thin wrapper; `ValueKey(id:isArchived:isDone)` remount; snackbar once; discarded_futures context-
  sensitive; binding key doc-comment lives on the *EditView*, syncs in same slice.
- **Pure-refactor extraction** (CommentsSection, Dec 2a): byte-equivalent behaviour; only the rename
  axis differs; every async invariant survives verbatim; grep no dangling old names.
- **Pure-UI / adaptive-layout** (desktop sidebar, Dec 28 S-A): theme-token fidelity; colours from
  `colorScheme` = chrome; `Flexible`+ellipsis vs fixed-height textScaler overflow (SUGGESTION).
- **Infra / bash / SQL-only**: trace quoting per shell hop; verify NOTIFY contract; check cold-start
  path when a "redundant" reload is removed.
- **Config / asset** (app-icon): pixel-sample corner-vs-center alpha, don't trust headers.

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
