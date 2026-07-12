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
| RLS/soft-delete slice's linchpin verification curl run live but not recorded in `backend/README.md` (red-team re-raises). First: event-types #13 → follow-up #19. | 2 | 1988e26 | PROMOTED → `docs/database.md` #11 (`4911243`); WORKING — at `1988e26` red-team's `update_contact`-refuses-soft-deleted curl was recorded in `backend/README.md` proactively (finding APPLIED, no re-raise). |
| A slice that reverses/rewrites a rule mid-multi-slice migration leaves a contradictory **sibling doc-comment / migration header** citing the old rule; a reviewer must catch it each time. Owner: `plan-critic` (its tracker independently at Count 2, RULE CANDIDATE). First: Decision-25 amendment conditional/unconditional mismatch (caught by crlocal). | 2 | 1988e26 | RULE CANDIDATE — learner proposed CLAUDE.md workflow line (a rule reversal isn't done until every sibling comment/header/doc citing the old rule is updated in the SAME slice). Not gated by `.githooks/`/lint/`.coderabbit.yaml`. |

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
  unconditional mismatch). `plan-critic` now greps for these at plan time; the proposed CLAUDE.md
  line makes it a standing convention so it's also covered on <10-line changes that skip
  `plan-critic`. Not double-gated (no hook/lint/CodeRabbit instruction catches a stale doc-comment).

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
