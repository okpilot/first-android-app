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
- **`toRpcParams` shape-change → stale sibling comment (RESOLVED-WATCH, count 1 — Task notes slice;
  held clean at Decision 38 importance, 2026-07-15):** when a scalar field is added to `toRpcParams()`,
  the model's dartdoc that quotes the OLD param literal (`create_task(p_title, p_notes, p_contacts)`,
  the `{p_id, p_title, p_is_done, p_notes, p_contacts}` update shape) goes stale in the SAME file.
  At Decision 38 the sweep was done proactively (plan-critic folded it in): both the `create_task(…
  p_importance)` signature quote and the update-shape quote in task.dart were updated in the same diff,
  AND the repo's update() comment. Minor (SUGGESTION) when missed — grep the model+repo for a comment
  quoting the pre-change param literal whenever the create/update shape grows.
- **Docs-sync "same file, >1 stale surface" — the backlog/owed-list twin (WATCHING, count 1 — issue
  #40 review-bar rebalance, 2026-07-14):** a rules/docs slice that updates a status line (plan.md
  current-status: "`/updatephone` done"; Decision 35 codifying #40) but leaves the SAME file's
  "Owed first / to-do" list still citing the very item the commit completed — plan.md:14 "phone done"
  vs plan.md:51 "phone owed", and #40 still listed as owed at :54 while THIS commit does it. Numbers
  were correct; the staleness was STATUS framing. RULE-IN-MINIATURE: on any doc-sync slice, after
  editing a status/shipped line, grep the SAME file's "Owed"/"Next"/"backlog"/"TODO" lists for the
  same task keyword — a file has >1 surface (this is the project's rule-reversal-sync discipline
  applied to plan.md, not just repos/migrations).
- **Verify-curl param names drift from the RPC signature (WATCHING, count 1 — Decision 36 pre-auth
  lockdown, 2026-07-15):** a NEW `backend/README.md` verify-curl block transcribed `create_contact`'s
  JSON body with non-existent params `p_birthday`/`p_notes` while the real signature is
  `p_dob`/`p_remarks` (a correct twin curl sat right below it). PostgREST matches RPC args by NAME →
  the "returns a uuid" curl would actually PGRST202. RULE-IN-MINIATURE: whenever a doc/README adds a
  `POST /rpc/<fn>` example, grep the fn's `create_*/update_*` migration for the exact `p_*` param
  names and match them 1:1 — the app's Dart `toRpcParams()` is NOT the source of truth for a
  hand-written curl (Dart may use different field names). ISSUE severity: a copy-paste-fails verify
  snippet contradicts its own success comment.
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
- **Scalar-field-add** (Task notes, Dec 27; **Task importance Decision 38, Jul 15**): drop+CR both
  RPCs on arity change + re-issue the Decision-36 `revoke … from public` + `grant … to anon,
  authenticated` on the NEW signatures (a recreate hands back default PUBLIC execute — the lockdown
  invariant); `nullif(trim,'')` clear-path; `copyWith` preserves via `?? this.` (both toggle paths
  omit the arg); toRpcParams carries the new `p_*` (4-arg create), repo update() sends it explicitly
  (6-arg update, REQUIRED no-default = fail-loud on stale caller); `.order('importance', desc)` sits
  BETWEEN is_done and created_at; new fixed-scale colour = chrome NOT Decision 19 (framed correctly);
  ImportanceMarks a11y = Semantics label so colour/'!' never rides alone; test fakes thread the field
  through create + archive + restore, not just update. Full dartdoc sweep held clean.
- **Template-port** (contacts/event_types/event-comments write-RPCs, Dec 26 S1–2): diff vs green
  template; security posture must be byte-for-byte; new fn = no CR-chain.
- **Full-stack new-entity mirror of EventType** (task_categories Slice A, Decision 39, Jul 15; clean
  0 blocking): NEW table created POST-lockdown ships RPC-only from day one — SELECT-only policy
  `using(deleted_at is null)` + `grant select`, NO insert/update policy or grant, 3 SECURITY DEFINER
  RPCs `set search_path=public` each with `revoke execute … from public` + `grant … to anon,
  authenticated` on the exact typed signatures. RPC arity matched toRpcParams 1:1 (create 2
  p_name/p_color, update 3 adds p_id via repo spread, soft_delete 1). Model mirrors EventType:
  `_validHex` → `#888888` fallback, draft ctor empty id, pure-Dart no dart:ui. Screen imports
  `TypeSwatch` via `show` (not redefined), reuses kEventTypePalette/colorFromHex/hexFromColor; new
  colour = user-data swatches (Decision 19 OK) + Semantics label so colour never rides alone;
  `_lastData` stale-guard + `identical(future,_future)` both present; mounted-after-await on every
  path; messenger/navigator captured pre-await. All 4 hand-fakes (calendar/home_shell/widget×2)
  threaded, both ContactsApp sites updated. NO Slice-B leak (no Task/create_task/tasks-repo/join).
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
- **Join-table + picker-generalization** (People on a task, Jul 14): m2m mirror of event_attendees
  (drop+CR both RPCs on arity change, join-delete AFTER not-found raise, `using(true)` off #4 list) +
  rename Attendee→ContactPicker w/ `title` noun (event strings byte-identical); load-bearing toggle
  invariant verified on all 3 update paths via `copyWith` default + embed on both reads; title-vs-
  widget.x trap handled (host seeds+setState `_task`).

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
