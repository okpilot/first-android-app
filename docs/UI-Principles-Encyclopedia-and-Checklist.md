# The UI Principles Encyclopedia & Build Checklist

*A source-verified reference for research, and an actionable checklist for AI-assisted coding.*

Version 1.0 · Compiled July 2026 · Universal (not stack-specific)

---

## Part 0 — How to use this document

This is the **UI companion** to the UX Principles Encyclopedia. Same format, same two jobs:

1. **For you (research reference).** Parts 1–9 are the encyclopedia: every major UI principle, the numbers that matter, and what separates a polished interface from an amateur one.
2. **For a machine (build checklist).** Part 10 is a consolidated, imperative checklist you can drop into a `CLAUDE.md` or paste as a review prompt. Every line is checkable against a screen.

**UX vs UI — the split.** UX is *how it works* (psychology, usability, flow — the other document). UI is *how it looks and behaves to the eye and hand* — typography, color, spacing, hierarchy, components, motion. They share a fence line: **Gestalt grouping, color contrast, and component states** live in both. This document is written to stand alone, so it restates those shared bits briefly and points you to the UX doc (`UX-Principles-Encyclopedia-and-Checklist.md`) for the deeper treatment. *Aviation frame: UX is whether the aircraft is airworthy and flies the mission; UI is the cockpit ergonomics — where the switches sit, how they're labelled, whether you can read the panel at night.*

**A note on trust.** Every number here (line lengths, contrast ratios, grid units, motion timings, type-scale ratios) was verified against primary or authoritative sources at compile time (see Sources, Part 12). UI numbers are *conventions*, not physical constants — they're strong defaults, not laws. Where a figure is a rule-of-thumb rather than a hard rule, it's flagged.

**Legend:** **What** (one line) · **Why** (why it matters) · **Build cue** (the concrete thing to do).

---

## Part 1 — Visual hierarchy (the master skill)

*If UI had one job, it'd be this: guide the eye to the right thing in the right order. Everything else serves hierarchy. A user should know where to look first, second, third — without thinking.*

**The five levers of hierarchy.** You create hierarchy by manipulating:
- **Size** — bigger = more important. The bluntest, strongest tool.
- **Weight** — bold pulls focus; regular recedes.
- **Color & contrast** — high contrast advances, low contrast retreats; a saturated accent among neutrals dominates.
- **Position** — top and left (in LTR reading) get seen first; center draws the eye as a focal point.
- **Whitespace** — space around an element isolates and elevates it (see also Gestalt proximity).

- **Contrast is the engine** — What: hierarchy is built from *difference*. Why: if everything is emphasized, nothing is. Build cue: make important things clearly different, not marginally different — timid hierarchy reads as no hierarchy.
- **One primary focal point per view** — What: each screen has a single most-important element. Why: competing focal points stall the eye. Build cue: one dominant action/headline; everything else is visibly subordinate (ties to Von Restorff — see UX doc).
- **The squint test** — What: squint at the screen until it blurs; the hierarchy should still be legible as light/dark blobs. Why: it reveals whether structure survives without detail. Build cue: use it as a 5-second self-audit on every layout.

---

## Part 2 — Typography

*Text is ~90% of most interfaces. Type is not decoration — it's the primary UI. Get this right and everything looks more professional instantly.*

### 2.1 The numbers that matter
- **Body size:** minimum **16px** for body text (especially on mobile — smaller causes zoom on iOS and strains everyone). Go up from there, rarely below for reading text.
- **Line length (the "measure"):** **45–75 characters per line, 66 is the classic ideal** (Bringhurst, *The Elements of Typographic Style*). Too long and the eye loses its place returning to the next line; too short and rhythm breaks. WCAG 1.4.8 (AAA) caps it at 80. Build cue: `max-width: 66ch` on the *text wrapper*, not the layout container.
- **Line height (leading):** body text ~**1.5** (range 1.4–1.7); headings tighter at **1.1–1.3**; the larger the type, the tighter the leading. Build cue: on a baseline grid, keep line-height a multiple of 4 or 8 so text lands on the grid.
- **Type scale (modular scale):** pick one ratio and generate all sizes from a base (usually 16px) — don't hand-pick arbitrary sizes. Common ratios: **1.125** (Major Second — dense dashboards), **1.2** (Minor Third), **1.25** (Major Third — Material's choice), **1.333** (Perfect Fourth — the most popular for web/app), **1.5** (Perfect Fifth — dramatic), **1.618** (Golden Ratio). Build cue: fewer, well-separated sizes beat many similar ones.

