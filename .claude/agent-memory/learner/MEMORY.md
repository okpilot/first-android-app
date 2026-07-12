# learner — memory

> Cross-agent pattern tracker, curated in place (never a dated session log — history is in git).
> Aggregates the post-commit reviewers' findings and tracks which recur toward a rule change.
> Curated at `/wrapup`.

## Issue Frequency Tracker (rows transition, never deleted)
State machine: `WATCHING ──(Count reaches 2 across different commits)──▶ RULE CANDIDATE
──(rule written)──▶ PROMOTED → <rule loc>`; side exits `RESOLVED` (fix stops recurrence),
`RESOLVED-WATCH`, `FALSE POSITIVE`. Count increments only for a **distinct-mechanism** recurrence,
not a re-mention. Read columns by header, not position.

| Issue Type | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|
| `setState(() => …)` arrow returns a Future (async work discarded; not caught by analyze, only by tests). First: Contacts slice `fa4fc45`. | 2 | 3a87cc8 | PROMOTED → `analysis_options.yaml` `discarded_futures` enabled (`0e4a7af`) |
| RLS/soft-delete slice's linchpin verification curl run live but not recorded in `backend/README.md` (red-team re-raises). First: event-types #13 → follow-up #19. | 2 | 3296258 | PROMOTED → `docs/database.md` #11 (`4911243`); held clean across the rest of Decision 26 — `20970ea` (event_types Slice 2) and `3296258` (event_comments Slice 3: red-team 0/0, 2 INFO only, recommended curls, no re-raise). Convention held for the full migration; RESOLVED-WATCH. |
| A slice that reverses/rewrites a rule mid-multi-slice migration leaves a contradictory **sibling doc-comment / migration header** citing the old rule; a reviewer must catch it each time. First: Decision-25 amendment conditional/unconditional mismatch (caught by crlocal). | 2 | 3296258 | PROMOTED → `CLAUDE.md` "How we work" ("A rule reversal isn't done until its contradictions are gone", cites learner count 2). **First real divergent-slice test PASSED at `3296258`** (event_comments Slice 3, Decision 26 COMPLETE): all contradictions caught in-cycle — nothing reached main stale. Leaky-but-caught: 3 stale spots hid in NON-OBVIOUS locations (README "Conventions in play" bullet, D23 main bullet, D23 *Implementation* subsection) — plan-critic caught 2 pre-impl, doc-updater caught the subsection post-commit. See "subsection/summary hiding place" watch below. |
| **Refinement:** stale citations in a rule reversal hide in secondary summaries & decision-entry SUBSECTIONS (Implementation/Why-safe/Principle), not just the obvious rule line. First (only) sighting: `3296258`. | 1 | 3296258 | WATCHING — single commit, do NOT sharpen `CLAUDE.md` yet (over-fitting risk). doc-updater already recorded the mechanical lesson in its own tracker ("grep the WHOLE of each touched file + every subsection"). If a FUTURE rule reversal leaks the same way → RULE CANDIDATE (sharpen the CLAUDE.md sweep line to name subsections/summaries). |
| **`toRpcParams()` spread must match the RPC's parameter list exactly, or PostgREST throws PGRST202** (function-not-found for the sent arg set). A body-only `update_*` (no `p_event_id`) or a `create_*` with a different arity than the model builds → blind `{...model.toRpcParams()}` sends a param the fn lacks. First: event_comments Slice 3 `1e7574d` (`update_comment` body-only → repo builds `{p_id,p_body}` explicitly, NOT a spread). | 2 | 258cb6c | RULE CANDIDATE — recurred distinct-mechanism at tasks `258cb6c` (`create_task` arity trap, plan-critic ISSUE fixed in-plan). Propose ONE convention line under `docs/database.md` rule #2. Both hits caught at PLAN time by plan-critic (never reached runtime) → the rule makes the check explicit so it's not re-derived per slice. |

## Durable cross-agent lessons (edit in place; don't stack)
- **`setState(() => Future)` is invisible to `flutter analyze`** (arrow returning a value in a void
  context is legal Dart; `flutter_lints` has no rule for it). It has surfaced twice as a runtime
  bug caught only by tests (`fa4fc45`, `3a87cc8`). The mechanical catch is the `discarded_futures`
  lint — now enabled in `analysis_options.yaml` (`0e4a7af`), so the pattern is double-gated (lint +
  tests). Noise caveat: it also flags intentional fire-and-forget, which need `unawaited(...)` /
  `// ignore: discarded_futures`.
