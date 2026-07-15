# learner — memory

> Cross-agent pattern tracker, curated in place (never a dated session log — history in git;
> `git log -p` for narration behind any trimmed row). Aggregates post-commit reviewers' findings,
> tracks which recur toward a rule change. Curated at `/wrapup`.

## Issue Frequency Tracker (rows transition, never deleted)
State machine: `WATCHING ──(Count 2 across different commits)──▶ RULE CANDIDATE ──(rule written)──▶
PROMOTED → <rule loc>`; side exits `RESOLVED` / `RESOLVED-WATCH` / `FALSE POSITIVE`. Count
increments only for a **distinct-mechanism** recurrence. Read columns by header, not position.

| Issue Type | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|
| `setState(() => …)` arrow discards a returned Future (invisible to analyze; tests only). First: `fa4fc45`. | 2 | 3a87cc8 | PROMOTED → `analysis_options.yaml` `discarded_futures` (`0e4a7af`) |
| RLS/soft-delete linchpin verify-curl run live but not recorded in `backend/README.md` (red-team re-raises). First: #13→#19. | 2 | 2b100b7 | PROMOTED → `docs/database.md` #11 (`4911243`); RESOLVED-WATCH (held at `2b100b7`, minor coverage nit only). |
| Rule reversal mid-multi-slice migration leaves a contradictory sibling doc-comment/migration-header citing the OLD rule. First: D25 amendment mismatch. | 3 | b5486f0 | PROMOTED → `CLAUDE.md` "How we work" + plan-critic greps at plan time. Nothing stale reached main. Two count-1 non-DB variants at `b5486f0` (see meta-cluster f/g) NOT yet re-tightened. |
| **Refinement of ↑:** reversal sweep misses SECONDARY stale surfaces *within an already-touched file* — summary/conventions blocks + decision-entry SUBSECTIONS (Context/Impl/Principle), not the obvious rule line. First: `3296258`. | 2 | d549d45 | **PROMOTED → `CLAUDE.md` "How we work"** (rule-reversal paragraph, `d549d45`). Recurred `d549d45` (plan sweep missed D33 decisions.md L390-391 + plan.md L41/L67-68; proposed skipping migration headers Slices 2/3 fixed in-slice; plan-critic caught it, REVISE), reaching count 2 → folded ONE clause into the binding CLAUDE.md rule: "grep the WHOLE of each touched file + every decisions-ledger subsection, not just the first citation". Deliberately NOT a `/fullpush` grep gate (semantic, un-greppable per-slice → would double-gate plan-critic+doc-updater). |
| **`toRpcParams()` spread must match RPC param list exactly or PGRST202.** Body-only `update_*` / mismatched-arity `create_*` → blind `{...toRpcParams()}` sends a param the fn lacks. First: `1e7574d`. | 2 | 258cb6c | RULE CANDIDATE — recurred `258cb6c` (`create_task` arity). Propose ONE line under `docs/database.md` #2. Both caught at PLAN time. |
| **Defaulted write-param on an RPC turns caller OMISSION into SILENT data loss** — `update_task.p_contacts` had a DEFAULT, stale caller dropping it silently WIPES People. Fix = drop default → REQUIRED → loud PGRST202. Fleet MISSED at `f8467d1`; cloud CR caught. First: `3b0468a`. | 1 | 3b0468a | NEAR MISS / WATCHING — inverse face of the arity seam ↑. If EITHER recurs, `database.md` #2 line covers BOTH: spread matches exactly AND write-params REQUIRED (no DEFAULT on update-writes). |
| **Width/breakpoint widget tests need a deterministic surface-size lever + teardown** — `setSurfaceSize()` or `view.physicalSize`+DPR, then `addTearDown(reset)` or size leaks into siblings. First: `4679504`. | 2 | 16ed89e | RULE CANDIDATE — recurred `16ed89e`. NOT gated by analyze/lint/hooks/CR. Propose ONE line under `docs/design-principles.md` (beside two-pane breakpoint convention). |
| **Master-detail content-area shape:** `LayoutBuilder` at content pane picks single vs two-pane at a breakpoint; both panes render from ONE shared body-builder keyed by selected-id. First: `16ed89e`. | 1 | 16ed89e | WATCHING — first master-detail slice. Next entity reusing shape → count 2 → RULE CANDIDATE (`design-principles.md`). |
| **Unbounded `Text` in a header/nav Row overflows RenderFlex** under long content / large textScaler; fix = `Flexible`+ellipsis or `TextScaler.noScaling`. Invisible to analyze. First: `5c1cefd`. | 2 | 194ff12 | RULE CANDIDATE — recurred CONCRETE `194ff12` (8.4px overflow in `_MasterHeader`). Propose ONE line under `design-principles.md` beside the `textScaler` principle. NOT gated. |
| **Programmatic text-field clear needs a State-owned `TextEditingController`(+`dispose`), NOT a mirror `String`** — ✕-clear must call `controller.clear()`. Invisible to analyze. First: `194ff12`. | 1 | 194ff12 | WATCHING — code-reviewer notes this slice owns+disposes `_search`. Recurs → count 2 → RULE CANDIDATE. |
| **Removing a widget/affordance: plan's Tests section under-enumerates SIBLING tests that assert it** (removed text/type is an incidental proxy). Grep the WHOLE test file. First: `cfbfe7f`. | 1 | cfbfe7f | WATCHING — DISTINCT from rule-reversal grep (docs vs tests). plan-critic owns. See removal-sweep meta-cluster. |
| **Extracting a shared widget out of its one parent needs parent-agnostic standalone tests** — pre-extraction only exercised via host, new file has ZERO own tests. First: `078d03c` (test-writer added 2, green). | 1 | 078d03c | WATCHING — test-writer HANDLED in-cycle. Future extraction landing untested → count 2 → RULE CANDIDATE. |
| **A component-level `ThemeData` override silently defeats a variant constructor** — `filledButtonTheme` pinned `.tonal` to primary; "subtle" rendered identical. LIVE-QA only. Fix = `SubtleButton` atom. First: `cfbfe7f`. | 1 | cfbfe7f | WATCHING — captured at `subtle_button.dart` dartdoc + code-reviewer. Future variant defeated by an override → count 2 → RULE CANDIDATE (`design-principles.md`). |
| **Read-only entity leaves a write affordance live — incl. STATE-DEPENDENT ones** (open inline editor, submit-on-enter). First: archived `TaskFormScreen` `58b2b5d`→`258cb6c`. | 2 | adab034 | RULE CANDIDATE — recurred distinct-mechanism `CommentsSection` inline-edit `643bbeb`→`adab034` (Save keyed on `_editingId` alone, not `readOnly`). **learner-PROPOSED → `design-principles.md`**; semantic-reviewer owns. NOT gated. Mark PROMOTED once written. |
| **Byte-faithful per-parent DUPLICATION** — repo (`Supabase{Task,Event}CommentsRepository` ~70 lines) `adab034`; widget (`_PeopleSection`≈`_AttendeesSection`) `2b100b7`. | 1 | 2b100b7 | WATCHING — code-reviewer-owned. Interface commits to N per-parent impls; extraction pays off at **N=3**, now N=2 → NO promotion. A 3rd `*_comments` repo OR contact-roster parent → count 2 → RULE CANDIDATE. Deliberate deferral, not a defect. |
| **Stale sibling INLINE COMMENT cites OLD `p_*` param shape after an RPC gains a param** — `tasks_repository.dart` said `{p_title,p_notes}` after `p_contacts` landed. Prose drift, NOT runtime PGRST202. First: `2b100b7`. | 1 | 2b100b7 | WATCHING — meta-cluster sub-mechanism (e). DISTINCT from arity RULE CANDIDATE (runtime) + rule-reversal (rule flip). Recurs → broadens the CLAUDE.md sibling-sweep line to cover param ADD. |
| **Hand-authored `backend/README.md` verify curl cites NON-EXISTENT RPC params** — `create_contact` curl used `p_birthday`/`p_notes` vs actual `p_dob`/`p_remarks`. First: `d549d45` (impl-critic REVISE, fixed in-cycle). | 1 | d549d45 | WATCHING — cousin of sub-mechanism (e) (param drift in prose/curls vs Dart comment). Recurs → fold into the same sibling-sweep broadening. |
| **Doc surface states `auth.uid()` as PRESENT-TENSE requirement while YAML/rule #2 phase-defer it** — `docs/database.md` #6. First: `d549d45` (coderabbit-sync ISSUE, fixed in-cycle). Superseded same day by **Decision 37 (no auth — single-user + tailnet-only, `auth.uid()` is WON'T-DO)**, so #6 now reads "no auth planned" not "deferred". | 1 | d549d45 | WATCHING — phase-caveat on a NEW doc surface. Recurs on another surface → propose a phase-aware clarification pass, NOT enforcement (see false-positive traps). |

