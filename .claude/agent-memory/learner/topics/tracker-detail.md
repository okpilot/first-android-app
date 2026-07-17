# learner — tracker row detail

> Long-form write-ups for the rows in `MEMORY.md`'s Issue Frequency Tracker. The tracker keeps the
> row + count + status; the reasoning lives here. Edit in place — never a dated log (history: `git log -p`).

## Docs-sync: rule-reversal / status-flip sweep (the fleet's #1 recurring miss)

**Two rows, one family.** (1) The base row — a rule reversal mid-multi-slice migration leaves a
contradictory sibling doc-comment/migration-header citing the OLD rule (count 3, PROMOTED →
`CLAUDE.md` "How we work" + plan-critic greps at plan time). (2) The refinement — the sweep misses
SECONDARY stale surfaces *within an already-touched file*: summary/conventions blocks and
decision-entry SUBSECTIONS, not the obvious first citation.

**Refinement history.** First `3296258`. Recurred `d549d45` (plan sweep missed D33 decisions.md
L390-391 + plan.md L41/L67-68; proposed skipping migration headers that Slices 2/3 had already
fixed in-slice; plan-critic caught it, REVISE) → count 2 → folded ONE clause into the binding
CLAUDE.md rule: "grep the WHOLE of each touched file + every decisions-ledger subsection, not just
the first citation". Deliberately NOT a `/fullpush` grep gate — the miss is semantic and
un-greppable per-slice, so a gate would double-gate plan-critic + doc-updater.

**Recurred `d429a80` (#19/D45) → count 3, THROUGH the promoted rule.** The rule under-fired on two
axes, both verified against source:
- **(a) Trigger too narrow.** Headline reads "When a slice rewrites or reverses a convention
  mid-migration". `d429a80` reversed no convention — it was a **status flip** (`/updatephone`
  owed → done). A doc author doesn't read the rule as applying to a status word.
- **(b) Subsection list reads CLOSED and omits the one that rots.** "(Context / Implementation /
  Principle)" — but `grep -oE '^\*\*[A-Za-z /-]+:?\*\*' docs/decisions.md` shows the ledger's real
  subsection vocabulary is wider (Context 45, Principle 43, Decided 39, Verification 2, Test
  coverage 2, Refines 2, **Deploy note 2**, …). Both `**Deploy note:**` instances (D40:487,
  D41:499) are EXACTLY where the twins rotted. The enumeration named neither `Decided:` nor
  `Deploy note:`.

**Evidence it's the dominant cost.** impl-critic r1 (2 ISSUE) and r2 (1 ISSUE) — *every* blocking
finding across both rounds was a stale doc twin; the curls/SQL/decision were clean from r1. Gate
HELD (caught pre-commit; nothing stale reached main) but cost 2 rounds on a docs-only slice.