### 2.2 Craft rules
- **Limit typefaces** — What: two families max (often one, in different weights). Why: more looks chaotic. Build cue: pair a display/heading face with a readable body face, or just use one good variable font.
- **Use weight and size for hierarchy, not just size** — Why: weight adds a hierarchy dimension without eating space. Build cue: a bold 16px label can outrank a regular 18px one.
- **Letter-spacing (tracking)** — What: tighten large headings slightly; open up all-caps and small labels. Why: default tracking is tuned for body size, not extremes. Build cue: all-caps text almost always needs positive letter-spacing.
- **Legibility ≠ readability** — legibility is recognizing individual characters; readability is processing whole blocks comfortably. Build cue: a legible font can still be unreadable at bad size/leading/measure.
- **Alignment** — left-align body text (in LTR); avoid justified text on the web (it creates ugly "rivers" of whitespace without proper hyphenation); never center more than a couple of lines. Build cue: ragged-right is the safe default for paragraphs.
- **Contrast** — body text must hit WCAG **4.5:1** (see Part 3 / UX doc). Avoid pure-gray-on-white that looks elegant in Figma and vanishes in sunlight.

---

## Part 3 — Color

*Color carries meaning, emotion, and hierarchy — and it's where amateur UIs betray themselves fastest (too many colors, wrong saturation, unreadable contrast).*

### 3.1 Structure & proportion
- **The 60-30-10 rule** — What: a balanced palette is roughly **60% dominant/neutral, 30% secondary, 10% accent**. Why: proportion creates calm and directs attention (the 10% accent is where you put calls-to-action). Build cue: most of the screen should be neutral; color is a spice, not the meal. *(Rule of thumb, borrowed from interior design — not a law.)*
- **Build a systematic scale, not single colors** — What: each hue needs a ramp of tints/shades (e.g. 50→900, like Material/Tailwind). Why: you need consistent options for backgrounds, borders, hover states, text. Build cue: define the scale once as tokens (Part 8); never hand-pick one-off hex values in components.
- **Neutrals do the heavy lifting** — a well-designed set of grays (warm or cool, not pure) carries most of the UI. Build cue: invest in a good neutral ramp before chasing brand colors.

### 3.2 Meaning & accessibility
- **Semantic colors** — reserve conventional meanings: red/error, green/success, amber/warning, blue/info. Why: users read these pre-attentively. Build cue: don't use your brand red if red means "error" elsewhere in the app.
- **Never rely on color alone** — What: pair color with an icon, label, or shape. Why: ~1 in 12 men have color-vision deficiency; color-only meaning excludes them (and fails WCAG). Build cue: error states get an icon *and* text, not just a red border.
- **Contrast (verify exactly):** normal text **4.5:1**, large text **3:1**, UI components/icons **3:1** (WCAG AA — full detail in the UX doc, Part 4). This is the single most-failed UI requirement.

