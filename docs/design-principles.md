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
- **Desktop affordances are first-class**: hover (`MouseRegion`), keyboard shortcuts
  (`Shortcuts`/`Actions`), visible focus, a sensible **Linux minimum window size**.
- **Material-everywhere carve-out.** The UI doc says "honor native platform conventions
  (iOS HIG vs Material)." We resolve that by standardizing on **Material across Android +
  web + Linux** — one design language (Decisions 8 & 13), not GTK/Cupertino per platform. Revisit
  only if/when we add iOS.

## Not now (YAGNI)
- A dedicated `/designreview` command — earn it once there are several real screens to review.
- A full token system / `ThemeExtension` — build it at the theming slice, not before.