**Disposition:** learner-PROPOSED → widen the SAME promoted rule (headline "rule reversal **or
status flip**"; open the subsection list, naming Deploy note). NOT a new rule (DO-NOT #4), NOT a
deletion (DO-NOT #3) — an under-firing trigger on an existing rule. impl-critic's row is the
originating RULE CANDIDATE (its count 3 = owed-list twin #40 → back-reference/plan+HANDOVER twin →
ledger deploy-note twin).

## Field-add → hand-fake completeness (count 5, PROMOTED, HELD)

Adding a scalar field to a model silently DROPS it in hand-fakes that RECONSTRUCT the entity
(`create`/`archive`/`restore` rebuild `Task(...)` from scratch, not pass-through) AND breaks
exact-map `toRpcParams()` assertions. Invisible to analyze/lint/hooks/CR — test-fake completeness is
opaque to all four. First: `notes` (task Slice 1). PROMOTED → CLAUDE.md "How we work" ("Adding a
field to a model isn't done until every hand-fake reflects it", written 3bf48ea follow-up).

Recurred notes → contacts → `importance` → `categories` → `p_id` = 5 distinct commits; **HELD** each
time — the rule's "update every exact-map `toRpcParams()` assertion" clause is exactly what fires,
and test-writer caught it in-cycle. At D41/#9 all 6 models' `toRpcParams` gained `p_id`; 5 test files
updated their assertion, Event's `event_test.dart` shipped MISSING (not even staged) → test-writer
backfilled.

**WRINKLE (count 1, WATCH):** the D41 recurrence was an **exposure-only** add — the model FIELD
(`id`) already existed, only its `toRpcParams` EXPOSURE changed — so the headline trigger ("adds a
*field* to a model") could be read too narrowly to fire. No rule change (broad mechanism already
covered; wrinkle at count 1). If a 2nd exposure-only / `toRpcParams`-key-only add slips a sibling
assertion → propose broadening the headline: "adds a field to a model **or a key to its
`toRpcParams` map**".

**MITIGATED `a08c199` (D42, #10):** reusable reconstructing fakes consolidated into ONE shared
`test/support/fakes.dart` (9 public fakes) — thread a new field through that file once, then grep
`test/` only for single-file specials that still reconstruct locally. Shrinks the blast radius;
does NOT retire the rule (locals + exact-map assertions are still per-file).

## Duplication rows (design-debt, NOT workflow rules)

- **Byte-faithful per-parent duplication** (count 2): repo `Supabase{Task,Event}CommentsRepository`
  ~70 lines (`adab034`, still N=2 → WATCHING); chip-section/roster WIDGET shape
  `_PeopleSection`≈`_AttendeesSection` (`2b100b7`) + `_CategoriesSection`≈`_PeopleSection` &
  `_CategoriesList`≈`_PeopleList` (`d95f85b`). RULE CANDIDATE **for the widget shape only** — now
  N=3 (People, Attendees, Categories) where extraction economics flip (MetaLine precedent: N=2
  zero-variance → extracted; here N=3 with parameterizable variance: label, `avatarBuilder`, button
  copy). Surface to the user as design-debt — extract a parameterised `ChipSection` + roster-row
  atom to `lib/widgets/`, record disposition in `decisions.md`. Mirrors are correct + documented →
  no recurring MISTAKE → not a CLAUDE.md rule.
- **Entity-agnostic byte-identical atom COPIED because it's PRIVATE** (count 1, `9377a61`):
  `_SwatchGrid` byte-identical across `event_types_screen.dart` ↔ `task_categories_screen.dart`.
  Contrast the SAME slice's `TypeSwatch` (public → REUSED via `show TypeSwatch`) — the atom is
  shareable; privacy is the only thing forcing the copy. DISTINCT from per-parent dup (that varies
  by entity; this is zero-variation). Next such copy → count 2 → RULE CANDIDATE ("an entity-agnostic
  atom used by ≥2 sibling screens goes public/`lib/widgets/`, never `_`-copied").

## doc-updater lifecycle over-claim (count 2, PROMOTED → RESOLVED)

Wrote "merged"/"on main"/"deployed"/"issue #N CLOSED" when the slice was only COMMITTED ON A BRANCH.
Prose the fleet's own agent authored; cloud CR kept catching it, burning SCARCE CR credits. First:
D39 Slice A (`df7afa7`); recurred `780c930` (D43).

**PROMOTED → 3 surfaces (`c83cecb`, Decision 44):** (1) `.claude/agents/doc-updater.md` —
*Lifecycle-state discipline* table + DO-NOT #10: derive each lifecycle word from real git/gh
(`git ls-remote`, `gh pr view --json state`), default "committed on branch; push/PR pending";
(2) `.coderabbit.yaml` `path_filters` exclude `**/*.md` + `.claude/**` so cloud CR no longer reviews
the prose where it surfaced — the fleet owns docs; (3) `docs/decisions.md` D44 records the split.

**Self-application VERIFIED `d429a80`** — first session after the def reload: doc-updater reported
SYNCED / 0 findings and applied the conservative lifecycle wording **unprompted** (no orchestrator
assist, unlike `c83cecb`'s session). The rule text lands. → RESOLVED. Residual half still WATCHING:
the `path_filters` globs have no local validator, so the first post-merge PR touching a root `.md`
should be spot-checked to confirm it draws no cloud-CR review.
