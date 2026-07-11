End-of-session wrap-up. Run before stopping — sync docs, dispose of open findings, verify the reviewer fleet ran, and leave `main` clean for the next session. Scaled for this project; grow it as the project earns more (CI, a board, etc.).

## Checklist (report pass/fail with brief notes)

### 1. Docs sync (update in place)
- `HANDOVER.md` — reflects exactly where we stopped + the resume condition.
- `docs/plan.md` — status section and "next slice" are current.
- `docs/decisions.md` — every decision made this session is recorded (numbered, dated).

### 2. Findings disposition (no silent skips)
List EVERY open non-blocking finding from this session — cr-local skips, cloud CodeRabbit nitpicks, anything deferred, **and every open ISSUE/SUGGESTION from a reviewer in the fleet** (plan-critic, implementation-critic, semantic-reviewer, code-reviewer, red-team, doc-updater, test-writer, coderabbit-sync). For each, the user picks one:
- **FIX NOW** (< 10 lines) · **DEFER** → open a GitHub issue (`gh issue create`) · **SKIP** → with a reason.
- "Noted" is not a disposition — it's a ticket or an explicit skip.
- **Answer the cloud bot on the PR:** if there's an open PR with a cloud CodeRabbit review, run
  **`/coderabbit`** (triage each finding vs source → fix/defer/skip) → **`/fullpush`** (push the fixes)
  → **`/replycoderabbit`** (post the reply — one general comment, each finding citing its fix commit
  or skip/defer reason). Triage before reply; never leave a cloud-CR finding unanswered.

### 3. Repo hygiene
- `main` is clean (`git status`) and synced (`git status -sb` shows up-to-date with `origin`).
- No stray merged branches left behind (local or remote).
- No uncommitted work that should be saved; nothing half-done left unstated.
- **Secret hygiene** — no secrets were committed, logged, or echoed this session.

### 4. Task & memory
- Any `TaskCreate` tasks are completed or explicitly carried forward.
- Project memory is accurate and lean; stale entries removed.
- **Agent memory** (`.claude/agent-memory/*/MEMORY.md`) — curate in place: keep the pattern
  trackers accurate and lean, prune stale rows, and confirm no raw secrets/findings leaked in. Each
  `MEMORY.md` stays **under the 200-line / 25 KB budget** (spill durable detail to `topics/`); keep
  `red-team/topics/attack-surface.md` current. If the auth phase advanced this session (issue #3),
  flip the `db-security-reviewer` (and `red-team`) phase notes.

### 5. Agent pipeline (the reviewer fleet — see `.claude/rules/agent-workflow.md`)
Report pass/fail with brief notes. Only audit what applies to this session's work.
- **Findings resolved** — no orphaned CRITICAL/ISSUE from any reviewer; each was fixed, deferred, or
  skipped (dispositioned in §2, not left hanging).
- **Pipeline ran** — each commit this session got the post-commit reviewers (+ `learner`);
  `implementation-critic` ran before each commit and `plan-critic` before each plan approval. Any
  skip is **stated** (plan-critic may skip a <10-line single-file change; implementation-critic
  never skips).
- **Ceiling escalations** — any critic that hit the multi-round ceiling (4) was **escalated to the
  user** with residual findings, not silently resolved.
- **Scope violations** — no reviewer acted outside its lane (e.g. `test-writer` editing `lib/`
  production code, `doc-updater` making an architectural decision, a critic editing code directly).
- **`learner` proposals** — any rule/doc/config change it proposed was applied or **explicitly
  declined** (not "noted"); none conflicts with an existing rule or double-gates the `.githooks/`.
- **doc-updater DRIFT** — any DRIFT it flagged (a doc contradicting committed code) was resolved —
  the doc updated or the code fixed.

### 6. Session summary (present to user)
- **Done this session** — what shipped / merged.
- **Open / deferred** — with issue links.
- **Repo state** — branch, last commit, clean/synced.

### 7. Next-session hint
- What the next session should start with (the next slice), and any blocker to clear first.

## Why this exists
A session should end tidy: docs current, every finding dispositioned (not "noted"), `main` green and synced, and a clear starting point recorded — so the next session resumes in seconds, not archaeology.
