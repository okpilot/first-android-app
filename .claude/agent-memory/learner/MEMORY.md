# learner — memory

> Cross-agent pattern tracker, curated in place (never a dated session log — history is in git).
> Aggregates the post-commit reviewers' findings and tracks which recur toward a rule change.
> Curated at `/wrapup`.

## Issue Frequency Tracker (rows transition, never deleted)
State machine: `WATCHING ──(Count reaches 2 across different commits)──▶ RULE CANDIDATE
──(rule written)──▶ PROMOTED → <rule loc>`; side exits `RESOLVED` (fix stops recurrence),
`RESOLVED-WATCH`, `FALSE POSITIVE`. Count increments only for a **distinct-mechanism** recurrence,
not a re-mention. Read columns by header, not position.

| Issue Type | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|
| `setState(() => …)` arrow returns a Future (async work discarded; not caught by analyze, only by tests). First: Contacts slice `fa4fc45`. | 2 | 3a87cc8 | PROMOTED → `analysis_options.yaml` `discarded_futures` enabled (`0e4a7af`) |
| RLS/soft-delete slice's linchpin verification curl run live but not recorded in `backend/README.md` (red-team re-raises). First: event-types #13 → follow-up #19. | 2 | 3296258 | PROMOTED → `docs/database.md` #11 (`4911243`); held clean across the rest of Decision 26 — `20970ea` (event_types Slice 2) and `3296258` (event_comments Slice 3: red-team 0/0, 2 INFO only, recommended curls, no re-raise). Convention held for the full migration; RESOLVED-WATCH. |
| A slice that reverses/rewrites a rule mid-multi-slice migration leaves a contradictory **sibling doc-comment / migration header** citing the old rule; a reviewer must catch it each time. First: Decision-25 amendment conditional/unconditional mismatch (caught by crlocal). | 2 | 3296258 | PROMOTED → `CLAUDE.md` "How we work" ("A rule reversal isn't done until its contradictions are gone", cites learner count 2). **First real divergent-slice test PASSED at `3296258`** (event_comments Slice 3, Decision 26 COMPLETE): all contradictions caught in-cycle — nothing reached main stale. Leaky-but-caught: 3 stale spots hid in NON-OBVIOUS locations (README "Conventions in play" bullet, D23 main bullet, D23 *Implementation* subsection) — plan-critic caught 2 pre-impl, doc-updater caught the subsection post-commit. See "subsection/summary hiding place" watch below. |
| **Refinement:** stale citations in a rule reversal hide in secondary summaries & decision-entry SUBSECTIONS (Implementation/Why-safe/Principle), not just the obvious rule line. First (only) sighting: `3296258`. | 1 | 3296258 | WATCHING — single commit, do NOT sharpen `CLAUDE.md` yet (over-fitting risk). doc-updater already recorded the mechanical lesson in its own tracker ("grep the WHOLE of each touched file + every subsection"). If a FUTURE rule reversal leaks the same way → RULE CANDIDATE (sharpen the CLAUDE.md sweep line to name subsections/summaries). |
| **`toRpcParams()` spread must match the RPC's parameter list exactly, or PostgREST throws PGRST202** (function-not-found for the sent arg set). A body-only `update_*` (no `p_event_id`) or a `create_*` with a different arity than the model builds → blind `{...model.toRpcParams()}` sends a param the fn lacks. First: event_comments Slice 3 `1e7574d` (`update_comment` body-only → repo builds `{p_id,p_body}` explicitly, NOT a spread). | 2 | 258cb6c | RULE CANDIDATE — recurred distinct-mechanism at tasks `258cb6c` (`create_task` arity trap, plan-critic ISSUE fixed in-plan). Propose ONE convention line under `docs/database.md` rule #2. Both hits caught at PLAN time by plan-critic (never reached runtime) → the rule makes the check explicit so it's not re-derived per slice. |
| **Width/breakpoint-parameterized widget tests need a deterministic surface-size lever + teardown.** A test that asserts responsive layout (sidebar vs bottom-nav; single-pane vs two-pane master-detail at a breakpoint) must drive width via `tester.binding.setSurfaceSize()` OR `tester.view.physicalSize` **and** `tester.view.devicePixelRatio` (logical width = physical/DPR — setting physicalSize alone is wrong if DPR≠1), then `addTearDown(reset)` so the fake size doesn't leak into sibling tests. First: desktop-sidebar Slice A `4679504`. | 2 | 16ed89e | RULE CANDIDATE — recurred distinct-commit at Contacts master-detail Slice B `16ed89e` (`test/contacts_master_detail_test.dart`: `setSurfaceSize` + `addTearDown`, applied cleanly, no finding). Two responsive tests now share the idiom and Decision 28 is a multi-slice adaptive initiative (more breakpoint tests coming). The footgun — a MISSING teardown silently corrupts sibling tests — is NOT gated by analyze/lint/hooks/CodeRabbit. Propose ONE line under `docs/design-principles.md` (co-located with the two-pane breakpoint convention it documents). |
| **Master-detail content-area shape: a `LayoutBuilder` at the content pane picks single-pane vs two-pane at a breakpoint, and BOTH panes render from one shared body-builder keyed by selected-id** (so list and detail can't diverge). First (only) sighting: Contacts master-detail Slice B `16ed89e`. | 1 | 16ed89e | WATCHING — first master-detail slice (Slice A was the app-shell sidebar/bottom-nav, a DIFFERENT structural pattern — don't conflate). Single sighting → log & watch, NO rule. If the NEXT entity (events/tasks per the future activity-view direction) reuses the same content-pane `LayoutBuilder` + shared-body-keyed-by-id shape → count 2 → RULE CANDIDATE (capture ONE line in `docs/design-principles.md`). |
| **Unbounded `Text` in a header/nav Row overflows RenderFlex** under long content / large textScaler; fix = wrap in `Flexible`+`TextOverflow.ellipsis`, or `TextScaler.noScaling` for a fixed-size brand glyph. Invisible to `flutter analyze` (runtime layout error, no lint). First: desktop-sidebar Slice A `5c1cefd` (latent watch — nav labels + `CRM+` wordmark guarded proactively; C⁺ glyph opts out). | 2 | 194ff12 | RULE CANDIDATE — recurred CONCRETE at Contacts-desktop-top Slice C `194ff12`: a real 8.4px RenderFlex overflow in `_MasterHeader` (fixed by making the title group `Flexible`), plus impl-critic SUGGESTION to wrap the count `Text` in `Flexible`. impl-critic predicted this exact footgun at Slice A ("non-`Flexible` Text in a fixed-width Row → latent extreme-textScaler overflow"); Slice C proved it. Propose ONE line under `docs/design-principles.md` beside the `textScaler` principle (line 79). NOT gated by analyze/lint/hooks/CodeRabbit — only runtime + visual QA. |
| **Programmatic text-field clear needs a State-owned `TextEditingController` (+`dispose`), NOT a mirror `String` in `setState`** — a ✕-clear / reset must call `controller.clear()`, unreachable if the field's text lives only in a mirror var. Flutter footgun invisible to analyze. First (only): Contacts search Slice C `194ff12` (plan-critic blocker, fixed pre-build). | 1 | 194ff12 | WATCHING — single sighting → log & watch, NO rule (over-fitting risk). code-reviewer's tracker already notes this slice owns+disposes the `_search` controller. If a FUTURE search/filter/input field re-derives mirror-state-then-can't-clear → count 2 → RULE CANDIDATE (`CLAUDE.md` NEVER-DO or a `docs/design-principles.md` line). |
| **When a slice REMOVES a widget/affordance, the plan's Tests section under-enumerates the sibling tests that assert it** — a removed widget/text/type (`'Mark complete'`, `Switch`, `TaskEditView`) is often used by OTHER tests as an incidental proxy for "the editable pane is here", so grep the WHOLE test file for that text/type, not just the tests the plan renames, or `flutter test` breaks on siblings the plan never named. First (only): tasks view-first `cfbfe7f` (plan-critic caught 2 sibling wide tests `:320`/`:359` pre-impl). | 1 | cfbfe7f | WATCHING — single sighting → log & watch, NO rule. This is a DISTINCT mechanism from the PROMOTED rule-reversal-sync (that grep is over DOCS for stale OLD-rule citations; this is over TESTS for references to a removed widget). plan-critic owns the row (count 1). If a FUTURE removal-slice breaks sibling tests the plan didn't enumerate → count 2 → RULE CANDIDATE (generalize the `CLAUDE.md` sweep line from "rule reversal → grep docs" to "removal/reversal → grep the whole sibling surface, docs AND tests"). See removal-sweep cluster note below. |
| **Extracting a shared widget out of the one parent that used it needs parent-agnostic standalone tests** — before extraction the widget was only ever exercised through its original host (e.g. `CommentsSection` via `EventDetailScreen`), so the new reusable file has ZERO tests of its own until test-writer adds them; the refactor is "behavior-preserving" only if the widget is proven to work independent of that one parent. First (only): task-comments Slice 2a `078d03c` (test-writer added 2 parent-agnostic tests to `test/comments_section_test.dart`, suite 129/129 green). | 1 | 078d03c | WATCHING — single sighting → log & watch, NO rule. test-writer HANDLED it cleanly in-cycle (positive signal), and the fleet was unanimously clean on this pure refactor. DISTINCT from the reviewer-driven `_MetaLine`→`MetaLine` dedup extraction (that was code-reviewer catching duplication AFTER the fact, count 2; this is a PLANNED pre-emptive extraction before the second consumer exists). If a FUTURE widget-extraction slice (e.g. Slice 2b wiring task comments to the shared widget) again lands a reusable widget with no standalone tests until test-writer backfills → count 2 → RULE CANDIDATE (ONE checklist line: "extraction slice → the extracted widget owns parent-agnostic tests in the same slice", target `CLAUDE.md` "How we work" or `docs/design-principles.md`). |
| **A component-level `ThemeData` override silently defeats a variant constructor of that component.** `theme.dart`'s `filledButtonTheme` pins EVERY `FilledButton` — including `FilledButton.tonal` — to `scheme.primary`, so a "subtle" tonal button rendered identical to the loud primary; only caught in LIVE QA (invisible to analyze/lint/tests — it's a rendered-colour outcome). Fix = a per-button container override (`SubtleButton`, `lib/widgets/subtle_button.dart`). First (only): tasks view-first `cfbfe7f`. | 1 | cfbfe7f | WATCHING — single sighting → log & watch, NO rule (2× threshold). Knowledge is ALREADY captured at two sites: `subtle_button.dart`'s own dartdoc ("Why not FilledButton.tonal?") + code-reviewer's tracker. If a FUTURE slice reaches for `FilledButton.tonal`/`.outlined`/another variant expecting a look the theme override defeats → count 2 → RULE CANDIDATE (ONE note in `docs/design-principles.md`: "component-level ThemeData overrides pin ALL variants — use a purpose atom for a subtle button, don't reach for `.tonal`"). Flagged for the main session: if the user wants this documented PROACTIVELY as a landmine (their framing), that override call is theirs to make now — I hold at watch per the threshold. |

