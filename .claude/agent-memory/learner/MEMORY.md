# learner — memory

> Cross-agent pattern tracker, curated in place (never a dated session log — history is in git;
> `git log -p` for the full narration behind any trimmed row). Aggregates the post-commit reviewers'
> findings and tracks which recur toward a rule change. Curated at `/wrapup`.

## Issue Frequency Tracker (rows transition, never deleted)
State machine: `WATCHING ──(Count reaches 2 across different commits)──▶ RULE CANDIDATE
──(rule written)──▶ PROMOTED → <rule loc>`; side exits `RESOLVED` / `RESOLVED-WATCH` / `FALSE
POSITIVE`. Count increments only for a **distinct-mechanism** recurrence, not a re-mention. Read
columns by header, not position.

| Issue Type | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|
| `setState(() => …)` arrow discards a returned Future (invisible to analyze; tests only). First: Contacts `fa4fc45`. | 2 | 3a87cc8 | PROMOTED → `analysis_options.yaml` `discarded_futures` (`0e4a7af`) |
| RLS/soft-delete linchpin verify-curl run live but not recorded in `backend/README.md` (red-team re-raises). First: #13→#19. | 2 | 3296258 | PROMOTED → `docs/database.md` #11 (`4911243`); held clean across all of Decision 26 → RESOLVED-WATCH. |
| Rule reversal mid-multi-slice migration leaves a contradictory sibling doc-comment / migration header citing the OLD rule. First: D25 amendment mismatch (crlocal). | 2 | 3296258 | PROMOTED → `CLAUDE.md` "How we work". Divergent-slice test PASSED at `3296258` (nothing stale reached main); but sweep is leaky at plan stage — see subsection-hiding watch below. |
| **Refinement:** stale rule-reversal citations hide in secondary summaries & decision-entry SUBSECTIONS (Impl/Why-safe/Principle), not the obvious rule line. First: `3296258`. | 1 | 3296258 | WATCHING — single commit, do NOT sharpen `CLAUDE.md` yet. doc-updater has the mechanical lesson ("grep the WHOLE file + every subsection"). Next reversal leaking same way → RULE CANDIDATE. |
| **`toRpcParams()` spread must match the RPC's param list exactly or PostgREST throws PGRST202.** Body-only `update_*` / mismatched-arity `create_*` → blind `{...toRpcParams()}` sends a param the fn lacks. First: `1e7574d` (`update_comment` body-only). | 2 | 258cb6c | RULE CANDIDATE — recurred at tasks `258cb6c` (`create_task` arity). Propose ONE line under `docs/database.md` #2. Both caught at PLAN time (plan-critic); rule makes it explicit so it's not re-derived. |
| **Width/breakpoint widget tests need a deterministic surface-size lever + teardown** — `setSurfaceSize()` OR `view.physicalSize`+`devicePixelRatio` (logical=physical/DPR), then `addTearDown(reset)` or the fake size leaks into siblings. First: `4679504`. | 2 | 16ed89e | RULE CANDIDATE — recurred at Contacts master-detail `16ed89e` (clean). Missing teardown silently corrupts siblings; NOT gated by analyze/lint/hooks/CR. Propose ONE line under `docs/design-principles.md` (beside the two-pane breakpoint convention). |
| **Master-detail content-area shape:** a `LayoutBuilder` at the content pane picks single vs two-pane at a breakpoint, both panes render from ONE shared body-builder keyed by selected-id. First: `16ed89e`. | 1 | 16ed89e | WATCHING — first master-detail slice (Slice A sidebar was a DIFFERENT pattern — don't conflate). Next entity reusing the shape → count 2 → RULE CANDIDATE (`docs/design-principles.md`). |
| **Unbounded `Text` in a header/nav Row overflows RenderFlex** under long content / large textScaler; fix = `Flexible`+`TextOverflow.ellipsis`, or `TextScaler.noScaling` for a fixed glyph. Invisible to analyze. First: `5c1cefd` (latent). | 2 | 194ff12 | RULE CANDIDATE — recurred CONCRETE at `194ff12` (real 8.4px overflow in `_MasterHeader`, fixed via `Flexible`); impl-critic predicted it at Slice A. Propose ONE line under `docs/design-principles.md` beside the `textScaler` principle. NOT gated. |
| **Programmatic text-field clear needs a State-owned `TextEditingController` (+`dispose`), NOT a mirror `String`** — a ✕-clear must call `controller.clear()`, unreachable if text lives only in a mirror var. Invisible to analyze. First: `194ff12` (plan-critic, fixed pre-build). | 1 | 194ff12 | WATCHING — single sighting, NO rule. code-reviewer's tracker notes this slice owns+disposes `_search`. Future field re-deriving mirror-then-can't-clear → count 2 → RULE CANDIDATE. |
| **Removing a widget/affordance: the plan's Tests section under-enumerates the sibling tests that assert it** — a removed text/type is an incidental proxy in OTHER tests; grep the WHOLE test file, not just renamed tests. First: `cfbfe7f` (plan-critic caught 2 sibling tests). | 1 | cfbfe7f | WATCHING — single sighting, NO rule. DISTINCT from the rule-reversal grep (docs vs tests). plan-critic owns row. Recurs → generalize the `CLAUDE.md` sweep line to "removal/reversal → grep sibling surface, docs AND tests". See removal-sweep cluster below. |
| **Extracting a shared widget out of its one parent needs parent-agnostic standalone tests** — pre-extraction it was only exercised via its host, so the new file has ZERO own tests until test-writer adds them. First: `078d03c` (test-writer added 2, suite green). | 1 | 078d03c | WATCHING — single sighting, NO rule; test-writer HANDLED it in-cycle (positive). DISTINCT from reviewer-driven `_MetaLine` dedup (after-the-fact). Future extraction landing untested → count 2 → RULE CANDIDATE (`CLAUDE.md`/`design-principles.md`). |
| **A component-level `ThemeData` override silently defeats a variant constructor** — `theme.dart`'s `filledButtonTheme` pins EVERY `FilledButton` incl `.tonal` to `scheme.primary`; a "subtle" tonal rendered identical to primary. LIVE-QA only. Fix = `SubtleButton` atom. First: `cfbfe7f`. | 1 | cfbfe7f | WATCHING — single sighting, NO rule. Captured at `subtle_button.dart` dartdoc + code-reviewer tracker. Future variant (`.tonal`/`.outlined`) defeated by an override → count 2 → RULE CANDIDATE (`docs/design-principles.md`). |
| **Read-only entity leaves a write affordance live — incl. STATE-DEPENDENT ones** (open inline editor, submit-on-enter). First: archived `TaskFormScreen` `58b2b5d`→`258cb6c`. | 2 | adab034 | RULE CANDIDATE — recurred DISTINCT-mechanism at `CommentsSection` `643bbeb`→fixed `adab034` (inline-edit branch keyed on `_editingId` alone, not `readOnly`). **learner-PROPOSED this cycle → `docs/design-principles.md`**; semantic-reviewer owns the row (already RULE CANDIDATE, count 2). Not gated by analyze/lint/hooks/CR. Mark PROMOTED once written. |
| **Byte-faithful per-parent repository duplication** — `SupabaseTaskCommentsRepository` ≈ `SupabaseEventCommentsRepository` (~70 lines, 6 strings differ). First: `adab034`. | 1 | adab034 | WATCHING — code-reviewer-owned; interface docstring commits to N per-parent impls, extraction pays off at **N=3**. Now N=2 → NO promotion. A 3rd `*_comments` repo → count 2 → RULE CANDIDATE (shared base/generic repo). |

## Durable cross-agent lessons (edit in place; don't stack)
- **`setState(() => Future)` is invisible to analyze** (legal void-context arrow; no `flutter_lints`
  rule). Twice a runtime bug caught only by tests (`fa4fc45`, `3a87cc8`). Now double-gated by the
  `discarded_futures` lint (`0e4a7af`); noise caveat — it also flags intentional fire-and-forget,
  which need `unawaited(...)` / `// ignore`.
- **red-team's "record the curl" is structural, not per-slice.** Each RLS/soft-delete slice runs a
  linchpin curl live but doesn't write it down, so red-team re-raises. DB-doc convention (`4911243`)
  stops it; held across Decision 26 (proactively recorded at `1988e26`, no re-raise).
- **Rule reversals mid-multi-slice migration are a doc-hygiene hazard.** A slice flipping a global
  rule leaves sibling doc-comments/headers citing the OLD rule. PROMOTED to `CLAUDE.md` + plan-critic
  greps at plan time (covers <10-line changes that skip plan-critic). Not double-gated. Divergent
  test PASSED at `3296258` but the sweep is leaky at plan stage — 3 stale spots hid in non-obvious
  places (README "Conventions" bullet, D23 main bullet, D23 *Impl* subsection); layered gates caught
  all 3 (plan-critic 2, doc-updater 1). Refinement WATCHING (count 1): stale cites concentrate in
  secondary summaries & decision subsections. Do NOT sharpen `CLAUDE.md` on one sighting.
- **Emerging meta-cluster: "under-scoped sibling-surface sweep on a model-shape change" (do NOT
  promote — mixed mechanisms, only one at count ≥2).** plan-critic has FOUR rhyming rows: (a)
  rule-reversal → grep docs (PROMOTED, count 3, `CLAUDE.md`); (b) remove a model write-method → grep
  `test/` + dead helpers (count 1); (c) remove a widget → grep the whole test file (count 1,
  `f39649f`); (d) ADD an optional scalar → reconstructing fakes silently DROP it + exact-map
  `toRpcParams()` assertion breaks on the new `p_*` key (count 1, `5cfc2b3`). Common shape: a slice
  ADD/REMOVE/REVERSE of a model surface X, plan enumerates only obvious sites, misses siblings. Each
  concrete mechanism except (a) is count 1 → NO rule (all four caught by plan-critic, no leak). Trip:
  if ANY test-surface mechanism (b/c/d) recurs → BROADEN the `CLAUDE.md` rule-reversal-sync line to
  "grep docs AND `test/` (reconstructing fakes + exact-map assertions) on any model field/method/
  affordance change (add OR remove)", not a second convention. NOT gated (surfaces at `flutter test`).
- **A CREATE OR REPLACE recreating an RPC to add ONE param must re-carry the WHOLE prior body**
  (SECURITY DEFINER, `SET search_path`, `deleted_at is null` guard, `if not found raise`, trims) — a
  terse "also set notes=…" risks dropping guards. Once (plan-critic ISSUE, `5cfc2b3`, folded in). Log
  & watch; the delta must not amputate the proven template. Promote if a future param-add drops a guard.
- **`state-lift-vs-widget.x` trap (impl-critic count 1, `cfbfe7f`) RESOLVED in-slice.** A thin host
  whose dynamic AppBar title reads `widget.task` (frozen at push) while mutation lives in the child
  via `onChanged` → in-place archive/restore leaves the title stale. Fixed via `late _task` +
  `setState` in `onChanged`. Const-title hosts (ContactDetailScreen) are immune. Promote if a future
  dynamic-title host re-derives the frozen read.
- **Decision 26 (RPC for all writes) COMPLETE — 4/4 slices clean incl. the divergent one (RESOLVED).**
  The RPC-write boilerplate (drop+recreate, `SET search_path`, revoke-from-public, `toRpcParams`,
  `.rpc()`+re-select) is a proven low-risk shape — spend attention on per-entity deltas. event_comments
  diverged benignly (`using(true)` open SELECT → RPC for uniformity not necessity; RPC-then-refetch is
  strictly safer). Lesson: a well-templated port stays clean even when one entity diverges, provided
  the divergence is documented in the migration header.
- **The `toRpcParams()`↔RPC-arity seam is the recurring failure mode of the RPC-write shape** (count 2:
  `update_comment` body-only `1e7574d`, `create_task` arity `258cb6c`). Per-entity attention on ONE
  seam: does the spread send EXACTLY the params the RPC declares? Body-only `update_*` / arity mismatch
  → PGRST202. Fix: build the map explicitly (`{p_id,p_body}`) when it diverges from create-shape. Caught
  at PLAN time both times; a `database.md` #2 line makes it written. NOT gated (PGRST202 is runtime).
- **Read-only entity must gate EVERY write affordance — incl. STATE-DEPENDENT ones** (RULE CANDIDATE,
  count 2 distinct commits: archived `TaskFormScreen` `58b2b5d`→`258cb6c`; `CommentsSection` inline-edit
  `643bbeb`→`adab034`). Two distinct mechanisms of one root: (1) an *always-rendered* affordance left
  live (title field + Saves on an archived task); (2) a *conditionally-rendered* one — the inline editor
  rendered its Save on `_editingId` ALONE, so archiving with an editor open left a working Save the DB
  accepted (guard checks the still-live COMMENT, not the task). Occurrence (2) earns promotion: also gate
  affordances that key off their OWN local state, and clear that edit-state on the read-only flip
  (`didUpdateWidget`). Invisible to analyze/lint/hooks/CR — reachable runtime write, caught only by
  semantic review + regression test. **learner-PROPOSED → `docs/design-principles.md`.** D29 removed
  occurrence (1)'s exact site but the pattern stays live (any read-only section with a stateful inline
  editor). Mark PROMOTED → design-principles.md once written.
