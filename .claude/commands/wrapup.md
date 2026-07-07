End-of-session wrap-up. Run before stopping — sync docs, dispose of open findings, and leave `main` clean for the next session. Scaled for this project; grow it as we add CI, a board, agents, etc.

## Checklist (report pass/fail with brief notes)

### 1. Docs sync (update in place)
- `HANDOVER.md` — reflects exactly where we stopped + the resume condition.
- `docs/plan.md` — status section and "next slice" are current.
- `docs/decisions.md` — every decision made this session is recorded (numbered, dated).

### 2. Findings disposition (no silent skips)
List EVERY open non-blocking finding from this session (cr-local skips, cloud CodeRabbit nitpicks, anything deferred). For each, the user picks one:
- **FIX NOW** (< 10 lines) · **DEFER** → open a GitHub issue (`gh issue create`) · **SKIP** → with a reason.
- "Noted" is not a disposition — it's a ticket or an explicit skip.

### 3. Repo hygiene
- `main` is clean (`git status`) and synced (`git status -sb` shows up-to-date with `origin`).
- No stray merged branches left behind (local or remote).
- No uncommitted work that should be saved; nothing half-done left unstated.
- **Secret hygiene** — no secrets were committed, logged, or echoed this session.

### 4. Task & memory
- Any `TaskCreate` tasks are completed or explicitly carried forward.
- Project memory is accurate and lean; stale entries removed.

### 5. Session summary (present to user)
- **Done this session** — what shipped / merged.
- **Open / deferred** — with issue links.
- **Repo state** — branch, last commit, clean/synced.

### 6. Next-session hint
- What the next session should start with (the next slice), and any blocker to clear first.

## Why this exists
A session should end tidy: docs current, every finding dispositioned (not "noted"), `main` green and synced, and a clear starting point recorded — so the next session resumes in seconds, not archaeology.
