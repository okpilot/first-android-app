Run CodeRabbit's local CLI against the current branch and triage findings. Use BEFORE pushing (and as part of `/fullpush`) on any branch with commits ahead of `main`.

## Why this exists
CodeRabbit local catches things our own reading misses — missing error paths, unhandled async, cleanup ordering, unsafe casts. Running it before push is cheaper than triaging the same findings on the PR after the fact. It's an LLM reviewer with no convergence guarantee, so the triage + multi-round rules below decide when to fix vs. when to stop.

## What to do
1. **Run the review** (2–5 min; use `run_in_background: true` and wait for completion):
   ```bash
   coderabbit review --plain --base main --type committed -c .coderabbit.yaml > /tmp/cr-local-roundN.log 2>&1
   ```
   Always pass `-c .coderabbit.yaml`. If `which coderabbit` is empty, tell the user and skip — do NOT pretend it ran.

2. **Triage each finding — READ THE SOURCE, don't trust labels OR line numbers** (CR is sometimes wrong about both; verify with Read/grep):

   | Class | Action |
   |---|---|
   | Real safety (missing error path, unhandled async, race, leak) | **Apply** |
   | Violates a rule in `CLAUDE.md` / `docs/database.md` | **Apply** |
   | Readability that genuinely helps a reader | Apply if < 10 lines |
   | Pure aesthetic preference | **Skip** (note reason) |
   | Diverges from an established codebase pattern | **Skip** (note reason) |
   | Scope expansion ("while you're here…") | **Defer** → note it |

3. **STOP. Plan before any Edit.** After the triage table, write a short inline plan (file:line per fix, blast radius, verification). The triage table is not a plan.

4. **Apply approved findings**, then **re-run** the review.

5. **Multi-round stop rule** (CodeRabbit is non-deterministic — one quiet round is weak evidence):
   - Run a **minimum of M rounds**, then stop on the first round at/after M with **no apply-worthy findings**.
   - **M = 2** normal diff. **M = 3** when the diff touches `**/*.sql` or auth/security code.
   - An **Apply** verdict extends the loop by one round (fix, then one more clean round). Never stop *on* a round that still has an Apply.
   - **Hard ceiling: 4 fix-commits** on the branch → stop and escalate to the user even if unmet.

6. **Report a round summary** each round:
   ```text
   CR local round N — <count> findings
   | File:line | Class | Verdict | Why |
   Applied: N   Skipped: N   Rounds: X/min M   this-round apply-worthy: yes/no
   Stop condition met: yes/no — <reason>
   ```

## Notes
- The cloud CodeRabbit bot reviews the actual PR on push (org-wide install) — that's the authoritative gate; cr-local is the cheaper pre-push preview.
- Common mistakes: trusting CR's severity labels; trusting its line numbers; applying everything to silence it (scope creep); skipping the plan step; not re-running after a fix.