### 3.3 Modern color & dark mode
- **Perceptual color spaces (OKLCH/HSL caveat)** — What: HSL is convenient but *not* perceptually uniform — equal number changes don't look equally different, so HSL ramps have uneven lightness. **OKLCH** (now supported in CSS) is perceptually uniform and produces smoother, more predictable scales. Build cue: for new systems, build color ramps in OKLCH.
- **Dark mode is not "invert everything"** — What: use very dark gray, not pure black (Material suggests ~#121212); desaturate colors (vivid colors vibrate on dark backgrounds); signal elevation with *lighter* surfaces rather than heavier shadows. Why: pure black + saturated color causes eye strain and halation. Build cue: design dark mode as its own palette, mapped through semantic tokens — not an afterthought filter.
- **Color is cultural** — associations (e.g. what red or white signify) differ across cultures. Build cue: don't hard-code emotional assumptions for a global audience.

---

## Part 4 — Layout, grid & spacing

*Spacing is the most underrated skill in UI. It's what makes a design look "intentional" versus "assembled by guesswork." Consistent space is invisible; inconsistent space feels cheap and untrustworthy.*

### 4.1 The spatial system
- **The 8-point grid** — What: size and space everything in multiples of 8 (**8, 16, 24, 32, 40, 48, 56, 64…**), with a **4px half-step** for tight spots (icon-to-label, badge padding). Why: it removes hundreds of micro-decisions, scales cleanly across screen densities (Android's ×0.75/×1.5), and every major system runs on it — Material (8dp+4dp), IBM Carbon, Atlassian, Adobe Spectrum; Tailwind's default scale is multiples of 4. Build cue: stop debating 13 vs 15px — the answer is 16.
- **Internal ≤ external rule** — What: the space *inside* a group should be less than the space *around* it. Why: it's Gestalt proximity made concrete — tight internal spacing says "these belong together," bigger external spacing separates groups. Build cue: form label + input sit close (4–8px); the next field group starts after a bigger gap (24px+).
- **Column grid** — a 12-column layout grid with consistent gutters (24px is common) and margins organizes the horizontal rhythm; 12 divides cleanly into halves, thirds, quarters. Build cue: content aligns to columns; nothing floats arbitrarily.
- **Baseline / vertical rhythm** — keeping line-heights and spacing on a 4/8px baseline makes text and elements align vertically down the page. Build cue: line-height as a multiple of 4 keeps text on the grid.

### 4.2 Whitespace & reading patterns
- **Whitespace is active, not wasted** — What: emptiness groups, separates, and elevates. Why: cramped UIs raise cognitive load and look cheap; generous space reads as premium and confident. Build cue: when something feels "off," the fix is usually more space, not more stuff.
- **F-pattern** — for text-heavy pages, eyes scan in an F (across the top, down the left, shorter scans). Build cue: front-load headings and key info on the left.
- **Z-pattern** — for sparse pages (landing pages), eyes sweep in a Z. Build cue: place logo top-left, action top-right, and a diagonal to the primary CTA bottom-right.
- **Density** — offer comfortable spacing by default; a compact mode suits data-heavy power-user tools (tables, dashboards). Build cue: match density to the audience and task.

### 4.3 Responsive layout
- **Mobile-first & breakpoints** — design the smallest screen first, then add space/columns as it grows. Common breakpoints cluster around ~640 / 768 / 1024 / 1280px, but let *content*, not devices, dictate them. Build cue: use fluid techniques (`clamp()`, container queries, flexible grids) over fixed pixel jumps; test the real reflow, not just the design canvas.

---

## Part 5 — Components & their states

*Components are the vocabulary of your UI. The mark of a pro isn't the default state — it's having designed **every** state.*

### 5.1 The full state set (the thing amateurs forget)
Every interactive element needs its complete set of states, each visually distinct:
**default · hover · focus · active/pressed · disabled · loading · selected · error.**
- **Focus state is non-negotiable** — a visible focus ring is how keyboard and screen-reader users navigate (WCAG). Build cue: never remove the focus outline without replacing it with something equally visible.
- **Hover is desktop-only** — don't hide critical actions behind hover (they don't exist on touch). Build cue: hover enhances; it never gates.
- **Disabled must still be legible** and ideally explain *why* it's disabled. Build cue: don't make disabled controls so faint they fail contrast or look broken.
- **Touch targets** — interactive elements need a minimum hit area: **24×24 CSS px** (WCAG 2.2 AA), and preferably **44×44pt (Apple) / 48×48dp (Material)** for anything finger-driven, with spacing between targets to prevent mis-taps. Why: fingers are imprecise (~10mm pad). Build cue: a target can *look* small but must have a padded hit area that meets the minimum.

### 5.2 Common components
- **Buttons** — establish a clear action hierarchy: **primary** (filled, one per view), **secondary** (outline/tonal), **tertiary/ghost** (text only), **destructive** (red, with confirmation/undo). Why: users should instantly see the main action. Build cue: never show two competing primary buttons.
- **Forms** — top-aligned labels scan fastest and are most accessible; use inline validation with clear, specific error text; group related fields; show helper text before errors, not after failure. Build cue: labels are persistent — placeholders are not labels (they vanish and fail contrast). (See UX doc, Part 7, for the forms/error rules.)
- **Cards** — a container (Gestalt common region) grouping related content; keep internal padding consistent (8-point grid) and one card = one coherent unit.
- **Modals/dialogs** — use sparingly (they interrupt). Requirements: trap focus inside, close on Escape and overlay click, return focus on close, and never stack modals. Build cue: if it's not a decision that must block everything, use an inline panel or a toast instead.
- **Toasts/snackbars** — transient, non-blocking feedback; auto-dismiss for info, persistent for anything requiring action. Build cue: don't put critical decisions in something that disappears.
- **Tables** — left-align text, **right-align numbers**, use tabular (monospaced) figures so digits line up for scanning; design the empty and loading states. Build cue: dense data still needs breathing room in row height.

---

## Part 6 — Iconography, imagery & depth

- **Icon consistency** — What: use one icon family with a consistent stroke weight and grid size (16/20/24px on the 8-point grid). Why: mixed icon styles read as sloppy instantly. Build cue: don't mix filled and outline sets arbitrarily; align icons optically with adjacent text.
- **Icons need labels** — What: an icon alone is often ambiguous (the infamous mystery hamburger/kebab). Why: recognition beats guessing. Build cue: pair icons with text labels for anything non-universal; a bare magnifying glass is fine, a bare abstract glyph is not.
- **Imagery** — maintain consistent aspect ratios; use `object-fit: cover` rather than distorting; provide responsive sources (`srcset`) and lazy-load below the fold for performance; always give meaningful images alt text (UX/accessibility). Build cue: never stretch a photo to fit.
- **Corner radius** — pick a small, consistent radius scale (e.g. 4/8/12px) and apply it systematically. Why: inconsistent radii look accidental. Build cue: nested radii should relate (outer radius ≈ inner radius + padding).
- **Elevation & shadow** — use a consistent shadow scale to signal depth/layering (resting → raised → overlay). Why: ad-hoc shadows look muddy. Build cue: define 3–5 elevation levels as tokens; softer/larger shadows read as "higher."

---

## Part 7 — Motion & microinteractions

*Motion, done right, is invisible: it provides feedback, preserves spatial continuity, and guides attention. Done wrong, it's a laggy, nauseating distraction. Motion is functional, not decorative.*

### 7.1 The four honest jobs of motion
Feedback (this tap registered) · Orientation (where did this panel come from / go to) · Attention (draw the eye to a change) · Brand expression (personality — used sparingly). If an animation does none of these, cut it.

### 7.2 Timing (verified ranges — treat as defaults, tune by feel)
- **Microinteractions** (button press, toggle, hover): **100–200ms.**
- **Standard transitions** (dropdowns, small moves): **200–300ms.**
- **Larger transitions** (modals, page/section, full-screen expand): **300–500ms.**
- **Exits are faster than entrances** — dismissing needs less attention than the next task (Material: a drawer opens in 250ms, closes in 200ms).
- **The edges:** under ~**100ms** feels instant/unnoticed; over ~**400–500ms** starts to feel sluggish; **NN/G: delays over 1s break the sense of direct manipulation.**

### 7.3 Easing & performance
- **Never use linear easing for movement** — it looks robotic. Use **ease-out** for entrances (fast in, gentle stop), **ease-in** for exits, ease-in-out for moves; Material's standard curve is `cubic-bezier(0.4, 0, 0.2, 1)`. Why: real objects accelerate and decelerate. Build cue: linear is fine for opacity/color fades, not for position/scale.
- **Animate cheap properties** — only `transform` and `opacity` are GPU-friendly and hit 60fps; animating `width`/`height`/`top`/`left` triggers layout and drops frames. Build cue: move with `transform: translate()`, not positional properties.
- **Respect `prefers-reduced-motion`** — some users get motion sickness from animation; honor the OS setting by reducing or removing non-essential motion (accessibility requirement). Build cue: wrap non-essential animation in the media query.
- **Microinteractions** (Dan Saffer's model): trigger → rules → feedback → loops/modes. The small moments (a like button, a pull-to-refresh) are where products feel alive. Build cue: sweat the tiny feedback loops; that's where "delight" lives.

---

## Part 8 — Design systems & tokens

*The bridge between a principles document and consistent code. This is what makes everything above enforceable at scale — and it's the part that lets an AI coding assistant apply your rules automatically.*

- **Design tokens** — What: named variables for every design decision (`color-primary`, `space-4`, `radius-md`, `font-size-body`, `duration-fast`), stored as a single source of truth and consumed by both design and code. Why: change the token, change it everywhere; no magic numbers scattered through components. Popularized by Salesforce's Lightning Design System (~2014); now being standardized by the **W3C Design Tokens Community Group** (`$value`/`$type` format). Build cue: tier them — **primitive/global** (`blue-500`) → **semantic/alias** (`color-action` → `blue-500`) → **component** (`button-bg` → `color-action`). Components reference semantic tokens, never raw hex.
- **Atomic Design** — *Brad Frost, 2013.* What: build UIs from a hierarchy — **atoms** (button, input, label) → **molecules** (a search field = input + button) → **organisms** (a header) → **templates** (page skeleton) → **pages** (real content). Why: a shared mental model for composing and naming components. Build cue: build small, composable pieces; assemble upward.
- **Component library / single source of truth** — reusable, documented components mean consistency by default and no one-off buttons. Build cue: if a pattern appears 3+ times, it's a component.
- **Consistency (internal + external)** — internal: the same thing looks/behaves the same everywhere in your product. External: you match platform/web conventions users already know (Jakob's Law — UX doc). Build cue: novelty is a cost; spend it only where it adds real value.

---

## Part 9 — Foundational aesthetic frameworks & platform conventions

*The classic mental models worth having in your back pocket.*

- **C.R.A.P.** — *Robin Williams, "The Non-Designer's Design Book."* The four beginner-to-pro fundamentals: **Contrast** (make different things clearly different), **Repetition** (repeat visual elements for unity), **Alignment** (nothing placed arbitrarily; everything connects to something), **Proximity** (group related items). Build cue: 90% of "why does this look amateur?" traces to one of these four.
- **Dieter Rams' 10 Principles of Good Design** — the industrial-design north star ("Good design is as little design as possible"; good design is innovative, useful, aesthetic, understandable, unobtrusive, honest, long-lasting, thorough, environmentally friendly). Build cue: a philosophical checklist for restraint.
- **Gestalt principles** — proximity, similarity, common region, closure, continuity, figure/ground (the rules for how the eye groups things). Full treatment in the UX doc (Part 3); they're the theory *underneath* spacing, grouping, and cards.
- **Visual style / design language** — What: the overall aesthetic school you commit to — **flat** (no faux-3D, the current default), **skeuomorphic** (mimics real objects; largely dated but useful for onboarding metaphors), **neumorphism** (soft extruded shapes; trendy but notoriously bad for contrast/accessibility), **glassmorphism** (frosted translucent layers; use sparingly, watch contrast). Why: consistency of style is what makes a product feel like one product. Build cue: pick one language and apply it systematically; the trendy ones (neu/glass) fight accessibility, so verify contrast before committing.
- **Platform conventions — iOS HIG vs Material Design** — What: Apple's Human Interface Guidelines and Google's Material Design encode platform-native patterns (navigation placement, back behavior, system fonts SF Pro / Roboto, control styles). Why: users expect their platform's conventions; fighting them costs usability. Build cue: honor native patterns for structural/navigation behavior; express brand in content, color, and personality — not by reinventing the back button. On the web, lean on established conventions unless you have a strong reason (Jakob's Law).

---

## Part 10 — The Build Checklist (hand this to Claude Code)

*Imperative, verifiable rules distilled from Parts 1–9. Drop into a `CLAUDE.md` at your project root, or paste as a review prompt.*

> **Instructions for an AI reviewer:** Go screen by screen (or component by component). Mark each item ✅ pass, ❌ fail, or ⚠️ N/A. For every ❌, name the element, cite the rule, and propose a concrete fix. Rank by severity (blocker → major → minor → cosmetic). Do not mark ✅ without evidence.

### Visual hierarchy
- [ ] Each view has one clear primary focal point / primary action; secondary elements are visibly subordinate.
- [ ] Hierarchy survives the squint test (structure readable when blurred).
- [ ] Emphasis is created by clear differences in size/weight/color, not marginal ones.

### Typography
- [ ] Body text is ≥ 16px.
- [ ] Reading text lines are ~45–75 characters (`max-width: ~66ch` on text wrappers).
- [ ] Body line-height ≈ 1.5; headings 1.1–1.3; larger type has tighter leading.
- [ ] All font sizes come from one modular scale (no arbitrary one-off sizes).
- [ ] No more than two typefaces; hierarchy uses size *and* weight.
- [ ] Body text meets 4.5:1 contrast; paragraphs are left-aligned, not justified.

### Color
- [ ] Palette follows ~60-30-10 proportion; the accent is reserved for primary actions.
- [ ] Colors come from a defined token scale — no one-off hex values in components.
- [ ] Meaning is never conveyed by color alone (icon/label/shape accompanies it).
- [ ] Semantic colors (error/success/warning/info) are used consistently.
- [ ] Text contrast ≥ 4.5:1 (normal) / 3:1 (large); UI components/icons ≥ 3:1.
- [ ] Dark mode (if present) uses dark gray not pure black, desaturated colors, and its own token mapping.

### Layout & spacing
- [ ] All spacing and sizing use the 8-point grid (multiples of 8, 4px for tight internal gaps).
- [ ] Internal spacing of a group is less than the space around it (internal ≤ external).
- [ ] Elements align to a consistent grid; nothing is placed arbitrarily.
- [ ] Whitespace is sufficient — the layout doesn't feel cramped.
- [ ] Layout is responsive with fluid reflow; no cut-off content or horizontal scroll at standard breakpoints.

### Components & states
- [ ] Every interactive element has all states designed: default, hover, focus, active, disabled, loading, selected, error.
- [ ] A visible focus indicator is present on all interactive elements (never removed without replacement).
- [ ] Interactive targets have a hit area ≥ 24×24px (AA); touch-driven controls are ≥ 44–48px with spacing to prevent mis-taps.
- [ ] No critical action is hidden behind hover (touch has no hover).
- [ ] Exactly one primary button per view; destructive actions are distinct and guarded.
- [ ] Form labels are persistent (not placeholder-only) and top-aligned; validation is inline and specific.
- [ ] Modals trap focus, close on Escape/overlay, restore focus on close, and don't stack.
- [ ] Tables right-align numbers, use tabular figures, and have designed empty/loading states.

### Icons, imagery & depth
- [ ] Icons come from one family with consistent stroke weight and grid sizing.
- [ ] Non-universal icons have text labels.
- [ ] Images keep aspect ratio (no stretching), are responsive, lazy-loaded below the fold, and have alt text.
- [ ] Corner radius and shadow/elevation follow a consistent, tokenized scale.

### Motion
- [ ] Every animation has a job (feedback/orientation/attention/brand) — no decorative motion.
- [ ] Durations sit in range: microinteractions 100–200ms, standard 200–300ms, large 300–500ms; exits faster than entrances.
- [ ] Movement uses ease-out/ease-in (never linear); only `transform`/`opacity` are animated for performance.
- [ ] `prefers-reduced-motion` is respected.

### System & consistency
- [ ] Design values (color, space, type, radius, motion) are defined as tokens and referenced, not hard-coded.
- [ ] Repeated patterns (3+ uses) are shared components — no one-off variants.
- [ ] The same element looks and behaves consistently across the product.
- [ ] Platform/native conventions are honored for navigation and structural behavior.

---

## Part 11 — Research backlog (dig deeper later)

*The runway holding queue.*

- **Books:** Robin Williams, *The Non-Designer's Design Book* (CRAP, the fastest ROI) · Robert Bringhurst, *The Elements of Typographic Style* (the typography bible) · Ellen Lupton, *Thinking with Type* · Refactoring UI (Wathan & Schoger — intensely practical for developers) · Alan Cooper, *About Face* (interaction design).
- **Systems to study:** Google Material Design 3 · Apple Human Interface Guidelines · IBM Carbon · Atlassian Design System · Shopify Polaris · the W3C Design Tokens format.
- **Deep-dives:** OKLCH and perceptual color · fluid typography with `clamp()` · container queries · variable fonts · the full Dieter Rams 10 · Dan Saffer on microinteractions.
- **The frontier:** designing for AI/generative interfaces, and how design tokens feed AI coding tools so a machine can build on-system by default.
- **Cross-reference:** the UX Principles Encyclopedia — Gestalt (Part 3), accessibility/WCAG numbers (Part 4), component/error states (Part 7), and Nielsen's heuristics (Part 1).

---

## Part 12 — Sources

Primary/authoritative references used to verify this document:

- Robert Bringhurst — *The Elements of Typographic Style* (line length 45–75/66 CPL).
- W3C — WCAG 2.2 (contrast 4.5:1 / 3:1; line-length SC 1.4.8; text spacing SC 1.4.12). w3.org/TR/WCAG22
- Google — *Material Design* (M2/M3): 8dp grid, type/line-height ~1.5, motion durations & easing. m3.material.io
- Apple — *Human Interface Guidelines*. developer.apple.com/design
- Brad Frost — *Atomic Design* (2013). atomicdesign.bradfrost.com
- Salesforce / W3C Design Tokens Community Group — design tokens definition & format.
- Robin Williams — *The Non-Designer's Design Book* (C.R.A.P.).
- Dieter Rams — *Ten Principles for Good Design*.
- Nielsen Norman Group — response-time limits (100ms / 1s); F-pattern reading research.
- Type-scale ratios & 8-point grid: widely-adopted design-system conventions (Material, IBM Carbon, Atlassian, Adobe Spectrum, Tailwind).

*End of document. Numbers are conventions, not constants — verify against the live spec (esp. WCAG and Material) before treating any as final in shipping code. Pairs with `UX-Principles-Encyclopedia-and-Checklist.md`.*
