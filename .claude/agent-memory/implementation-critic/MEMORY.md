# implementation-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring
> implementation deviations vs the approved plan for THIS project so future pre-commit reviews
> focus where builds actually drift. Curated at `/wrapup`.

## Seed watch-items (per-project trap list — check these on every Dart slice)
- After an `await` in a `State`, is there `if (!mounted) return` before touching `context`/`setState`?
- `startMin`/`endMin` math — right unit (minutes from midnight, `0..1439`), both null iff `allDay`?
- Nullable model fields dereferenced without a guard (`Event.startMin`/`endMin`/`type`, `Contact.dob`)?
- Repository/model signature change → is the hand-written `_FakeXRepo` in `test/` updated too?
- Fallbacks match sibling code (`EventType` bad-hex → `#888888`; `toWrite()` empty → null)?
- `FutureBuilder` screens keep the `_lastData` stale-guard (failed refresh keeps stale data)?

## Recurring deviations — tracker
Full write-ups: [deviations](topics/deviations.md).

| Pattern | First Seen | Count | Last Seen | Status |
|---|---|---|---|---|
| Docs-sync "same file, >1 stale surface" — owed-list twin → back-reference clause + plan/HANDOVER twin-file copy → **status-flip lands in plan.md/HANDOVER.md but NOT in the decisions.md ledger deploy-note twin** (`/updatephone` owed, D40:487 + D41:499) | #40, 2026-07-14 | 3 | #19/D45 r2, 2026-07-17 | **RULE CANDIDATE → learner-PROPOSED (`d429a80`), awaiting main session.** learner took this at count 3 and proposed widening the EXISTING promoted CLAUDE.md rule on both axes you named — headline "a rule reversal **or a status flip**", and an OPEN subsection list naming `Deploy note:` (grep-confirmed: the ledger's real vocabulary is Context 45 / Principle 43 / Decided 39 / Verification 2 / Test coverage 2 / Refines 2 / **Deploy note 2**, and both deploy-notes — D40:487, D41:499 — are exactly where the twins rotted). Not a new rule (would duplicate) and not a deletion: an under-firing TRIGGER on a rule that already exists. Mark PROMOTED once the main session writes it. Standing lesson meanwhile: on a docs-only slice the blocking findings are twin greps, not the artifact under test |
| `toRpcParams` shape-change → stale sibling doc-comment quoting the OLD `p_*` literal | Task notes, Dec 27 | 1 | D38, 2026-07-15 | RESOLVED-WATCH (promoted to CLAUDE.md; held clean since) |
| Consolidating a duplicated fake orphans its `///` doc-comment onto the retained sibling | #10 fakes.dart, 2026-07-16 | 1 | same | WATCHING |
| Verify-curl `p_*` names drift from the RPC signature (→ PGRST202) | D36, 2026-07-15 | 1 | same | WATCHING (held clean at D45 — arity + names checked vs latest chain def) |
| State-lift-vs-`widget.x` — dynamic-title host reads frozen `widget.task` | D29 Tasks | 1 | same | WATCHING |
| **"Inert param" reasoning is axis-blind** — a plan proves a param inert on ONE axis, the build then DELETES it, and it silently drives a SECOND axis. `radius: 11` dropped from `InitialsAvatar` in 2 chips (A1/D47): proven inert for the DISC (Chip hands the avatar a `tightFor(contentSize)` box, `chip.dart:1884`) but `initials_avatar.dart:34` reads `fontSize: radius * 0.7` → default 20 ⇒ initials 7.7px→14px. Tell: the build ships a comment ASSERTING inertness. **Check every read of the param, not the one the plan analysed** — and diff against the in-tree precedent the plan itself cited (`calendar_screen.dart:1292` passes radius AND ring) | A1/D47, 2026-07-17 | 1 | same | WATCHING |
| **Plan prose ambiguous on an axis → build picks the reading the plan's own justification forbids.** "compact `padding` — HORIZONTAL ONLY" shipped as `symmetric(horizontal: 4)`, which ZEROES vertical (M3 default is `all(8)` ⇒ 16) — the maximal *lowering* of the very lever the plan said "do not chase … merely inflates the avatar and the ✕". When a plan names an axis, check whether it means "specify only this" or "change only this"; the justification sentence disambiguates | A1/D47, 2026-07-17 | 1 | same | WATCHING |
| **Docs written but left UNSTAGED** — a fresh docs-sync miss distinct from the stale-twin rule (the twins were CORRECT here). A1/D47: 9 code comments cite "Decision 47"; `docs/decisions.md` + `docs/plan.md` were ` M` not `M `, so the commit ships the citations WITHOUT the decision. The existing CLAUDE.md rule greps for OLD status words and cannot catch this. **Cheap check: `git status --porcelain` for a ` M docs/` alongside any staged `Decision N` citation** | A1/D47, 2026-07-17 | 1 | same | WATCHING |

