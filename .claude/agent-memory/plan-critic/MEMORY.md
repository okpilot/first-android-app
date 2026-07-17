# plan-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring plan failure
> modes for THIS project so future reviews focus where plans actually go wrong. Detail lives in
> `topics/` — read on demand. Curated at `/wrapup`.

## Recurring plan failure modes

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| **F1** `hhmm(int minutes)` reused to render a `DateTime`/timestamp (it takes minutes-from-midnight; `timestamptz` needs `.toLocal()`) | 2026-07-11 event-comments | 1 | 2026-07-11 | WATCHING — flag if a UI slice reuses `hhmm` on `created_at`/`updated_at` |
| **F2** New RPC's `SET search_path` diverges from database.md #6 + the 5 existing RPCs while claiming to "mirror create_event" | 2026-07-12 writes→RPC | 1 | 2026-07-12 | WATCHING — diff any proposed `SET search_path` against rule #6 |
| **F3** Rule-reversal / status-flip doc sweep under-scoped — plan says "document it" but the change *reverses* an emphatic rule, leaving stale twins across sibling docs, ledger subsections, migration headers | 2026-07-12 writes→RPC | 3 | 2026-07-15 d549d45 | **PROMOTED → CLAUDE.md** "How we work" (rule-reversal-sync) |
| **F4** Removing a model method: plan lists only NEW tests — misses tests *for* the removed method, now-orphaned private helpers (`unused_element`), dangling dartdoc `[X]` | 2026-07-12 contacts→RPC S1 | 1 | 2026-07-12 | WATCHING — grep `test/` + check dead helpers/dartdoc |
| **F5** Rename under-enumerates fakes — named a non-existent test file, missed 2 of 3 fakes, raw JSON keys, `main.dart` prod instantiation | 2026-07-14 CommentsSection | 1 | 2026-07-14 | WATCHING — grep every fake; verify named test files EXIST |
| **F6** Field-add sweep — reconstructing fakes silently drop the field; exact-map `toRpcParams()` assertions break; CREATE OR REPLACE must re-carry the whole prior body; inline `p_*` param comments rot | 2026-07-14 task notes | 3+ | 2026-07-15 3bf48ea | **PROMOTED → CLAUDE.md** "How we work" (field-add sweep clause) |
| **F7** "Reuse the shared fake" — but fakes are private per-file `_Fake*`, not importable | 2026-07-14 task↔contacts | 1 | 2026-07-14 | WATCHING — verify the fake is genuinely public (partly mitigated by `test/support/fakes.dart`, D42) |
| **F8** Removing/relocating a UI affordance under-enumerates test fallout — sibling tests use it as an incidental proxy; a removed affordance may be the *driver tap*, not an assertion, with a mode-dependent replacement label; **and the replacement target may be un-hit-testable at the default 800×600 viewport** (an AppBar action is always visible; a bottom-of-ListView submit button is not — cf. the `Size(800,1400)` pin at `test/task_form_screen_test.dart:94–101`). **Relocating a labelled `FilledButton('Edit')` → an `IconButton(edit_outlined, tooltip:'Edit')` breaks EVERY `find.widgetWithText(FilledButton,'Edit')` (8 hits, A2), and the naive replacement `find.text('Edit')` COLLIDES with `CommentsSection`'s own `_action('Edit')` TextButton — the correct finder is `find.byTooltip('Edit')`/`find.widgetWithIcon`**. **Gate-divergence:** the two relocation surfaces can guard differently — A2 routed the narrow AppBar through the guarded public `edit()` (no-ops when archived) but the wide in-pane strip called the UNGUARDED private `_edit()`, which would reopen the form on an archived read-only task (the body's `if (!_isArchived)` gate at `task_detail_screen.dart:225` is the invariant being dropped) | 2026-07-14 tasks view-first | **4** | 2026-07-17 slice A2 | **RULE CANDIDATE** — grep the WHOLE test file; classify ASSERTION vs DRIVER; read both `_isEditing`/`_isArchived` branches; **check the new target's viewport reachability + whether the test file pins a surface size; grep for a sibling widget that renders the SAME label before picking `find.text`; and diff the archived/`_busy` gate on EVERY relocated surface (private helper vs guarded public wrapper)** |
| **F9** `toRpcParams()` gains a key → the inert `id: existing?.id ?? ''` sentinel goes live → create breaks; `.draft`→factory breaks `const .draft()`; model unit tests assert the old invariant by literal | 2026-07-16 idempotent creates #9 | 1 | 2026-07-16 | WATCHING — grep EVERY create call site for `?? ''`; `grep -rn "\.id, ''" test/` over ALL of test/ |
| **F10** Fake-name → shared-class map is not 1:1 — the same `_FakeCommentsRepo` name is seeded in one file, inert in three | 2026-07-16 fakes consolidation #10 | 1 | 2026-07-16 | WATCHING — build an explicit per-file name→class map |
| **F11** Dedupe/extract moves the LAST use of a symbol out of a file → orphaned import → `unused_import` → analyze fails → **pre-commit hook blocks** | 2026-07-17 slice A1 | 1 | 2026-07-17 | WATCHING — `grep -c` the moved-from file for EVERY public symbol of the import |
| **F12** Theme-token collision — a new `*ThemeData` sets a container to a token an **inner atom already fills with** (chipTheme `backgroundColor: secondaryContainer` vs `InitialsAvatar`'s own `secondaryContainer` fill → the avatar disc goes invisible). The mono palette aliases `primaryContainer`/`secondaryContainer`/`tertiaryContainer` all onto ONE `chip` token, so scheme roles that *read* as distinct are the same colour | 2026-07-17 slice A1 #6 | 1 | 2026-07-17 | WATCHING — for any new component theme, grep the atoms it wraps (`avatar:`/`child:`) for the same scheme token; resolve through `theme.dart`'s `_build` aliases, never the role name. **Follow-on:** the *fix* (`ring: true`) does NOT re-size the atom — the chip tight-constrains it (see F13); an earlier note here guessed "+4px" and was wrong |
| **F14** New View constructor flag (`showPaneHeader`) added without stating it must be **optional with a default** — every existing instantiation (2 narrow wrappers + 3 test `*DetailScreen` sites) breaks if required; and the WIDE call sites (`contacts_list_screen.dart:158`, `tasks_list_screen.dart:276`) must each be updated to pass it `true` | 2026-07-17 slice A2 | 1 | 2026-07-17 | WATCHING — for any new constructor param, grep EVERY instantiation and confirm the plan defaults it |
| **F13** Plan reasons about a **framework** widget's layout from its API surface (param names, the child atom's own `radius`/padding) instead of its `performLayout` — e.g. D-h's "its 22px avatar sets a height floor ≈ 34–38px" when `chip.dart` tight-constrains the avatar TO the chip. The *conclusion* survived; the mechanism, the numbers, and the stated QA risk were all false | 2026-07-17 slice A1 v3 D-g/D-h | 1 | 2026-07-17 | WATCHING — when a plan asserts a *framework* widget's sizing, read `_Render*.performLayout` / `_computeSizes` in `~/flutter`, never the public params |