- **Byte-faithful per-parent repository duplication** (WATCHING, count 1, code-reviewer-owned,
  `adab034`): task-comments repo duplicates the event one (~70 lines). Interface docstring commits to N
  per-parent impls; extraction pays off at N=3. Now N=2 → NO promotion. 3rd `*_comments` repo → count 2
  → RULE CANDIDATE (shared base/generic repo). Do NOT pre-empt.

Watch-items carried from project conventions:
- Promotion threshold is **2× across different commits**. First sighting = log & watch, not a rule.
- Targets: `CLAUDE.md`, `docs/decisions.md` (append-only), `docs/database.md`, `docs/design-principles.md`,
  `.coderabbit.yaml` `path_instructions`, `analysis_options.yaml`.
- Don't propose anything already gated by `.githooks/` or an existing `.coderabbit.yaml` instruction.

## Known false-positive traps (don't promote these into rules)
- Missing `auth.uid()` / owner-scoping is **expected pre-auth** (issue #3). red-team's phase-flip watch
  (owner checks move INSIDE the RPCs when #3 lands, since SECURITY DEFINER bypasses RLS) is a legitimate
  forward-watch, NOT a present defect — don't promote while auth is unwired.
- `drop function if exists …; create or replace …` to change an RPC signature is **correct** (avoids
  PGRST203), not a breaking change.
- The `.coderabbit.yaml` SQL `path_instructions` demanding SECURITY DEFINER "check auth.uid()" is itself
  phase-unaware — if reviewers trip on it 2×, propose **softening** it, not enforcing it.
