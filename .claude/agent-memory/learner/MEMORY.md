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
| _(none yet — first run pending)_ | 0 | — | — |

## Durable cross-agent lessons (edit in place; don't stack)
_None yet._ Watch-items carried from project conventions:
- Promotion threshold is **2× across different commits**. First sighting = log & watch, not a rule.
- Targets for a proposed change: `CLAUDE.md`, `docs/decisions.md` (append-only), `docs/database.md`,
  `docs/design-principles.md`, `.coderabbit.yaml` `path_instructions`, `analysis_options.yaml`.
- Don't propose anything already gated by `.githooks/` (format/analyze/commit-msg/secret-scan) or an
  existing `.coderabbit.yaml` instruction — no double-gating.

## Known false-positive traps (don't promote these into rules)
- Missing `auth.uid()` / owner-scoping is **expected pre-auth** (issue #3), not a defect.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a breaking change.
- The `.coderabbit.yaml` SQL `path_instructions` telling the bot SECURITY DEFINER must "check
  auth.uid()" is itself phase-unaware — if reviewers keep tripping on it (2×), the action is to
  propose **softening** it, not enforcing it.