## Durable cross-agent lessons (edit in place; don't stack)
- **`setState(() => Future)` invisible to analyze** — twice a runtime bug caught only by tests; now
  double-gated by `discarded_futures` (`0e4a7af`). Noise caveat: also flags intentional
  fire-and-forget → needs `unawaited(...)`/`// ignore`.
- **red-team's "record the curl" is structural, not per-slice** — DB-doc convention (`4911243`)
  stops the re-raise; held across Decision 26 (`1988e26`).
- **Rule-reversal-sync (PROMOTED, count 3) + its refinement (PROMOTED, count 2) — both in `CLAUDE.md`.**
  The binding rule catches sibling FILES; the recurring miss was SECONDARY surfaces WITHIN a touched
  file + ledger subsections. As of `d549d45` that refinement is folded into the same CLAUDE.md
  paragraph (whole-file + every ledger subsection), so the plan author reads it at plan time.
  Deliberately NOT a mechanical `/fullpush` grep (semantic, per-slice phrasing; plan-critic+doc-updater
  already gate it). Every recurrence was caught in-cycle — the clause reduces re-derivation, does not
  plug a leak.
- **Meta-cluster: "under-scoped sibling-surface sweep on a change" (do NOT promote — mixed
  mechanisms, only rule-reversal at count ≥2).** plan-critic rhyming rows: (a) rule-reversal→grep
  docs (PROMOTED, `CLAUDE.md`); (b) remove model write-method→grep `test/`+dead helpers (count 1);
  (c) remove widget→grep whole test file (count 1); (d) ADD optional scalar→reconstructing fakes
  DROP it + exact-map `toRpcParams()` assertion breaks (count 1); (e) ADD `p_*` param→sibling INLINE
  COMMENT cites old shape (count 1); (f) change operative RULE-NUMBER→`.claude/commands`|`agents`
  file restating it goes stale (count 1, `b5486f0`); (g) same-file OWED-LIST twin — status line
  updated, "Owed"/"Next" list still cites shipped item (count 1, `b5486f0`). All count 1, all caught
  in-cycle, NO leak → NO rule. Trip: if any recurs → BROADEN the CLAUDE.md sweep line ("grep docs,
  sibling COMMENTS, `test/` fakes+exact-map assertions, AND `.claude/commands`|`agents`
  number-restatements + same-file owed/status lists on any field/method/affordance/`p_*`/rule-number
  change, add OR remove"), NOT a second convention. NOT gated (surfaces at test/review).
- **CREATE OR REPLACE recreating an RPC to add ONE param must re-carry the WHOLE prior body**
  (SECURITY DEFINER, `SET search_path`, `deleted_at is null` guard, `if not found raise`, trims).
  Once (`5cfc2b3`, folded). Promote if a future param-add drops a guard.
- **`state-lift-vs-widget.x` (impl-critic, `cfbfe7f`) RESOLVED in-slice** — thin host's dynamic
  AppBar title read `widget.task` (frozen at push) while mutation lived in child → stale title. Fix:
  `late _task`+`setState` in `onChanged`. Const-title hosts immune. Promote if it recurs.
- **RPC-write shape is proven-low-risk (Decision 26 COMPLETE, 4/4 clean)** — boilerplate
  (drop+recreate, `SET search_path`, revoke-from-public, `toRpcParams`, `.rpc()`+re-select) stays
  clean even when one entity diverges, provided the divergence is documented in the migration header.
  Spend attention on per-entity deltas. **Decision 36 (`d549d45`) hardened it to the SOLE write
  path** (revoked anon direct grants + PUBLIC execute).
- **The `toRpcParams()`↔RPC-arity seam is the recurring failure of the RPC-write shape** (count 2:
  `1e7574d`, `258cb6c`). Per-entity: does the spread send EXACTLY the declared params? Body-only /
  arity mismatch → PGRST202; build the map explicitly when it diverges from create-shape. Inverse
  near-miss (count 1, `3b0468a`): a DEFAULT write-param → omission silently WIPES. One `database.md`
  #2 line covers both faces. Caught at PLAN time; NOT gated (runtime).
- **Read-only entity must gate EVERY write affordance — incl. STATE-DEPENDENT** (RULE CANDIDATE,
  count 2: `TaskFormScreen` `58b2b5d`→`258cb6c`; `CommentsSection` inline-edit `643bbeb`→`adab034`).
  Also gate affordances keyed off their OWN local state, and clear edit-state on the read-only flip
  (`didUpdateWidget`). NOT gated — semantic review + regression test only. **learner-PROPOSED →
  `design-principles.md`**; mark PROMOTED once written.

Watch-items carried from project conventions:
- Promotion threshold is **2× across different commits**. First sighting = log & watch, not a rule.
- Targets: `CLAUDE.md`, `docs/decisions.md` (append-only), `docs/database.md`,
  `docs/design-principles.md`, `.coderabbit.yaml` `path_instructions`, `analysis_options.yaml`.
- Don't propose anything already gated by `.githooks/` or an existing `.coderabbit.yaml` instruction.

## Known false-positive traps (don't promote these into rules)
- Missing `auth.uid()` / owner-scoping is **WON'T-DO (Decision 37)** — single-user + tailnet-only, so
  there is no auth and none is planned; it is out of scope, not a present defect (and not "deferred
  to #3"). The "owner checks move INSIDE RPCs when auth lands" note is a conditional fallback only IF
  the no-auth decision is ever revisited (sharing / public exposure / multi-tenant).
- `drop function if exists …; create or replace …` to change an RPC signature is **correct** (avoids
  PGRST203), not a breaking change.
- ~~The `.coderabbit.yaml` SQL `path_instructions` demanding SECURITY DEFINER "check auth.uid()"~~ —
  RESOLVED: as of Decision 37 the yaml explicitly says "do NOT flag missing auth.uid()" (no auth is
  planned), so there is no phase-unaware demand left to soften.