## Positive signals — one line each; win conditions in [positive-signals](topics/positive-signals.md)
All clean pre-commit (0 blocking) unless noted.
- **Scalar-field-add** (Task notes Dec 27; **D38 importance Jul 15**) — drop+CR both RPCs on arity change **and re-issue the D36 revoke+grant on the NEW sigs** (a recreate restores PUBLIC execute); required-no-default = fail-loud; fixed-scale colour = chrome, not D19.
- **Full-stack new-entity mirror** (task_categories Slice A, D39, Jul 15) — a post-lockdown table ships RPC-only from day one (no write policy/grant at all); import `TypeSwatch`, don't redefine; no Slice-B leak.
- **Join-table + picker-generalization** (People on a task, Jul 14) — m2m mirror of event_attendees; join-delete AFTER the not-found raise; `using(true)` correctly off database.md #4's list.
- **Join-table 2nd occurrence — copy-not-generalize picker** (task↔task_categories, Slice B/D40, Jul 15) — drop targets matched the CURRENT chain sigs; 4th recurrence of field-vanishes-in-a-fake (notes→contacts→importance→categories).
- **Cross-cutting RPC-arity retrofit** (idempotent `create_*`, D41/#9, Jul 16) — one drop+recreate for all 7; `p_id` in `toRpcParams` lets the 4 spread-update repos drop their explicit `p_id`; `_pendingId` reset AFTER success = retry reuses id = dedupe.
- **Superset-merge widget extraction** (`DetailField` from two `_Field`s, #10 item 2/D43, Jul 16) — the trap is a pixel/behaviour diff surviving the merge; relaxed both-null assert required by contact, empty branch unreachable for events.
- **Rules/config CR-scoping** (`.coderabbit.yaml` path_filters + doc-updater lifecycle, D44, Jul 16) — negation-ONLY globs = exclude-those-keep-the-rest (does NOT collapse to exclude-all).
- **Docs-only verify-curl backfill** (soft-delete non-destructiveness, #19/D45, Jul 17; r1 REVISE 2 doc-sync ISSUEs → r2 REVISE 1 doc-sync ISSUE — every round's blocker was a **stale doc twin**, never the curls/SQL/decision, which were clean from r1) — `-tA` prints `t` but `::text` in a union prints `true`; `$(curl … | tr -d '"')` swallows a 400 into the var, so blocks need a uuid sanity `echo`; each block must re-declare its preamble + mint its own ids. **Lesson: on a docs-only slice, spend the review budget on twin-surface greps, not on the artifact under test.**
- **Template-port** (contacts/event_types/event-comments write-RPCs, D26 S1–2) — diff vs the green template; security posture byte-for-byte; a new fn has no CR-chain.
- **Divergent (rule-reversing)** (comment write-RPCs, D26 S3) — `update` builds params EXPLICITLY (no spread → PGRST202); restore guards `is NOT null`; full rule-reversal doc-sweep.
- **Shared-widget second-consumer** (task_comments, D33/Slice 2b) — faithful twin + `readOnly` gating (default false → events untouched); second repo threaded end-to-end, no cross-wiring.
- **New-entity-from-scratch** (Tasks v0, D27) — `_lastData` needs the `identical(future,_future)` guard (cloud-CR #30 caught its absence).
- **Widget-extraction / master-detail** (Contacts D28 S-B; Tasks S-D) — shared Scaffold-less body + thin wrapper; `ValueKey(id:isArchived:isDone)` remount; binding-key doc-comment lives on the *EditView*.
- **Pure-refactor extraction** (CommentsSection, D2a) — byte-equivalent behaviour; only the rename axis differs; grep for dangling old names.
- **Pure-UI / adaptive-layout** (desktop sidebar, D28 S-A) — theme-token fidelity; `colorScheme` colours = chrome; `Flexible`+ellipsis vs textScaler overflow.
- **Infra / bash / SQL-only** — trace quoting per shell hop; verify the NOTIFY contract; check the cold-start path when a "redundant" reload is removed.
- **Config / asset** (app-icon) — pixel-sample corner-vs-center alpha, don't trust headers.

## Durable, verified facts (load-bearing)
- **`CREATE EVENT TRIGGER` does NOT fire `ddl_command_end`** (proven locally on postgres:15/16 — a
  second event trigger created while `pgrst_ddl_watch` was active emitted no NOTICE; only
  `CREATE TABLE` did). So `20260712120000_pgrst_ddl_watch.sql` emits ZERO `NOTIFY pgrst` during its
  OWN application: on a fresh DB where PostgREST is already up with an empty cache, applying all
  migrations does not reload it — every endpoint 404s until a restart or the next DDL. Hence
  `deploy-homebase.sh` keeps one UNCONDITIONAL `notify pgrst` as the cold-start net (triggers own
  steady-state + ad-hoc psql; the script one-liner owns fresh-DB cold start). **General lesson:**
  when a slice removes a "redundant" reload/refresh, check the cold-start path, not just steady state.
- **The local dev stack has no migration ledger** (found at #19, 2026-07-17): `init.sh` applies
  `backend/migrations/` only on a FRESH volume, so a long-lived local volume silently rots as later
  migrations get hand-applied (or not). A local curl-run can be hitting a stale schema — re-init with
  `docker compose down -v && docker compose up -d` before trusting local verification output.
  Homebase is unaffected (it has the ledger).

## Known false-positive traps (do not flag these)
- An internal event-trigger / NOTIFY-only function pinning `set search_path = ''` (not `= public`)
  is CORRECT — rule #6's `= public` is for SECURITY DEFINER client-facing RPCs.
- Missing `auth.uid()` / login checks are expected — auth is WON'T-DO (D37, single-user + tailnet-only).
- `with check (true)` policies and RPCs granted to `anon` are intentional.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a dropped-function regression.
- Hard `DELETE` on the annotated `event_attendees` join is allowed; soft-delete is only required on
  mutable entity tables.
- A verify-curl reusing a var name (`TID`, `CID`) that another README block also uses is NOT
  cross-block leakage — each block re-declares its own preamble and is meant to run standalone.
- **A bare `psql -c "…"` in `backend/README.md` is NOT a D45 violation** (raised + retracted at
  #19 r1, 2026-07-17). D45's stdin-only rule targets the **ssh → docker exec → psql** word-splitting
  chain used by `deploy-homebase.sh`; README blocks run *locally inside the db container*
  (`docker compose exec -T db psql …`), where no ssh hop exists. Check for the ssh hop before flagging.
- `order by <alias> desc` over a `union all` **is** valid + deterministic Postgres (verified live at
  #19 r2: the first branch's `as what` alias names the union output column). Not a portability bug.
