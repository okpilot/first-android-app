# Agent workflow — the review pipeline (First Android App)

> How the reviewer fleet in `.claude/agents/` is run. Ported + trimmed from LMS Plus for this
> **Flutter + trimmed self-hosted Supabase** project. Companion: `.claude/rules/agent-memory.md`.

## Prime directive
The fleet is **orchestrator-driven**: Claude launches the reviewers via the Agent tool at the
right moment in the session, so **findings are visible and actionable in the conversation** and get
fixed immediately. External hooks I can't see are useless — the git hooks only *nudge* (the
`post-commit` banner) and run the deterministic mechanical gates (`.githooks/`). The reviewers are
**advisory**; the human approval step in `/fullpush` is the only real gate. No reviewer blocks a
`git push` (this project has no Node and doesn't want an LLM inside a git hook).

## The pipeline (moment → agent)

| Moment | Agent(s) | Runs |
|---|---|---|
| **Plan time** — after I draft a plan, before you approve | `plan-critic` | multi-round (below); skip for single-file <10-line changes |
| **Pre-commit** — after building, before `git commit` | `implementation-critic` | **always**, no skip |
| **Post-commit** (the `.githooks/post-commit` banner nudges) | `code-reviewer` · `semantic-reviewer` · `doc-updater` · `test-writer` in parallel | unconditional (each no-ops if nothing in its scope) |
| ↳ then, conditional | `red-team` (if diff touched `backend/migrations/**` or auth) · `coderabbit-sync` (if diff touched `CLAUDE.md` / `docs/database.md` / `analysis_options.yaml` / `.claude/rules/*`) | only when the path condition holds |
| ↳ **last** | `learner` — after all the above, so it aggregates every reviewer's findings (the parallel four **plus** any conditional `red-team`/`coderabbit-sync`) | always |
| **Pre-push** (`/fullpush`, before `/crlocal`) | `db-security-reviewer` | when diff touches `backend/migrations/**/*.sql` |
| **PR** | cloud CodeRabbit + `/coderabbit` triage | authoritative |
| **Session end** | `/wrapup` | disposes findings + curates memory |

The post-commit reviewers sit **earlier** than `/crlocal` (pre-push) and cloud CodeRabbit (PR) —
additive early catches, **not** replacements. They dedupe against `.coderabbit.yaml` and focus on
this project's own conventions (repository pattern, `FutureBuilder`+`_lastData` stale-guard,
`mounted`-after-`await`, colour-as-data, 24h time, minutes-from-midnight event math).

## Severity (all critics/reviewers use these three)
- **CRITICAL** — safety / security / data-loss. Resolve directly; no revision round.
- **ISSUE** — functional bug, wrong assumption, or plan deviation. Fix before proceeding.
- **SUGGESTION** — non-blocking improvement. Noted; does not gate.

(`db-security-reviewer` uses CRITICAL/ISSUE/**INFO** — INFO = pre-auth items tracked under #3.)

## Multi-round discipline (applies to `plan-critic`, and post-commit `semantic-reviewer` /
`code-reviewer`; **`implementation-critic` is exempt**)
- **Coverage round** = distinct lenses in parallel for breadth — always include an **adversarial
  lens** (actively try to break the change: the exploit, the race, the edge case) and a
  **completeness lens** (what's missing: an unhandled path, an untested branch, a doc/citation left
  stale). **Stability round** = re-run the same review on the same unchanged artifact to shake out
  variance. Only stability rounds count toward the clean floor.
- **Consecutive-clean floor:** N=**3** for a normal multi-file change; N=**4** when the diff hits
  the **security path** (`backend/migrations/**/*.sql`, or auth files once they exist).
- A clean round = zero APPLY-worthy findings (CRITICAL/ISSUE, or a SUGGESTION you choose to apply).
  A stylistic-only round or a validated skip-with-reason does **not** break clean.
- **Reset on finding, not on skip:** any APPLY finding resets the counter to 0; a validated
  skip-with-reason (false positive / contradicts a codebase pattern) does not.
- **Ceiling: 6 rounds.** If the floor is unmet at the ceiling, **STOP and escalate to the user**
  with the residual findings — do not resolve unilaterally.
- **`implementation-critic` exemption:** its artifact mutates on every fix and it never skips, so
  it runs a max **2-round** revision loop, then the orchestrator (me) takes over directly. A
  CRITICAL from it → I intervene immediately, no revision loop.

## Finding validation (before acting on ANY finding)
Read the actual source the finding points at and confirm it's real before fixing — the fleet is
advisory, and a wrong fix is worse than the finding. A finding that turns out to be a false
positive is a validated **skip-with-reason** (recorded, doesn't reset the clean counter).

## Model tiers
- **opus:** `db-security-reviewer` — it's the one reviewer that runs at the push **gate**, so its
  quality is pinned and can't silently drop on a cheaper session.
- **haiku:** `doc-updater`, `coderabbit-sync` — cheap, mechanical.
- **inherit (omit `model:`):** `plan-critic`, `implementation-critic`, `semantic-reviewer`,
  `code-reviewer`, `red-team`, `learner`, `test-writer` — inherit the session model (opus-class
  here). `test-writer` inherits (not haiku) because it writes real Dart tests and must leave the
  suite green. **`red-team` inherits** (not pinned like `db-security-reviewer`) because it is
  post-commit + **advisory**, one step before the gate.

## Pre-flag verification: the CREATE OR REPLACE chain (every SQL-touching reviewer)
Before flagging a missing pattern on a Postgres function, grep `backend/migrations/**/*.sql` (sorted
by the `YYYYMMDDHHMMSS_` prefix) and read the **latest** definition — this project uses
`drop function if exists …; create or replace …` to change RPC signatures (correct, not a
regression). Never flag from a single migration in isolation.
