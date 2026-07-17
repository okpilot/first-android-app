---
date: 2026-07-08
status: active (operative wrapper — the two encyclopedias are its on-demand references)
project: First Android App (learning CRM)
---

# How we apply the UI/UX principles

> This is the **light, load-first** design doc. It says *how* we use the two big
> reference docs without dragging their ~12k tokens of prose into every session.
> The encyclopedias themselves —
> [`UI-Principles-Encyclopedia-and-Checklist.md`](UI-Principles-Encyclopedia-and-Checklist.md)
> and [`UX-Principles-Encyclopedia-and-Checklist.md`](UX-Principles-Encyclopedia-and-Checklist.md)
> — are source-verified references to reach for **when a slice actually touches UI**, not
> constant reading. Their *Build Checklists* (UI Part 10, UX Part 8) are the working tool.

## Stance (what changed after the critics: we under-adopt on purpose)
1. **References, not a gate.** The push gate stays exactly what Decision 7 defined —
   `analyze` + `test` + `build` + `/crlocal` + explicit push approval + CodeRabbit. Checklist review is **advisory guidance at
   UI slices**, never a blocker. It informs the slice; it doesn't fail it.
2. **Proportional application.** Don't run ~60 checklist items against every diff. When a
   slice touches UI, name the *relevant* checklist groups (see the map below), review those,
   mark the rest N/A with a one-line reason. A backend-only or docs-only slice reviews none.
3. **Numbers have two tiers.**
   - **Load-bearing defaults we honor** (WCAG 2.2 AA): text contrast **4.5:1** / large **3:1**,
     non-text/icon/focus **3:1**, target size **≥24×24** (prefer 44–48 for touch), visible
     focus, keyboard operable, don't-rely-on-color-alone, labels-not-placeholders.
   - **Advisory rules of thumb** (tune by feel): 60-30-10, 66ch measure, type-scale ratios,
     8-pt grid, motion timings, the squint test.
   - Both docs are a **July-2026 snapshot** and *say so* — re-verify WCAG/Material against the
     live spec when a slice's correctness actually depends on a number.

## Slice-type → which checklist groups to pull

| Slice touches… | UI groups (Part 10) | UX groups (Part 8) |
|---|---|---|
| A list / table view | hierarchy, layout, components, icons | hierarchy&gestalt, nav&IA, perf, a11y |
| A form (add/edit) | typography, components, color | forms&input, errors, feedback, a11y |
| Navigation / shell | components, system&consistency | nav&IA, consistency, a11y |
| Empty / loading / error states | components, motion | feedback, content, a11y |
| Theming / tokens | color, system&consistency | (a11y contrast only) |

## Web cue → Flutter translation (the docs are stack-agnostic; we're Flutter)

| Doc's build cue | Flutter equivalent |
|---|---|
| `max-width: 66ch` measure | `ConstrainedBox(maxWidth: ~640)` on long text; usually N/A for lists/forms |
| 8-pt grid spacing | `SizedBox`/`Padding` in multiples of 8 (4 for tight); a spacing-tokens file later |
| tabular numbers | `Text(..., style: TextStyle(fontFeatures: [FontFeature.tabularFigures()]))` |
| design tokens / no one-off hex | `Theme.of(context)` + a `ThemeExtension`; never hardcode colors in widgets |
| every-state set (hover/focus/…) | `WidgetStateProperty` + `FocusableActionDetector`/`MouseRegion` |
| visible focus ring | Material focus overlay; keyboard nav via `Shortcuts`/`Actions`/`FocusTraversal` |
| `prefers-reduced-motion` | `MediaQuery.of(context).disableAnimations` (⚠ may not be wired on Linux — default motion conservative) |
| labels not placeholders | `TextField(decoration: InputDecoration(labelText: …))` — persistent label |
| alt text / semantic markup | `Semantics(label: …)`, semantic widgets, `excludeSemantics` for decorative |
| `object-fit: cover` | `Image(fit: BoxFit.cover)` |
| lazy-load below the fold | `ListView.builder` (builds only visible); `cacheWidth`/`ResizeImage` for photos |
| animate `transform`/`opacity` only | N/A — Flutter has no CSS reflow model; use implicit animations (`AnimatedFoo`) |

