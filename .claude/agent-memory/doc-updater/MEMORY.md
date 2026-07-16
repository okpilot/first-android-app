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
- **Slice-series (like RPC-for-all-writes, multi-slice Decision):** when Slice N lands on a branch (not merged yet), update `plan.md` *Current status* bullet to show Slice N on-branch + "pending /fullpush/PR/merge/deploy", AND update *Next slice* section to list Slice N as done + point at next actionable (Slice N+1). Same pass for `HANDOVER.md` Status headline + RESUME line. Pattern: "BUILT ON BRANCH (commit hash, branch name), pending /fullpush/PR/merge/deploy → then Slice N+1". Both docs together — partial updates cause extra commits. **When multiple slices (A+B, …) land on ONE shared branch:** summarize both in a single *Current status* bullet and a single HANDOVER status block; list each slice's number, show commit hashes for each slice in order; fold the history into the amendment note (dated, e.g. "Amended (2026-07-12 — Slice B committed)"). **Update *Next slice* to the next actionable after the series** (not after Slice A alone).
- **Widget extraction / refactor for follow-on slices** (e.g. `CommentsSection` extract enabling task comments): update `plan.md` *Current status* + `HANDOVER.md` Status + RESUME to name the refactor slice (e.g. "Slice 2a") as on-branch, note it as behavior-preserving, and point RESUME at the follow-on slice (Slice 2b). **Append a Decision line WHEN the refactor embodies an explicit architectural CHOICE** the user made (e.g. Decision 32: extract ONE shared widget vs. copy it — a precedent with forward consequences); a purely mechanical extraction with no such choice needs no Decision. Both docs together.
- **Rule-reversal sweep (Decision 26 Slice 3):** in a reversal, **grep the WHOLE of each touched file + every subsection of the decisions ledger** (not just main bullets). Implementation/Why safe/Principle sections can have factual statements contradicted by code. Decision 23's "Implementation" still said "direct-CRUD repository" when code now uses RPCs — caught as DRIFT post-commit, fixed with dated amendment. The in-commit sweep may miss these subsections.

## Recent syncs (commit snapshots; trim after /wrapup curates)
- **2026-07-16, Decision 43 (780c9309):** plan.md (Current status — D43 above D42; decision count 42→43 + D43 appended to decision list) + decisions.md (D43 appended by session) + HANDOVER.md (Status headline — item 2 **committed on branch `slice/shared-detail-field`**, `/fullpush`/push/PR pending; "Last updated" date). Widget refactor slice (non-user-facing); **No README.md / database.md update needed.** No DRIFT. Decision records synced; **Issue #10 remains OPEN — closes only on merge** (item 1 = D42 merged PR #50; item 2 = D43 still on the branch). *(Corrected: an earlier draft over-stated this as "Issue #10 CLOSED" / merged — the lifecycle over-claim learner tracks; read git state before writing merged/deployed.)*
- **2026-07-16, Decision 42 (a08c199):** plan.md (Current status + decision count 41→42 + Decision 42 bullet + decision list update D41/D42) + decisions.md (Decision 42 already appended by session) + HANDOVER.md (Status headline + "Last updated" date + RESUME line). Test infrastructure slice (non-user-facing); **No README.md / database.md update needed.** No DRIFT. CLAUDE.md deliberately untouched — the rule about "every reconstructing fake" stayed in place (full-CRUD fakes remain file-local per the extraction boundary).
- **2026-07-15, Decision 40 Slice B (d95f85b on-branch):** plan.md (Current status + decision count 39→40 + Slice B on-branch as first bullet + Next slice pointer) + decisions.md (Decision 40 appended) + database.md (task_category_links subsection + updated RPC sigs + lockdown invariant note) + HANDOVER.md (Status + RESUME) + README Features (Task categories wording updated — "assign" not "arrive later"). **No DRIFT.** On-branch only, pending /fullpush/PR/merge/deploy. Pattern re-confirmed: Slice A (Slice B lands next) → Slice B (record at commit, on-branch state).
- **2026-07-15, Decision 39 Slice A (squash `df7afa7`):** plan.md (Current status + decision count 38→39 + Next slice to Slice B) + decisions.md (Decision 39 appended) + database.md (focused task_categories entry + 3 RPCs) + HANDOVER.md (Status + RESUME) + README Features (Task categories bullet). MERGED & DEPLOYED to homebase; `/updatelinux` + emulator QA done, `/updatephone` owed. **Lesson: I over-stated lifecycle status** — initially wrote "merged/deployed" while the slice was only committed on-branch, and promised Slice-B task-assignment in the README; both caught by the orchestrator + cloud CR. Stick to the verified state at commit time; never assume push/merge/deploy happened. **RECURRED `780c930` (D43 — over-claimed "MERGED & on main" vs branch-only) → count 2, distinct commits (learner). This is now a STANDING pre-write check, not a trimmable one-off: before writing any lifecycle word (committed / pushed / merged / deployed), read the actual state from git — never assume the next step happened.** Elevate this out of the trimmable "Recent syncs" prose so `/wrapup` can't prune it.
- **2026-07-15, Decision 38 (3bf48ea):** plan.md (Current status + decision count 37→38) + decisions.md (Decision 38 appended — already done) + database.md (RPC-recreate invariant note — already done) + HANDOVER.md (Status + Prior) + README Features (Task importance bullet). All surfaces synced post-commit; Decision 38 recorded, on-branch pending deploy. No DRIFT found.
- **2026-07-14, Decision 35 / issue #40 (b5486f0):** plan.md (Phone QA backlog clarified — device is back on tailnet) + decisions.md (Decision 35 appended, Decision 7 amended in place) + HANDOVER.md + README (no rule numbers cited as current). All surfaces synced post-commit; fleet-only rule/docs slice.
- **2026-07-14, Slice 2b (643bbeb):** plan.md + decisions.md (Decision 33) + database.md (#4 exception) + backend README + HANDOVER.md (Status + Prior Slice 2a) + README Features (task comments bullet). All surfaces synced post-commit; full fleet clean.

## Known false-positive traps (do NOT record as DRIFT)
- Missing `auth.uid()` / owner-scoping in an RPC → **expected pre-auth** (issue #3), not a
  `database.md` #6 contradiction. Flips to a real update only when auth lands.
- `with check (true)` on a write policy → intentional pre-auth, not weak-policy drift.
- `drop function if exists …; create or replace …` to change an RPC signature → the **correct**
  pattern here (avoids PGRST203), not a regression to re-document.
- `docs/database.md` is conventions, not a schema mirror — a new column that doesn't change a
  stated convention needs **no** database.md edit.
