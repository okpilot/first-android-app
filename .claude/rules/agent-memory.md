# Agent memory — format & discipline (First Android App)

> Governs `.claude/agent-memory/<agent>/`. Ported + trimmed from LMS Plus. Companion:
> `.claude/rules/agent-workflow.md`. Binding for every agent with `memory: project`.

## Mechanics
`memory: project` in an agent's frontmatter binds `.claude/agent-memory/<name>/`. At each
invocation Claude Code auto-injects that dir's `MEMORY.md` (first 200 lines / 25 KB, whichever is
smaller) and grants the agent Read/Write on the dir. Only `MEMORY.md` is auto-injected — sibling
`topics/*.md` files are read on demand. **Agent defs snapshot at session start**: adding or
removing `memory:` needs a session restart to take effect.

## `MEMORY.md` layout (keep it < 200 lines AND < 25 KB — the budget is hard)
1. **Tracker table** — recurring findings, one row each (see state machine). `learner` and
   `code-reviewer` always keep one; the other agents add one once a pattern recurs ≥ 2×.
2. **Durable knowledge** — short bullets of stable, load-bearing facts/conventions for this project.
3. **Topic pointers** — one line each: `- [theme](topics/theme.md) — one-line hook`.

## No journals
**Never** append a dated "session log" section to any `MEMORY.md`. History lives in git
(`git log -p -- <file>`). Update **in place** — edit the existing row/bullet so the file stays
small and current; don't stack a new dated paragraph per session.

## Tracker state machine (rows are never deleted — they transition)
```text
WATCHING ──(count reaches 2)──▶ RULE CANDIDATE ──(rule written)──▶ PROMOTED → <rule location>
   ├──(fix proven, stops recurring)──▶ RESOLVED
   ├──(resolved but worth watching)──▶ RESOLVED-WATCH
   └──(not a real issue)──────────────▶ FALSE POSITIVE
```
- Columns (read by header, not position): `Pattern | First Seen | Count | Last Seen | Status (→ rule loc)`.
  (`learner` uses its own `Issue Type | Count | Last Seen | Status` shape — First Seen folded into Status.)
- **Count** increments only for a **distinct-mechanism** recurrence, not a re-mention. A pattern
  reaching **count 2** is the promotion threshold — propose a rule/convention change (that's the
  `learner`'s job).
- A row that stops recurring is itself a positive signal (transition to RESOLVED, don't delete).

## Protected topic files (never auto-pruned)
`red-team/topics/attack-surface.md` — the threat-vector → coverage matrix. `red-team` keeps a small
`MEMORY.md` index that points at it; keep the matrix as the named topic file, never inline it, never
let curation drop it.

## Which agents have memory
- **Standard** (`memory: project`, MEMORY.md tracker): `plan-critic`, `implementation-critic`,
  `semantic-reviewer`, `code-reviewer`, `doc-updater`, `test-writer`, `learner`, `db-security-reviewer`.
- **red-team** — `memory: project` + a small MEMORY.md index → protected `topics/attack-surface.md`.
- **coderabbit-sync** — **no memory** (no dir, no `memory:` key).

## Curation
`MEMORY.md` files are **committed** (they're curated pattern-trackers, not secret dumps; `.md`
skips the Dart-only pre-commit hook). `/wrapup` curates them each session-end: keep lean, prune
stale prose (move durable detail to `topics/`), transition tracker rows — never a journal.
