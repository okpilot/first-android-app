# learner — memory

> Cross-agent pattern tracker, curated in place (never a dated session log — history in git;
> `git log -p` for narration behind any trimmed row). Aggregates post-commit reviewers' findings,
> tracks which recur toward a rule change. Curated at `/wrapup`.
> Row reasoning → [topics/tracker-detail.md](topics/tracker-detail.md); lessons → [topics/durable-lessons.md](topics/durable-lessons.md).

## Issue Frequency Tracker (rows transition, never deleted)
State machine: `WATCHING ──(Count 2 across different commits)──▶ RULE CANDIDATE ──(rule written)──▶
PROMOTED → <rule loc>`; side exits `RESOLVED` / `RESOLVED-WATCH` / `FALSE POSITIVE`. Count
increments only for a **distinct-mechanism** recurrence. Read columns by header, not position.

| Issue Type | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|
| `setState(() => …)` arrow discards a returned Future (invisible to analyze). First: `fa4fc45`. | 2 | 3a87cc8 | PROMOTED → `analysis_options.yaml` `discarded_futures` (`0e4a7af`) |
| RLS/soft-delete linchpin verify-curl run live but not recorded in `backend/README.md`. First: #13→#19. | 2 | 9377a61 | PROMOTED → `docs/database.md` #11 (`4911243`); RESOLVED-WATCH. `9377a61` recurrence = author skipped the promoted convention, red-team caught it in-cycle; gate held, no new rule. |
| **Docs-sync (base):** rule reversal mid-migration leaves a contradictory sibling doc-comment/migration-header citing the OLD rule. First: D25. | 3 | b5486f0 | PROMOTED → `CLAUDE.md` "How we work" + plan-critic greps at plan time. Nothing stale reached main. Two count-1 non-DB variants at `b5486f0` (meta-cluster f/g) not yet re-tightened. |
| **Docs-sync (refinement of ↑):** sweep misses SECONDARY stale surfaces *within an already-touched file* — summary blocks + decisions-ledger SUBSECTIONS, not the first citation. First: `3296258`. | 3 | d429a80 | PROMOTED → `CLAUDE.md` (`d549d45`) — but **recurred THROUGH the rule at `d429a80`**: trigger says "reverses a convention" (this was a **status flip**, `/updatephone` owed→done) and the subsection list "(Context/Impl/Principle)" omits **`Deploy note:`** — exactly where both twins rotted (D40:487, D41:499; verified by grep). **learner-PROPOSED → widen the SAME rule** (headline + open the subsection list). impl-critic row = originating RULE CANDIDATE. Detail → topics. |
| **`toRpcParams()` spread must match RPC param list exactly or PGRST202.** First: `1e7574d`. | 2 | 258cb6c | RULE CANDIDATE — propose ONE line under `docs/database.md` #2. Both caught at PLAN time. |
| **Field-add silently DROPS in hand-fakes that RECONSTRUCT the entity** + breaks exact-map `toRpcParams()` assertions. Invisible to analyze/lint/hooks/CR. First: `notes`. | 5 | D41/#9 | PROMOTED → CLAUDE.md field-add rule (3bf48ea); **HELD** ×5 (notes→contacts→importance→categories→`p_id`), test-writer catches in-cycle. Wrinkle (count 1): exposure-only adds may not trip the headline. MITIGATED by `test/support/fakes.dart` (D42). Detail → topics. |
| **Defaulted write-param on an RPC turns caller OMISSION into SILENT data loss** (`update_task.p_contacts` wipes People). Fleet MISSED; cloud CR caught. First: `3b0468a`. | 1 | 3b0468a | NEAR MISS / WATCHING — inverse face of the arity seam ↑. If EITHER recurs, one `database.md` #2 line covers both. |
| **Width/breakpoint widget tests need a deterministic surface-size lever + teardown** (`setSurfaceSize` + `addTearDown`, else size leaks). First: `4679504`. | 2 | 16ed89e | RULE CANDIDATE — propose ONE line under `docs/design-principles.md`. NOT gated. |
| **Master-detail content-area shape:** `LayoutBuilder` picks single vs two-pane; both panes from ONE body-builder keyed by selected-id. First: `16ed89e`. | 1 | 16ed89e | WATCHING — next entity reusing the shape → count 2. |
| **Unbounded `Text` in a header/nav Row overflows RenderFlex** under long content / large textScaler. Invisible to analyze. First: `5c1cefd`. | 2 | 194ff12 | RULE CANDIDATE — ONE line under `design-principles.md` beside the `textScaler` principle. NOT gated. |
| **Programmatic text-field clear needs a State-owned `TextEditingController`(+`dispose`)**, not a mirror `String`. First: `194ff12`. | 1 | 194ff12 | WATCHING. |
| **Removing a widget/affordance: plan's Tests section under-enumerates SIBLING tests** that assert it as an incidental proxy. First: `cfbfe7f`. | 1 | cfbfe7f | WATCHING — DISTINCT from the docs-sync grep (tests vs docs). plan-critic owns. |
| **Extracting a shared widget out of its one parent needs parent-agnostic standalone tests.** First: `078d03c`. | 1 | 078d03c | WATCHING — test-writer handled in-cycle. |
| **A component-level `ThemeData` override silently defeats a variant constructor** (`filledButtonTheme` pinned `.tonal`). LIVE-QA only. First: `cfbfe7f`. | 1 | cfbfe7f | WATCHING — captured at `subtle_button.dart` dartdoc. |
| **Read-only entity leaves a write affordance live — incl. STATE-DEPENDENT ones** (open inline editor, submit-on-enter). First: `58b2b5d`→`258cb6c`. | 2 | adab034 | RULE CANDIDATE — **learner-PROPOSED → `design-principles.md`**; semantic-reviewer owns. NOT gated. Mark PROMOTED once written. |
| **Byte-faithful per-parent DUPLICATION** — comments repo (N=2); chip-section/roster widget shape (N=3: People/Attendees/Categories). | 2 | d95f85b | RULE CANDIDATE for the WIDGET shape only — **design-debt, NOT a workflow rule** (documented mirrors, no recurring mistake): surface to user → extract a parameterised `ChipSection`+roster atom, à la `MetaLine`. Repo dup stays WATCHING at N=2. Detail → topics. |
| **Entity-agnostic byte-identical atom COPIED because it's PRIVATE (`_`)** — `_SwatchGrid` across two sibling screens; same slice REUSED public `TypeSwatch`. First: `9377a61`. | 1 | 9377a61 | WATCHING — SUGGESTION only. Next such copy → count 2 → RULE CANDIDATE. Detail → topics. |
| **Hand-authored screen test for a MIRRORED screen under-covers states the SIBLING already tests.** First: `9377a61`. | 1 | 9377a61 | WATCHING — test-writer backfilled 3 in-cycle. Next mirrored screen under-covering → count 2 (plan-critic Tests-section check). |
| **Stale sibling INLINE COMMENT enumerates OLD `p_*` param shape after an RPC gains a param** — repo `create()`/`update()` doc-comments. Both instances are linked-collection FIELD-ADDS. `2b100b7`; `d95f85b`. | 2 | d95f85b | RULE CANDIDATE — **learner-PROPOSED → fold ONE clause into the CLAUDE.md field-add rule** (tighter than broadening the docs-sync sweep, since both are field-adds). Caught in-cycle both times. NOT gated. |
| **Hand-authored `backend/README.md` verify curl cites NON-EXISTENT RPC params** (`p_birthday`/`p_notes` vs `p_dob`/`p_remarks`). First: `d549d45`. | 1 | d549d45 | WATCHING — cousin of the `p_*` prose-drift row ↑. Recurs → fold into the same broadening. |
| **`## Verify:` section intro names an RPC the block never exercises** — `update_event` named but uncalled; the only intro-named RPC with zero coverage across all 11 sections. First: `46a2cdc`/`d429a80`. | 1 | d429a80 | NEW / WATCHING — code-reviewer ISSUE, fixed in-cycle (the added guard-check turned out to be the section's STRONGEST: it's what stops `p_attendees:[]` wiping an archived event's roster). 2nd such section → count 2 → RULE CANDIDATE ("a `## Verify:` intro may only name RPCs the block calls"). code-reviewer owns. NOT gated. |
| **Coverage-partition rule stated by the WRONG discriminator** — D45's draft keyed "needs a privileged read" on *having a `deleted_at` column*; the real discriminator is **anon-invisibility**, so `event_attendees` (no column, hidden by the parent-live gate) was misfiled as "nothing to prove". First: `d429a80`. | 1 | d429a80 | NEW / WATCHING — semantic-reviewer ISSUE, fixed in-cycle (bullet rewritten into 3 explicit buckets, all 10 tables filed). Mechanism = a rule whose stated TEST is a proxy that diverges from its INTENT. Recurs → count 2 → RULE CANDIDATE. NOT gated. |
| **Doc surface states `auth.uid()` as PRESENT-TENSE requirement** while rule #2 phase-defers it. First: `d549d45`. Superseded by D37 (no auth = WON'T-DO). | 1 | d549d45 | WATCHING — recurs on another surface → propose a phase-aware clarification, NOT enforcement (see traps). |
| **A PRIVATE (`_`) hand-fake NAME denotes DIFFERENT behavior tiers across test files** → a mechanical "drop the `_`" rename mis-maps call sites. First: `a08c199`. | 1 | a08c199 | WATCHING — plan-critic caught at plan time (per-file name→class map); code-reviewer flagged the residual same-name hazard SAME commit → still count 1. plan-critic owns. |
| **doc-updater OVER-STATES lifecycle state** ("merged"/"deployed"/"#N CLOSED" for a branch-only commit). First: `df7afa7`. | 2 | c83cecb | **PROMOTED → 3 surfaces (`c83cecb`, D44)**: doc-updater def (*Lifecycle-state discipline* + DO-NOT #10) · `.coderabbit.yaml` `path_filters` exclude `**/*.md`+`.claude/**` · D44 records the split. **Self-application VERIFIED unprompted at `d429a80` → RESOLVED.** Detail → topics. |
| **`path_filters` md/`.claude` excludes have no local validator.** First: `c83cecb`. | 1 | c83cecb | WATCHING (verify-on-next-push) — first post-merge PR touching a root `.md` should draw NO cloud-CR review. Residual half of the row above. |
| **LOCAL dev DB silently drifts from `backend/migrations/`** — `init.sh` is `docker-entrypoint-initdb.d` (fresh-volume ONLY), so a long-lived volume rots as later migrations get hand-applied or not. Found `d429a80`: `create_contact` MISSING, `create_event` pre-D41 9-arg, `task_category_links` absent; any local curl-run since 2026-07-12 hit a stale schema. NO migration ledger locally (homebase has one). | 1 | d429a80 | **learner-PROPOSED → `backend/README.md`** (a factual invariant of the stack, NOT a pattern promotion — the count-2 threshold doesn't gate documenting a verified fact). Silently INVALIDATES the README's own 11 Verify blocks → the note belongs where the curls live. Thematically D45's own principle: a check that can't fail proves nothing. Currently recorded only in impl-critic's durable facts (an agent memory no curl-runner reads). |

## Durable cross-agent lessons (one-liners; full detail → [topics/durable-lessons.md](topics/durable-lessons.md), edit there)
- `setState(() => Future)` invisible to analyze → double-gated by `discarded_futures` (`0e4a7af`); noise: needs `unawaited`/`// ignore`.
- red-team's "record the curl" is structural → DB-doc convention (`4911243`), held across D26.
- Docs-sync is the fleet's #1 recurring miss: base ×3 + refinement ×3, both PROMOTED to CLAUDE.md; NOT a mechanical grep. **A PROMOTED rule can still under-fire** — when a pattern recurs *through* its own rule, fix the rule's TRIGGER, don't add a second rule (`d429a80`).
- Meta-cluster "under-scoped sibling-surface sweep" — do NOT promote (mixed mechanisms; only rule-reversal ≥2). Sub-mechs (a)-(g); (d) split to own row ×5, (e) fold to field-add rule ×2.
- CREATE OR REPLACE +1 param must re-carry WHOLE prior body (SEC DEFINER, `SET search_path`, soft-del guard). Once (`5cfc2b3`).
- `state-lift-vs-widget.x` (`cfbfe7f`) RESOLVED — dynamic AppBar title read frozen `widget.task`; fix `late _task`+setState.
- RPC-write shape proven-low-risk (D26 COMPLETE 4/4; D36 = SOLE write path). Spend attention on per-entity deltas.
- `toRpcParams()`↔RPC-arity seam = recurring RPC-write failure (×2 `1e7574d`,`258cb6c`); inverse DEFAULT-wipe near-miss (`3b0468a`). One `database.md` #2 line covers both.
- Read-only entity must gate EVERY write affordance incl. STATE-DEPENDENT (RULE CANDIDATE ×2). learner-PROPOSED → `design-principles.md`.
- Shared test fakes → `test/support/fakes.dart` (D42): share at ≥2-file dup, specials stay local. Rename trap: private fake NAME ≠ one behavior across files — map by BEHAVIOR.
- **Extract-a-duplicated-atom is SETTLED & ledger-recorded — do NOT re-propose as a rule (DO-NOT #4).** Lives in `decisions.md` D32/D42/D43. Paydown healthy: `InitialsAvatar`→`MetaLine`→`CommentsSection`→fakes(D42)→`DetailField`(D43). Surface remaining dups (chip-section N=3, `_SwatchGrid` N=1) as design-debt, not a workflow rule.
- Fix a recurring miss at its SOURCE agent, not via a downstream checker (D44: hardened doc-updater's def + blinded cloud CR to prose, shipped TOGETHER). Agent-def changes bite NEXT session (defs snapshot at start) → the first post-promotion session needs a manual assist + a verify-next-session row. **`d429a80` closed that loop: the rule self-applied unprompted → source-fix pattern VALIDATED, not just plausible.**
- **On a docs-only slice, spend the review budget on twin-surface greps, not on the artifact under test** (`d429a80`: every blocking finding across impl-critic r1+r2 was a stale doc twin; the curls/SQL/decision were clean from r1).
- Meta-obs (no action): D42→D43→D44→D45 = 4 consecutive debt-paydown slices (dup extraction ×2, process fix, verification backfill). Healthy maintenance cadence, not drift to promote.

Watch-items carried from project conventions:
- Promotion threshold is **2× across different commits**. First sighting = log & watch, not a rule.
- Targets: `CLAUDE.md`, `docs/decisions.md` (append-only), `docs/database.md`,
  `docs/design-principles.md`, `.coderabbit.yaml` `path_instructions`, `analysis_options.yaml`.
- Don't propose anything already gated by `.githooks/` or an existing `.coderabbit.yaml` instruction.

## Known false-positive traps (don't promote these into rules)
- Missing `auth.uid()` / owner-scoping is **WON'T-DO (Decision 37)** — single-user + tailnet-only, so
  there is no auth and none is planned; out of scope, not a present defect (and not "deferred to #3").
  The "owner checks move INSIDE RPCs when auth lands" note is a conditional fallback only IF the
  no-auth decision is ever revisited (sharing / public exposure / multi-tenant).
- `drop function if exists …; create or replace …` to change an RPC signature is **correct** (avoids
  PGRST203), not a breaking change.
- ~~The `.coderabbit.yaml` SQL `path_instructions` demanding SECURITY DEFINER "check auth.uid()"~~ —
  RESOLVED: as of D37 the yaml explicitly says "do NOT flag missing auth.uid()".
- **"Doc status word contradicts git ⇒ stale drift" is NOT sound for out-of-band actions** (`d429a80`,
  plan-critic CRITICAL → validated SKIP). `/updatephone` is a physical-device install: **git cannot
  record it**, so a doc saying "done" while git says "owed" may be CORRECT and the git-derived verdict
  wrong. This is the sharp EDGE of D44's "derive every lifecycle word from real git/gh" — that rule
  holds for git-observable states (committed/pushed/merged), NOT for device installs or homebase
  deploys. Before flagging such a claim, ask whether the action leaves a git trace at all. (Count 1 —
  if a 2nd git-derived verdict misfires on an out-of-band action, propose scoping D44's rule to
  git-observable lifecycle words.)