## Durable knowledge
- **Skip threshold:** don't run for a single-file change under ~10 lines.
- **Rounds:** consecutive-clean floor N=3 (N=4 if the plan touches `backend/migrations/**/*.sql`),
  reset on any APPLY finding (not on a validated skip), ceiling 6 → escalate with residuals.
- **Pre-auth is permanent, not pending.** No login is planned (single-user + tailnet-only,
  Decision 37); issue #3 is CLOSED. Never demand `auth.uid()` — it is not a plan defect.
- **`drop function if exists …; create or replace …`** to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a breaking change. Judge from the LATEST definition across
  `backend/migrations/**/*.sql` sorted by timestamp prefix — never a single migration in isolation.
- **`util/calendar.dart` has zero imports** (no Flutter) — it's the safe dependency for `format.dart`,
  which models import. Anything dragging Flutter into `format.dart` would poison the models.
- **Shared reconstructing fakes live in `test/support/fakes.dart`** (Decision 42) — but single-file
  private specials still exist; grep both.
- **M3 chip facts (verified against `~/flutter`):** an unselected+enabled `InputChip` has **no fill**
  (`_InputChipDefaultsM3.color` returns null) and an `outlineVariant` hairline `side` — so a themed
  `backgroundColor` is a *new* fill, not a recolour. `ChipThemeData.side: BorderSide.none` IS honoured
  and IS required (`chip.dart` `_getShape` re-applies the defaults' side only when side is null).
  `deleteIconColor: onSurfaceVariant` + `showCheckmark: false` are **no-ops** on these chips (already
  the default; the chips are never `selected`). **The `avatar` is NOT unconstrained** (an earlier
  note here claimed it was — wrong): with `avatarBoxConstraints` null, `_layoutAvatar` gives it
  `BoxConstraints.tightFor(contentSize, contentSize)` (`chip.dart:1884`), where `contentSize =
  max(_kChipHeight(32) - padding.vertical + labelPadding.vertical, labelHeight +
  labelPadding.vertical)` (`:1953`). So an avatar **never** sets a chip's height — the chip sizes
  the avatar, and `radius:` on an `InitialsAvatar` passed as a chip `avatar:` is inert. Chip height
  = `padding.vertical + contentSize` + `VisualDensity` adj, **floored at 32** (compact → ~28);
  lowering `padding.vertical` does NOT shrink a chip, it inflates the avatar and the ✕.
- **`docs/decisions.md` hits are historical and append-only** (CLAUDE.md NEVER DO) — never list them
  in a plan's docs sweep. Only `README.md`, `docs/plan.md`, and `lib/**` doc-comments are sweepable.

## Topics
- [Failure modes — full detail](topics/failure-modes.md) — F1–F11 with evidence, variants, and the exact rule each promoted to.
- [Positive signals](topics/positive-signals.md) — plans that were accurate, and what specifically they got right (keeps reviews from re-litigating settled ground).