**N/A for Flutter** (skip, don't chase): OKLCH ramps, `srcset`, `clamp()`/container queries,
`cubic-bezier` literals (use `Curves.*`), CSS specificity.

## Where the docs conflict with Material 3 — follow the project theme (Decision 13)
The shipped baseline is the **bespoke flat/monochrome theme in `lib/theme.dart`** (Decision 13),
which *supersedes* the "stock M3 for now" of Decision 8. Reconcile against that:
- **Dark mode ≠ `#121212`.** That's Material **2**. Our theme uses `ColorScheme` surface roles
  (and `surfaceTint: transparent` for a flat look) — not the doc's fixed dark-gray + shadow.
- **Body ≠ hard 16px.** Our type scale sets body values at 16 and secondary/labels at 14 — use
  the roles in `theme.dart`, don't force 16 everywhere.
- Elevation is **flat/tonal**, not shadow-stacked (`useMaterial3: true` + transparent surfaceTint).

## Multi-platform is a standing constraint (Android + web + Linux desktop)
Per Decisions 1 & 5, one Flutter codebase ships to all three. So at the **first list/detail
slice**, design responsive + adaptive with real teeth:
- **Material window-size classes**: compact `<600` · medium `600–840` · expanded `840–1200`
  · large `>1200`. (Use these, not the UI doc's 640/768/1024 web breakpoints.)
- **Adaptive nav**: `NavigationBar` (compact) → `NavigationRail` (medium/expanded) →
  `NavigationDrawer` (large). List+detail = single-pane push on compact, **two-pane** on expanded.
- **Honor `MediaQuery.textScaler`** — never hardcode font sizes past scaling.
- **No unbounded `Text` in a header / nav `Row`.** Wrap it in `Flexible` + `TextOverflow.ellipsis`;
  a fixed-size brand glyph opts out via `TextScaler.noScaling`. A `RenderFlex` overflow is a *runtime*
  layout error — `flutter analyze` never catches it, only tests / visual QA do. (Decision 28;
  learner-promoted after the sidebar wordmark guards and a real 8.4px overflow in the Contacts header.)
- **Desktop affordances are first-class**: hover (`MouseRegion`), keyboard shortcuts
  (`Shortcuts`/`Actions`), visible focus, a sensible **Linux minimum window size**.
- **Testing a breakpoint-driven layout**: drive width via `tester.binding.setSurfaceSize(...)`
  (or `view.physicalSize` **with** `view.devicePixelRatio` pinned — `LayoutBuilder` sees
  logical px = physical/DPR), and always `addTearDown` a reset (`setSurfaceSize(null)`) so the
  fake surface size doesn't leak into sibling tests. The default test viewport is already
  **800×600 logical** (≥600 → wide branch), so it's the *narrow* case that needs the override.
  (Decision 28; learner-promoted after `home_shell_test` + `contacts_master_detail_test`.)
- **Material-everywhere carve-out.** The UI doc says "honor native platform conventions
  (iOS HIG vs Material)." We resolve that by standardizing on **Material across Android +
  web + Linux** — one design language (Decisions 8 & 13), not GTK/Cupertino per platform. Revisit
  only if/when we add iOS.

## Read-only / archived entities: gate EVERY write affordance
When a form or section renders read-only (an archived task, a frozen log), gate **all** write
affordances on the same read-only flag — including **state-dependent** ones that aren't always on
screen: an open inline editor, a submit-on-enter (`onFieldSubmitted`), a per-row Edit/Save that
renders only while `_editingId != null`. An affordance whose visibility keys off its *own* local
state (not the read-only flag) stays live after the entity flips read-only — e.g. a comment editor
left open when its task is archived keeps a working **Save**, and the DB write *succeeds* because the
RPC guard checks the still-live comment, not the archived task. Belt-and-braces: (a) render-gate the
editor `(editing && !readOnly)`, and (b) clear the transient edit-state on the read-only flip
(`didUpdateWidget`) so it can't reappear on a later restore. Invisible to `flutter analyze` — a
reachable runtime write path, caught only by review + a regression test. (learner-promoted, count 2:
archived `TaskFormScreen` title+Save `58b2b5d`; `CommentsSection` inline-edit branch `adab034`.)

## Visual QA asserts against the SPECIFIED value, on ADVERSARIAL data (Decision 47)
A screenshot that "looks fine" is not a passing QA — it's confirmation bias if there's no number to
check it against. Two disciplines, both learner-promoted after a chip regression shipped green:
- **Assert against the plan's specified values.** When the plan says a disc is 20px and its initials
  7.7px, QA measures them — not "does this look reasonable". A build rendering 32px discs with 14px
  initials *looks* like an avatar; it's still the wrong build. If a number was specified, verify it
  (a `getSize` probe, or read the pixels), don't eyeball it.
- **Exercise adversarial data, not the convenient sample.** The live data's initials were narrow
  ("AT", "DR") and hid an overflow that the widest pair ("WW", "MM") exposes. Always QA the extremes
  the layout has to survive — the longest label, the widest glyphs, the empty state, the many-items
  case — not whatever happens to be on screen. The narrow sample is where overflow hides.
  *(This is the visual twin of the reviewer rule "read + probe, never reason" in
  `.claude/rules/agent-workflow.md` — both replace "it looks right" with a measured value.)*

## Not now (YAGNI)
- A dedicated `/designreview` command — earn it once there are several real screens to review.
- A full token system / `ThemeExtension` — build it at the theming slice, not before.