- **red-team's "record the curl" finding is structural, not per-slice.** Each RLS/soft-delete
  slice runs a linchpin curl live to prove non-destructive delete, but it isn't written down, so
  red-team re-raises it every time (#19, then `3a87cc8`). A standing convention in the DB doc stops
  the re-derivation — and it held at `1988e26` (contacts Slice-1 curl recorded proactively, no
  re-raise). Watch it keeps holding across the remaining Decision-26 slices.
- **Rule reversals mid-multi-slice migration are a doc-hygiene hazard.** Decision 26 flips a
  *global* DB rule (rule #2 "not everything is RPC" → "all writes via RPC") one slice at a time.
  Each slice that flips the rule tends to leave a sibling repo doc-comment / migration header still
  citing the OLD rule (the event_types "…like contacts" comment; the Decision-25 conditional/
  unconditional mismatch). Now PROMOTED to a `CLAUDE.md` standing convention (+ `plan-critic` greps
  at plan time) so it's covered even on <10-line changes that skip `plan-critic`. Not double-gated
  (no hook/lint/CodeRabbit instruction catches a stale doc-comment). **First real divergent-slice
  test PASSED at `3296258`** (event_comments Slice 3): nothing stale reached main. But the sweep is
  *leaky at the plan stage* — 3 stale spots hid in non-obvious places (README "Conventions" bullet,
  D23 main bullet, D23 *Implementation* subsection); the fleet's layered gates caught all three
  (plan-critic 2, doc-updater 1 post-commit) but the initial plan grep missed them. Refinement now
  WATCHING (count 1): stale citations concentrate in **secondary summaries & decision-entry
  subsections**, not the obvious rule line. Do NOT sharpen `CLAUDE.md` on this single sighting —
  if the next reversal leaks the same way, promote the sharpening then.
- **Decision 26 (RPC for all writes) is COMPLETE — 4/4 slices came back clean, including the
  divergent one (positive signal, RESOLVED).** events→contacts→event_types→event_comments
  (`2370fcf`, `20970ea`, `3296258`, + earlier) all cleared the whole fan-out (impl-critic APPROVED,
  code/semantic CLEAN, test GREEN). The RPC-write boilerplate (drop+recreate RPC, `SET search_path`,
  revoke-from-public, model `toRpcParams`, repo `.rpc()`+re-select) is a **proven low-risk shape** —
  spend attention on per-entity deltas, not the template. The divergence prediction was correct and
  benign: event_comments' `using(true)` open SELECT means a direct write never hit the 42501
  RETURNING re-check, so the RPC is for UNIFORMITY not necessity, and semantic-reviewer noted the
  RPC-then-refetch is *strictly safer* there (row can't vanish mid-op). Lesson for the NEXT
  cross-entity migration: a well-templated port stays clean even when one entity diverges, provided
  the divergence is documented in the migration header (it was, so no reviewer mis-flagged the
  missing 42501 guard).
- **The `toRpcParams()`↔RPC-arity seam is the recurring failure mode of the RPC-write shape** (count
  2: `update_comment` body-only `1e7574d`, `create_task` arity `258cb6c`). The template is proven
  safe (above), so per-entity attention belongs on ONE seam: does the model's `toRpcParams()` spread
  send EXACTLY the params the target RPC declares? A body-only `update_*` or an arity mismatch → a
  blind `{...toRpcParams()}` sends an extra/missing param → PostgREST **PGRST202** (fn-not-found for
  that arg set). Fix per-entity: build the param map explicitly (`{p_id, p_body}`) when it diverges
  from the create-shape, don't blind-spread. Caught at PLAN time both times (plan-critic), never hit
  runtime — semantic-reviewer's seed watch ("toRpcParams passes the params the RPC expects") already
  half-covers it; a `database.md` #2 line makes it a written convention so it isn't re-derived slice
  by slice. NOT gated by any hook/lint (PGRST202 is a runtime PostgREST error, invisible to analyze).
- **Read-only form must gate ALL write affordances on the same flag, not just one** (count 1, tasks
  `258cb6c`; semantic RESOLVED-WATCH). Archived `TaskFormScreen` hid the complete-toggle but left the
  title field editable + both Save affordances live → Save → `update_task` `deleted_at is null` guard
  → misleading "Couldn't save". Fixed by gating title `readOnly` + both Saves on `_isArchived`. SINGLE
  sighting → log & watch (no rule); already in semantic-reviewer's tracker. Promote only if a future
  edit/detail form gates one affordance but not its siblings again.

Watch-items carried from project conventions:
- Promotion threshold is **2× across different commits**. First sighting = log & watch, not a rule.
- Targets for a proposed change: `CLAUDE.md`, `docs/decisions.md` (append-only), `docs/database.md`,
  `docs/design-principles.md`, `.coderabbit.yaml` `path_instructions`, `analysis_options.yaml`.
- Don't propose anything already gated by `.githooks/` (format/analyze/commit-msg/secret-scan) or an
  existing `.coderabbit.yaml` instruction — no double-gating.

## Known false-positive traps (don't promote these into rules)
- Missing `auth.uid()` / owner-scoping is **expected pre-auth** (issue #3), not a defect. red-team's
  phase-flip watch (auth.uid() owner checks must move INSIDE `create_contact`/`update_contact` when
  #3 lands, because SECURITY DEFINER bypasses RLS) is a legitimate forward-watch, NOT a present
  defect — do not promote it while auth is unwired.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a breaking change.
- The `.coderabbit.yaml` SQL `path_instructions` telling the bot SECURITY DEFINER must "check
  auth.uid()" is itself phase-unaware — if reviewers keep tripping on it (2×), the action is to
  propose **softening** it, not enforcing it.
