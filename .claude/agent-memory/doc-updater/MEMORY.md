# doc-updater — memory

> Transition tracker + durable recipes, curated in place (never a dated session log). Records where
> each kind of change lands in the docs, and DRIFT classes worth watching. Curated at `/wrapup`.

## Doc-surface recipes (where each change lands)
- **A slice ships/merges** → `docs/plan.md` *Current status* (dated line + decision count) **and**
  `HANDOVER.md` Status headline + "Last updated" date. If user-visible → also the `README.md`
  Features bullet, capability-level.
- **A new decision is recorded** → append to `docs/decisions.md` at the **bottom**, next number,
  today's date, matching the `## Decision N: title (YYYY-MM-DD)` + Context/Decided/Principle shape.
  Never renumber or rewrite; correct with a dated sub-note in place.
- **A migration changes schema/RPC/index** → `docs/database.md` only if it enumerates that
  convention; it is conventions, not a full schema dump. Read the **latest** RPC definition first
  (drop+recreate chain).
- **A file is renamed** → grep `docs/*.md`, `HANDOVER.md`, `README.md`, `CLAUDE.md`,
  `.claude/rules/*.md`, `.claude/agent-memory/**/MEMORY.md` for the old path; fix every hit.

## Recurring drift / doc-link patterns
- **Slice-series (like RPC-for-all-writes, multi-slice Decision):** when Slice N lands on a branch (not merged yet), update `plan.md` *Current status* bullet to show Slice N on-branch + "pending /fullpush/PR/merge/deploy", AND update *Next slice* section to list Slice N as done + point at next actionable (Slice N+1). Same pass for `HANDOVER.md` Status headline + RESUME line. Pattern: "BUILT ON BRANCH (commit hash, branch name), pending /fullpush/PR/merge/deploy → then Slice N+1". Both docs together — partial updates cause extra commits.

## Known false-positive traps (do NOT record as DRIFT)
- Missing `auth.uid()` / owner-scoping in an RPC → **expected pre-auth** (issue #3), not a
  `database.md` #6 contradiction. Flips to a real update only when auth lands.
- `with check (true)` on a write policy → intentional pre-auth, not weak-policy drift.
- `drop function if exists …; create or replace …` to change an RPC signature → the **correct**
  pattern here (avoids PGRST203), not a regression to re-document.
- `docs/database.md` is conventions, not a schema mirror — a new column that doesn't change a
  stated convention needs **no** database.md edit.