## Durable cross-agent lessons (edit in place; don't stack)
- **`setState(() => Future)` is invisible to `flutter analyze`** (arrow returning a value in a void
  context is legal Dart; `flutter_lints` has no rule for it). It has surfaced twice as a runtime
  bug caught only by tests (`fa4fc45`, `3a87cc8`). The mechanical catch is the `discarded_futures`
  lint — now enabled in `analysis_options.yaml` (`0e4a7af`), so the pattern is double-gated (lint +
  tests). Noise caveat: it also flags intentional fire-and-forget, which need `unawaited(...)` /
  `// ignore: discarded_futures`.
- **red-team's "record the curl" finding is structural, not per-slice.** Each RLS/soft-delete
  slice runs a linchpin curl live to prove non-destructive delete, but it isn't written down, so
  red-team re-raises it every time (#19, then `3a87cc8`). A standing convention in the DB doc stops
  the re-derivation — and it held at `1988e26` (contacts Slice-1 curl recorded proactively, no
  re-raise). Watch it keeps holding across the remaining Decision-26 slices.
- **Rule reversals mid-multi-slice migration are a doc-hygiene hazard.** Decision 26 flips a
  *global* DB rule (rule #2 "not everything is RPC" → "all writes via RPC") one slice at a time.
  Each slice that flips the rule tends to leave a sibling repo doc-comment / migration header still
  citing the OLD rule (the event_types "…like contacts" comment; the Decision-25 conditional/
  unconditional mismatch). Now PROMOTED to a `CLAUDE.md` standing convention (+ `plan-critic` greps
  at plan time) so it's covered even on <10-line changes that skip `plan-critic`. Not double-gated
  (no hook/lint/CodeRabbit instruction catches a stale doc-comment). **First real divergent-slice
  test PASSED at `3296258`** (event_comments Slice 3): nothing stale reached main. But the sweep is
  *leaky at the plan stage* — 3 stale spots hid in non-obvious places (README "Conventions" bullet,
  D23 main bullet, D23 *Implementation* subsection); the fleet's layered gates caught all three
  (plan-critic 2, doc-updater 1 post-commit) but the initial plan grep missed them. Refinement now
  WATCHING (count 1): stale citations concentrate in **secondary summaries & decision-entry
  subsections**, not the obvious rule line. Do NOT sharpen `CLAUDE.md` on this single sighting —
  if the next reversal leaks the same way, promote the sharpening then.
- **Emerging meta-cluster: "under-scoped sibling-surface sweep on a model-shape change" (do NOT
  promote yet — mixed mechanisms, only one at count ≥2).** plan-critic now has FOUR rhyming rows:
  (a) rule-reversal → grep docs for stale OLD-rule citations (PROMOTED, count 3, `CLAUDE.md`);
  (b) remove a model write-method → grep `test/` + check dead private helpers/dartdoc (count 1);
  (c) remove a widget/affordance → grep the WHOLE test file for its text/type (count 1, `f39649f`);
  (d) **ADD an optional scalar field → reconstructing fakes (`_StatefulTasksRepo.create/archive/
  restore` rebuild `Task(...)` from scratch) silently DROP the new field, + an exact-map
  `toRpcParams()` assertion breaks the moment the new `p_*` key is added (count 1, `5cfc2b3`, task
  notes).** Common shape: when a slice ADDS/REMOVES/REVERSES a model surface X, the plan's Tests/
  Docs section enumerates only the obvious sites and misses siblings that reference X. The cluster
  is now broad (4 mechanisms across 3 test-surface commits `d241131`-era/`f39649f`/`5cfc2b3`), but
  each concrete mechanism except the doc-reversal one is STILL count 1 — the candidate (d) is a
  first sighting, so NO rule this cycle (per the 2×-distinct-mechanism threshold; all four were
  also CAUGHT by plan-critic at plan time and folded in — no leak reached main, the gate is
  working). Sharpened trip-wire: if ANY test-surface mechanism (b/c/d) recurs in a future commit →
  promote by BROADENING the existing `CLAUDE.md` rule-reversal-sync line from "grep docs on a rule
  reversal" to "grep the whole sibling surface — docs AND `test/` (reconstructing fakes + exact-map
  assertions) — whenever a slice changes a model's field/method/affordance set (add OR remove)",
  rather than adding a second overlapping convention. NOT gated by hooks/lint/CodeRabbit (a plan
  omission + a broken sibling test only surface at `flutter test`, which the fleet runs pre-push).
- **A CREATE OR REPLACE that recreates an RPC to add ONE param must re-carry the WHOLE prior body**
  (SECURITY DEFINER, `SET search_path=public`, `where deleted_at is null` guard, `if not found
  raise`, `trim(p_title)`) — a terse "also set notes=…" risks silently dropping guards. Surfaced
  once as a plan-critic ISSUE at task notes (`5cfc2b3`), folded in pre-build. Single sighting → log
  & watch (plan-critic owns the row). This rhymes with the RPC-write template being a proven shape
  where per-entity attention belongs on the DELTA — here the delta must not amputate the template.
  Promote only if a future RPC-param-add recreates a body that drops a prior guard.
- **The `state-lift-vs-widget.x` trap surfaced (impl-critic count 1, `cfbfe7f`) and was RESOLVED
  in-slice.** A thin host whose dynamic AppBar title claims (in a comment) to track the LIVE entity
  but reads `widget.task` (frozen at push) while the mutation lives in the child body via
  `onChanged` — an in-place archive/restore flips the body but leaves the title stale. Fixed by
  seeding `late _task = widget.task` + `setState` in `onChanged`; semantic-reviewer confirmed the
  host now can't go stale. Single sighting → log & watch (impl-critic owns the WATCHING row). Const-
  title hosts (ContactDetailScreen = `'Contact'`) are immune, so it only bites when a host gains a
  state-dependent title. Promote only if a future dynamic-title host re-derives the frozen-`widget.x`
  read.
- **Decision 26 (RPC for all writes) is COMPLETE — 4/4 slices came back clean, including the
  divergent one (positive signal, RESOLVED).** events→contacts→event_types→event_comments
  (`2370fcf`, `20970ea`, `3296258`, + earlier) all cleared the whole fan-out (impl-critic APPROVED,
  code/semantic CLEAN, test GREEN). The RPC-write boilerplate (drop+recreate RPC, `SET search_path`,
  revoke-from-public, model `toRpcParams`, repo `.rpc()`+re-select) is a **proven low-risk shape** —
  spend attention on per-entity deltas, not the template. The divergence prediction was correct and
  benign: event_comments' `using(true)` open SELECT means a direct write never hit the 42501
  RETURNING re-check, so the RPC is for UNIFORMITY not necessity, and semantic-reviewer noted the
  RPC-then-refetch is *strictly safer* there (row can't vanish mid-op). Lesson for the NEXT
  cross-entity migration: a well-templated port stays clean even when one entity diverges, provided
  the divergence is documented in the migration header (it was, so no reviewer mis-flagged the
  missing 42501 guard).
- **The `toRpcParams()`↔RPC-arity seam is the recurring failure mode of the RPC-write shape** (count
  2: `update_comment` body-only `1e7574d`, `create_task` arity `258cb6c`). The template is proven
  safe (above), so per-entity attention belongs on ONE seam: does the model's `toRpcParams()` spread
  send EXACTLY the params the target RPC declares? A body-only `update_*` or an arity mismatch → a
  blind `{...toRpcParams()}` sends an extra/missing param → PostgREST **PGRST202** (fn-not-found for
  that arg set). Fix per-entity: build the param map explicitly (`{p_id, p_body}`) when it diverges
  from the create-shape, don't blind-spread. Caught at PLAN time both times (plan-critic), never hit
  runtime — semantic-reviewer's seed watch ("toRpcParams passes the params the RPC expects") already
  half-covers it; a `database.md` #2 line makes it a written convention so it isn't re-derived slice
  by slice. NOT gated by any hook/lint (PGRST202 is a runtime PostgREST error, invisible to analyze).
- **Read-only form must gate ALL write affordances on the same flag, not just one** (count 1, tasks
  `258cb6c`; semantic RESOLVED-WATCH). Archived `TaskFormScreen` hid the complete-toggle but left the
  title field editable + both Save affordances live → Save → `update_task` `deleted_at is null` guard
  → misleading "Couldn't save". Fixed by gating title `readOnly` + both Saves on `_isArchived`. SINGLE
  sighting → log & watch (no rule); already in semantic-reviewer's tracker. Promote only if a future
  edit/detail form gates one affordance but not its siblings again.

Watch-items carried from project conventions:
- Promotion threshold is **2× across different commits**. First sighting = log & watch, not a rule.
- Targets for a proposed change: `CLAUDE.md`, `docs/decisions.md` (append-only), `docs/database.md`,
  `docs/design-principles.md`, `.coderabbit.yaml` `path_instructions`, `analysis_options.yaml`.
- Don't propose anything already gated by `.githooks/` (format/analyze/commit-msg/secret-scan) or an
  existing `.coderabbit.yaml` instruction — no double-gating.

## Known false-positive traps (don't promote these into rules)
- Missing `auth.uid()` / owner-scoping is **expected pre-auth** (issue #3), not a defect. red-team's
  phase-flip watch (auth.uid() owner checks must move INSIDE `create_contact`/`update_contact` when
  #3 lands, because SECURITY DEFINER bypasses RLS) is a legitimate forward-watch, NOT a present
  defect — do not promote it while auth is unwired.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a breaking change.
- The `.coderabbit.yaml` SQL `path_instructions` telling the bot SECURITY DEFINER must "check
  auth.uid()" is itself phase-unaware — if reviewers keep tripping on it (2×), the action is to
  propose **softening** it, not enforcing it.
