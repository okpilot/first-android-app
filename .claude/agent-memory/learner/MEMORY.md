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
| RLS/soft-delete slice's linchpin verification curl run live but not recorded in `backend/README.md` (red-team re-raises). First: event-types #13 → follow-up #19. | 2 | 20970ea | PROMOTED → `docs/database.md` #11 (`4911243`); WORKING — held again at `20970ea` (event_types Slice 2: red-team's create/update_event_type curl already covered by README curls, INFO-only, no re-raise). |
| A slice that reverses/rewrites a rule mid-multi-slice migration leaves a contradictory **sibling doc-comment / migration header** citing the old rule; a reviewer must catch it each time. First: Decision-25 amendment conditional/unconditional mismatch (caught by crlocal). | 2 | 20970ea | PROMOTED → `CLAUDE.md` "How we work" ("A rule reversal isn't done until its contradictions are gone", cites learner count 2). HELD at `20970ea` (event_types Slice 2: doc-updater NO-OP, all doc surfaces synced in-commit — no stale contradiction). Slice 3 (event_comments) is the rule's real test: comments-repo doc-comments still say "direct, no RPC needed". |

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
  (no hook/lint/CodeRabbit instruction catches a stale doc-comment). Held clean at event_types
  Slice 2. **Slice 3 (event_comments) is the first real test:** its repo doc-comments still assert
  "direct, no RPC needed" and rule #4 in `docs/database.md` gets rewritten — watch that every such
  sibling flips in the SAME slice.
- **A faithful RPC-write template port is a proven low-risk shape (positive signal).** The
  events→contacts→event_types ports (Slice 1 `2370fcf`, Slice 2 `20970ea`) came back three-in-a-row
  clean across the whole fan-out (impl-critic APPROVED, code/semantic CLEAN, test GREEN, doc-updater
  NO-OP). When the next slice is a genuine template port, treat the boilerplate (drop+recreate RPC,
  `SET search_path`, revoke-from-public, repo method swap) as low-risk and spend attention on the
  **per-entity deltas** instead. Slice 3 (event_comments) is NOT a faithful port — it diverges:
  `using(true)` open SELECT (no owner scope, so **no 42501 to route around** like contacts/
  event_types had), the `docs/database.md` rule #4 rewrite lands here, and the "direct, no RPC
  needed" doc-comments must be flipped. Give Slice 3 full scrutiny, not template-port confidence.

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
