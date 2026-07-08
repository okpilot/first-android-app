# The UX Principles Encyclopedia & Build Checklist

*A source-verified reference for research, and an actionable checklist for AI-assisted coding.*

Version 1.0 · Compiled July 2026 · Universal (not stack-specific)

---

## Part 0 — How to use this document

This document has **two audiences and two jobs**:

1. **For you (research reference).** Parts 1–7 are the encyclopedia: every major UX principle, who invented it, what it means in plain language, why it matters, and what it looks like when done right versus wrong. Read it, mine it for vocabulary, follow the "dig deeper" trails.
2. **For a machine (build checklist).** Part 8 is a consolidated, imperative checklist written so it can be handed to an AI coding assistant (e.g. dropped into a `CLAUDE.md` project file) or used as a manual heuristic-evaluation pass on any screen. Every line is phrased as a *verifiable* instruction, not a vibe.

**A note on trust.** Every quantitative figure, attribution, and date in this document was verified against primary or authoritative sources at compile time (see Sources, Part 10). Where a "fact" is commonly misquoted in the wild, that's flagged inline. Treat the round numbers (contrast ratios, response-time thresholds, target sizes) as load-bearing — they're the ones worth getting exactly right.

**Legend for each entry:**
- **What** — the principle in one sentence.
- **Why** — why it matters to a user.
- **Build cue** — the concrete thing to do (or avoid) in an interface.

---

## Part 1 — The Foundational Frameworks

*The load-bearing walls. If you learn nothing else, learn these.*

### 1.1 Don Norman's six principles of interaction

From *The Design of Everyday Things* (Donald Norman, 1988; revised 2013). These six explain why some things feel obvious and others feel like fighting the cockpit.

- **Affordance** — What: the possible actions an object offers (a button *can* be pressed; a chair *affords* sitting). Why: it defines what's even doable. Build cue: make the real actions actually possible and reachable.
- **Signifier** — What: the perceivable *cue* that tells the user an affordance exists and where to act (the button *looks* pressable). Norman added this term in the 2013 revision because everyone was misusing "affordance." Why: an affordance nobody can perceive is useless. Build cue: buttons should look like buttons, links like links; don't hide interactivity behind flat mystery-meat.
- **Constraints** — What: deliberate limits on possible actions (physical, logical, cultural) that prevent error. Why: fewer wrong moves means fewer mistakes. Build cue: disable/hide invalid options, restrict inputs to valid formats.
- **Mapping** — What: the relationship between a control and its effect (stove knobs laid out like the burners they control). Why: natural mapping means no memorization. Build cue: put controls near what they affect; up means more, right means forward.
- **Feedback** — What: immediate, informative communication that an action registered. Why: silence breeds doubt and repeated clicks. Build cue: every action gets a visible/audible/haptic acknowledgment — *fast*. Norman's warning: poor feedback is worse than none (it distracts and provokes anxiety).
- **Conceptual model** — What: the user's mental story of how the system works. Why: an accurate model lets people predict and recover; a wrong one bites later. Build cue: design so the interface teaches a correct, simple model of itself.

*The payoff of all six is **discoverability**: a user can figure out what to do and what's happening without a manual.*

### 1.2 The two Gulfs

Also Norman (with Hutchins & Hollan), first described in *User Centered System Design*, 1986. The single most useful diagnostic frame in UX.

- **Gulf of Execution** — the gap between *what I want to do* and *figuring out how to do it*. ("How do I even turn this on?") Bridged by signifiers, constraints, mappings, and a good conceptual model.
- **Gulf of Evaluation** — the gap between *the system did something* and *me understanding what it did*. ("Wait — did that save?") Bridged by feedback and a good conceptual model.

*Aviation frame: this is positive control (execution) and positive verification (evaluation). You command the input, then you confirm the input took. A cockpit that lets you command but never confirms is a wide gulf of evaluation.*

### 1.3 The Seven Stages of Action

Norman's model of how any action unfolds: (1) form the **goal**, then execution — (2) **plan**, (3) **specify**, (4) **perform** — then evaluation — (5) **perceive** the result, (6) **interpret** it, (7) **compare** it to the goal. Good design supports every stage. It's the granular version of the two Gulfs.

### 1.4 Nielsen's 10 Usability Heuristics

Jakob Nielsen, 1994 (refined from a factor analysis of 249 usability problems; wording updated 2020 but the ten are unchanged). These are the industry-standard checklist for spotting usability problems — the "10 commandments."

1. **Visibility of system status** — keep users informed with timely feedback.
2. **Match between system and the real world** — speak the user's language and follow real-world conventions; no internal jargon.
3. **User control and freedom** — provide a clearly marked "emergency exit"; support undo and redo.
4. **Consistency and standards** — same words/actions mean the same thing; follow platform conventions.
5. **Error prevention** — prevent problems before they happen (good defaults, constraints, confirmation on risky actions).
6. **Recognition rather than recall** — show options; don't make users remember information across screens.
7. **Flexibility and efficiency of use** — accelerators (keyboard shortcuts, gestures) for experts, without blocking novices.
8. **Aesthetic and minimalist design** — every extra element competes with the essentials; cut the noise.
9. **Help users recognize, diagnose, and recover from errors** — plain-language error messages (no codes), state the problem, offer a fix.
10. **Help and documentation** — best if not needed, but when it is, make it searchable, task-focused, and concrete.

*This is the default toolkit for "heuristic evaluation" — see Part 6.*

### 1.5 Norman's three levels of emotional design

From Norman's *Emotional Design* (2004). Design lands on three levels at once:
- **Visceral** — gut reaction to how it looks/feels (first impression).
- **Behavioral** — how it feels to actually use (usability, function).
- **Reflective** — the story the user tells themselves about it afterward (meaning, identity, memory).

*Great products satisfy all three. A tool can be usable (behavioral) yet leave no positive memory (reflective).*

---

## Part 2 — The Laws of UX (psychology & cognition)

*Mostly collected and popularized by Jon Yablonski (*Laws of UX*, 2020), but drawn from decades of psychology and HCI. Grouped here by what they govern.*

### 2A. Cognitive load — how much thinking you demand

- **Miller's Law** — *George Miller, 1956.* What: working memory holds about **7 ± 2** "chunks" at once. Why: overload one screen and people drop things. Build cue: **chunk** information into groups. *Common misquote: "7" is NOT a hard limit on menu items or list length — the real lesson is chunking, not a magic number.*
- **Hick's Law** — *W. E. Hick, 1952 (extended by Ray Hyman, 1953); the "Hick–Hyman Law."* What: decision time grows with the number and complexity of choices. Why: too many options → hesitation or abandonment. Build cue: reduce/segment choices; use progressive disclosure; highlight a recommended default.
- **Cognitive Load** — What: the total mental effort an interface demands. Why: it's a finite budget; spend it on the task, not on decoding the UI. Build cue: offload memory onto the screen; kill unnecessary steps and decoration.
- **Choice Overload / Paradox of Choice** — What: too many options causes stress and worse decisions. Why: freezes the user. Build cue: curate; don't dump the whole catalog on one screen.
- **Tesler's Law (Conservation of Complexity)** — *Larry Tesler.* What: every process has an irreducible amount of complexity — you can't delete it, only *move* it between the user and the system. Why: someone always pays. Build cue: make the *system* absorb complexity so the user doesn't (smart defaults, auto-formatting). *Aviation frame: an autopilot doesn't remove the complexity of flying — it relocates it into a box so you don't carry it every second.*
- **Occam's Razor** — What: prefer the simplest design that works. Why: fewer parts, fewer failure points. Build cue: remove elements until it breaks, then add the last one back.
- **Pareto Principle (80/20)** — What: ~80% of use comes from ~20% of features. Why: focus effort where it counts. Build cue: make the vital 20% effortless; tuck the rest away.
- **Progressive disclosure** — What: show only what's needed now; reveal advanced options on demand. Why: manages Hick's Law and cognitive load. Build cue: sensible defaults up front, "advanced" behind a click.

### 2B. Interaction, motion & motivation — the feel of using it

- **Fitts's Law** — *Paul Fitts, 1954.* What: the time to hit a target depends on its **size** and **distance** (bigger + closer = faster). Why: tiny/faraway targets cause misses and slowness. Build cue: make primary actions large and near; exploit screen edges/corners (effectively infinite size). Minimum touch targets: **Apple 44×44 pt, Material 48×48 dp, WCAG 24×24 CSS px (AA)** — see Part 4.
- **Doherty Threshold** — *Doherty & Thadhani, IBM, 1982.* What: keep system response under **400 ms** and productivity/flow soar (this replaced the old 2-second standard). Why: above it, attention drifts and doubt creeps in. Build cue: respond within 400 ms; if the real work takes longer, give instant lightweight feedback (press state, skeleton, optimistic UI).
- **Nielsen's response-time limits** — *Nielsen, Usability Engineering, 1993.* Three thresholds: **0.1 s** feels instantaneous; **1 s** keeps the user's flow of thought; **10 s** is the limit for holding attention (show a progress indicator beyond this). Modern web target: Google's INP (Interaction to Next Paint) metric calls ≤ **200 ms** "good."
- **Postel's Law (Robustness Principle)** — *Jon Postel.* What: be liberal in what you accept, conservative in what you produce. Why: humans input messily. Build cue: forms should accept "+386 31…", "0038631…", spaces and dashes, and clean it up silently instead of scolding.
- **Goal-Gradient Effect** — What: motivation increases as people near a goal. Why: visible nearness drives completion. Build cue: show progress; pre-fill the first step (a punch card with 2 free stamps beats a blank one).
- **Zeigarnik Effect** — What: people remember unfinished tasks better than finished ones. Why: incompleteness nags (usefully). Build cue: progress bars, "profile 60% complete" prompts, checklists.
- **Parkinson's Law** — What: a task expands to fill the time allowed. Why: friction slows people down. Build cue: reduce steps and autofill so tasks finish faster than expected.
- **Flow** — *Csikszentmihalyi, 1975.* What: the absorbed state when challenge matches skill. Why: it's where good work and delight happen. Build cue: remove interruptions, give clear goals and immediate feedback.
- **Fogg Behavior Model** — *BJ Fogg.* What: a behavior happens only when **Motivation + Ability + Prompt** converge at the same moment (B = MAP). Why: explains why users don't act. Build cue: if adoption stalls, raise motivation, make the action easier, or fix the prompt/timing.

### 2C. Memory, attention & perception — what sticks

- **Serial Position Effect** — What: people best remember the **first** and **last** items in a series. Why: the middle gets lost. Build cue: put key nav/actions at the start and end.
- **Von Restorff Effect (Isolation Effect)** — What: the item that stands out is remembered. Why: contrast drives attention. Build cue: make the single primary call-to-action visually distinct — but only one, or none stand out.
- **Peak-End Rule** — *Kahneman.* What: people judge an experience by its most intense moment (**peak**) and its **end**, not the average. Why: a rough middle is forgiven if the peak and finish shine. Build cue: nail the highlight moment and the closing moment (confirmation, thank-you, success state).
- **Aesthetic-Usability Effect** — What: people *perceive* attractive designs as more usable and forgive their flaws more. Why: beauty buys goodwill and error tolerance. Build cue: visual polish is real UX value — *but* it masks usability problems in testing, so don't let pretty hide broken.
- **Mere Exposure Effect** — What: familiarity breeds preference. Why: users like what they've seen before. Build cue: lean on established patterns; introduce novelty gradually.
- **Selective Attention / Banner Blindness** — What: users tune out anything that looks like an ad or is irrelevant to their goal. Why: important things placed in "ad zones" get ignored. Build cue: don't style critical UI like advertising; respect where eyes actually go.
- **Curse of Knowledge (Expert Blind Spot)** — What: once you know something, you can't imagine not knowing it. Why: designers build for themselves and confuse newcomers. Build cue: test with real, fresh users; write for the novice.

### 2D. Conventions & mental models — meeting expectations

- **Jakob's Law** — *Jakob Nielsen.* What: users spend most of their time on *other* sites/apps, so they expect yours to work like the ones they already know. Why: convention beats cleverness. Build cue: don't reinvent standard patterns (cart, search, nav) without a strong reason; when you must deviate, test hard.
- **Mental Model** — What: the user's internal belief about how your system works, imported from past experience. Why: friction happens when your system contradicts it. Build cue: match existing expectations; where you can't, teach the new model explicitly.
- **Principle of Least Astonishment** — What: a component should behave the way its appearance and context lead people to expect. Why: surprising behavior erodes trust and causes errors. Build cue: if a control *could* do something unexpected, redesign it so it can't — the least surprising option is usually the right one.

### 2E. Error, defaults & human factors — designing for imperfect humans

- **Slips vs. Mistakes** — *Norman, building on James Reason's human-error work.* What: **slips** are unconscious execution errors (you knew the right action, your finger slipped); **mistakes** are conscious errors from a wrong mental model (you did the wrong thing on purpose, believing it right). Why: they need different fixes. Build cue: prevent *slips* with constraints and good defaults; prevent *mistakes* by fixing the conceptual model and warning before commitment. *Aviation frame: this is the difference between a control-input error and a decision error — the same split your CRM and human-factors training runs on.*
- **Poka-yoke (error-proofing)** — *from Japanese manufacturing (Shigeo Shingo).* What: design so the wrong action is impossible or obvious, not merely discouraged. Why: prevention beats correction. Build cue: shape inputs so only valid data fits (date pickers over free text, disabled Submit until valid).
- **The Power of Defaults** — What: the pre-selected option is the one most people keep (status-quo bias). Why: defaults are the single highest-leverage nudge you have. Build cue: make the default the safe, common, ethical choice — never a pre-ticked trap (that's a deceptive pattern; see Part 5).
- **Forgiveness / reversibility** — What: assume users will act wrong and let them recover cheaply. Why: freedom to explore without fear. Build cue: undo, autosave, drafts, confirmations on the irreversible.

---

## Part 3 — Visual perception: the Gestalt principles

*From Gestalt psychology (1920s). These describe how the eye automatically groups things — the rules behind visual hierarchy. "The whole is other than the sum of its parts."*

- **Proximity** — elements placed close together are perceived as a group. Build cue: spacing defines relationships more than borders do.
- **Similarity** — elements that look alike (color, shape, size) are seen as related. Build cue: style same-function items the same way.
- **Common Region** — elements inside a shared boundary are grouped. Build cue: cards/containers signal "these belong together."
- **Closure** — the mind completes incomplete shapes. Build cue: you can imply form with less; logos and icons exploit this.
- **Continuity** — the eye follows lines and curves, preferring smooth paths. Build cue: align elements along clear lines to guide the gaze.
- **Figure/Ground** — we separate a focal object from its background. Build cue: use contrast/depth (shadows, blur) to pull modals and key content forward.
- **Common Fate** — elements moving together are perceived as related. Build cue: animate grouped items together.
- **Prägnanz (Law of Good Figure / Simplicity)** — we interpret ambiguous images in the simplest form possible. Build cue: simpler layouts are read faster and remembered better.

---

## Part 4 — Accessibility & inclusive design (WCAG)

*The most commonly skipped "principles" — and often a legal requirement. Standard: **Web Content Accessibility Guidelines (WCAG) 2.2**, published by the W3C on 5 Oct 2023.*

### 4.1 The POUR principles
Every requirement rolls up to four principles — **POUR**:
- **Perceivable** — users can perceive the information (text alternatives, captions, sufficient contrast).
- **Operable** — users can operate it (keyboard access, focus indicators, adequate target sizes, no seizure-inducing motion).
- **Understandable** — content and behavior are predictable and clear (plain language, error identification, declared page language).
- **Robust** — it works with assistive technologies (valid, semantic markup; screen-reader compatible).

Conformance has three levels: **A** (minimum), **AA** (the practical, widely-targeted standard), **AAA** (strictest, rarely fully met).

### 4.2 The numbers that matter (verify these exactly)
- **Text contrast (SC 1.4.3, AA):** normal text **4.5:1**; large text **3:1**. (Large text = 18 pt / 24 px, or 14 pt / ~18.66 px **bold**.)
- **Enhanced contrast (SC 1.4.6, AAA):** normal **7:1**; large **4.5:1**.
- **Non-text contrast (SC 1.4.11, AA):** UI components, icons, focus indicators, form borders need **3:1** against adjacent colors.
- **Target size (SC 2.5.8, AA — new in 2.2):** minimum **24×24 CSS px**. **(SC 2.5.5, AAA:** 44×44.) *Note: the 44×44 figure people quote is Apple's guideline / WCAG's AAA level — not the AA minimum.*
- *Reality check:* low contrast is the single most common accessibility failure — found on ~81% of home pages (WebAIM Million).

### 4.3 Core inclusive-design rules
- **Full keyboard operability** — everything works without a mouse; logical tab order; visible focus ring.
- **Don't rely on color alone** to convey meaning (add icons, text, patterns) — for color-blind users.
- **Alt text** for meaningful images; empty alt for decorative ones.
- **Semantic HTML / proper roles** so screen readers can parse structure (headings, landmarks, labels).
- **Labels on every input** (not just placeholders — placeholders vanish and fail contrast).
- **Respect reduced-motion** preferences; avoid content that flashes more than 3×/second.
- **Captions/transcripts** for audio and video.

---

## Part 5 — Ethics: dark (deceptive) patterns

*Coined by Harry Brignull on 28 July 2010 (darkpatterns.org, now deceptive.design; 2023 book* Deceptive Patterns*). Now written into law — EU Digital Services Act & Digital Markets Act, California's CPRA, and US FTC enforcement. Brignull himself now prefers "**deceptive patterns**."*

**Definition:** interface choices crafted to trick users into doing things they didn't intend, against their own interest. The original taxonomy of twelve, still the cleanest entry point:

- **Roach Motel** — easy to get into, brutally hard to get out of (free-trial sign-up vs. cancellation).
- **Confirmshaming** — guilting the opt-out ("No thanks, I don't want to save money").
- **Privacy Zuckering** — tricking users into sharing more data than they meant to.
- **Sneak into Basket** — adding items to the cart via a pre-checked box or side path.
- **Hidden Costs** — surprise fees revealed only at the last checkout step.
- **Bait and Switch** — the advertised action produces a different, undesirable result.
- **Forced Continuity** — silent charges when a free trial ends, with no reminder.
- **Misdirection** — visual/verbal focus steered toward the choice that benefits the business.
- **Trick Questions** — wording (often double negatives) that means the opposite of what a skim implies.
- **Disguised Ads** — ads styled as content or navigation.
- **Price Comparison Prevention** — making it hard to compare options fairly.
- **Friend Spam** — harvesting contacts to message on the user's behalf.

**The rule:** none of these. They work short-term and destroy trust long-term. The honest inverse — clear pricing, symmetrical opt-in/opt-out, no pre-ticked consent — is both ethical and increasingly *legally mandatory*.

---

## Part 6 — Research & evaluation methods

*How you actually find UX problems rather than guessing.*

- **Heuristic evaluation** — experts audit an interface against a checklist (usually Nielsen's 10). Cheap and fast: **3–5 evaluators typically catch ~60–75% of usability issues.** Each issue gets a **severity rating**.
- **Think-aloud protocol** — a real user narrates their thoughts while using the product. The qualitative gold standard for finding *why* people struggle.
- **Usability testing & the "5-user rule"** — *Nielsen:* about **5 users** uncover the majority of usability problems in a given round; run several small rounds rather than one giant test.
- **Jobs To Be Done (JTBD)** — *associated with Clayton Christensen.* People don't buy products, they "hire" them to do a job ("I hired this milkshake to make my commute less boring"). Design for the underlying goal, not the feature list.
- **Information Foraging & Information Scent** — *Pirolli & Card, Xerox PARC.* Users follow "scent" — cues that a link leads toward their goal — like an animal tracking prey. Weak scent → they give up. Build cue: descriptive links/labels that clearly signal what's on the other side.
- **A/B testing** — compare two versions with real traffic to settle debates with data (behavioral, not opinion).
- **Card sorting / tree testing** — validate information architecture (do your categories match users' mental models?).

---

## Part 7 — Practical UI states & feedback (theory → build)

*Where principles become pixels. Most "bad UX" lives in the states teams forget.*

- **The four+ states every component needs:** default, **loading**, **empty**, **error**, plus success and disabled. Design all of them, not just the happy path.
- **Loading:** show progress; use skeleton screens or spinners; under 1 s often needs nothing, over ~1 s needs feedback, over ~10 s needs a real progress indicator (per Nielsen's limits).
- **Empty states** are onboarding opportunities, not dead ends — explain what goes here and how to start.
- **Error states:** plain language, name the problem, offer the fix, preserve the user's input (never make them retype everything).
- **Optimistic UI:** show the expected result immediately, reconcile with the server after (why chat messages appear before they're confirmed).
- **Microinteractions & feedback:** every tap gets an instant press state; confirm consequential actions; use motion to explain change, not to decorate.
- **Confirmation & undo:** for destructive actions, either confirm first *or* (better) allow undo after — undo beats a nagging "Are you sure?" for reversible actions.
- **Responsive & adaptive layout:** the interface reflows to fit any viewport (phone to desktop); touch targets grow on touch devices; nothing critical is hidden or cut off on small screens. Test the real breakpoints, not just the design canvas.

---

## Part 8 — The Build Checklist (hand this to Claude Code)

*Imperative, verifiable rules distilled from Parts 1–7. Drop this into a `CLAUDE.md` at your project root, or paste it as a review prompt. Each line is checkable against a screen.*

> **Instructions for an AI reviewer:** Go screen by screen (or component by component). For each item, mark ✅ pass, ❌ fail, or ⚠️ N/A. For every ❌, name the specific element, cite the rule, and propose a concrete fix. Rank issues by severity (blocker → major → minor → cosmetic). Do not mark an item ✅ unless you can point to the evidence.

### Feedback & system status
- [ ] Every user action produces visible feedback within **400 ms** (press state, spinner, skeleton, or optimistic update).
- [ ] The system's current state is always visible (loading, saving, saved, offline, error).
- [ ] Operations over ~1 s show progress feedback; over ~10 s show a determinate progress indicator.
- [ ] No action with consequences happens silently.

### Errors & prevention
- [ ] Destructive/irreversible actions require confirmation **or** provide undo (prefer undo when reversible).
- [ ] Invalid states are prevented (disable invalid options, constrain inputs) rather than only caught after.
- [ ] Error messages are in plain language, name the specific problem, and suggest a fix — no raw codes.
- [ ] On form error, the user's already-entered data is preserved.

### Navigation, information architecture (IA) & control
- [ ] Users can always undo, go back, or exit ("emergency exit"); no dead ends or traps.
- [ ] Navigation follows conventions users already know (Jakob's Law); deviations are justified.
- [ ] Link and button labels clearly signal their destination/result (strong information scent).
- [ ] Key navigation and actions sit at the start and end of lists/menus (serial position).

### Forms & input
- [ ] Every input has a persistent visible label (not placeholder-only).
- [ ] Inputs accept messy human formats and normalize them (Postel's Law) — phone numbers, dates, spaces, casing.
- [ ] Validation is inline and immediate where possible; requirements are stated before submission.
- [ ] Forms ask for the minimum necessary; steps are chunked and progress is shown for long flows.

### Cognitive load & choice
- [ ] No screen forces the user to remember information from another screen (recognition over recall).
- [ ] Choices per decision point are limited/grouped; a sensible default or recommendation is offered (Hick's Law).
- [ ] Related information is chunked into digestible groups (Miller's Law — chunking, not a hard count).
- [ ] Advanced/rare options use progressive disclosure; the common 20% is front and center.
- [ ] Complexity is absorbed by the system (smart defaults, autofill) wherever possible (Tesler's Law).

### Visual hierarchy & Gestalt
- [ ] Related items are visually grouped by proximity and/or a shared container (proximity, common region).
- [ ] Same-function elements share consistent styling (similarity, consistency).
- [ ] Exactly one primary action per view is visually dominant (Von Restorff); secondary actions are quieter.
- [ ] Layout removes non-essential elements; every element earns its place (aesthetic-minimalist).

### Consistency
- [ ] The same word/icon/action means the same thing everywhere (internal consistency).
- [ ] Platform and industry conventions are followed (external consistency).
- [ ] A design system / shared components enforce this (no one-off buttons).

### Performance
- [ ] Interactions feel instant (target INP ≤ **200 ms**; hard ceiling **400 ms** for feedback).
- [ ] Perceived performance is managed even when real work is slow (skeletons, optimistic UI, staged loading).
- [ ] Layout is responsive: it reflows from mobile to desktop with no cut-off content, horizontal scroll, or overlapping elements at standard breakpoints.

### Accessibility (WCAG 2.2 AA baseline)
- [ ] Normal text contrast ≥ **4.5:1**; large text ≥ **3:1**; UI components/icons/focus rings ≥ **3:1**.
- [ ] Interactive targets are ≥ **24×24 CSS px** (AA); prefer larger (44–48 px) for touch.
- [ ] Everything is fully operable by keyboard, with a logical tab order and a visible focus indicator.
- [ ] Meaning is never conveyed by color alone (add text, icon, or pattern).
- [ ] Meaningful images have alt text; markup is semantic (headings, landmarks, labeled inputs).
- [ ] `prefers-reduced-motion` is respected; nothing flashes more than 3×/second.

### Content & microcopy
- [ ] UI uses the user's language and real-world concepts, not internal jargon (match to real world).
- [ ] Every component has designed empty, loading, error, and success states — not just the happy path.
- [ ] Empty states explain what belongs there and how to begin.

### Ethics (no deceptive patterns)
- [ ] Opt-in and opt-out are equally easy; consent boxes are never pre-ticked.
- [ ] Cancellation/deletion is as easy as sign-up (no roach motel).
- [ ] Full price/fees shown before the final step (no hidden costs); no confirmshaming; no disguised ads.

---

## Part 9 — Research backlog (dig deeper later)

*The runway holding queue — not a graveyard. Threads worth pulling when you have time.*

- **Books:** Norman, *The Design of Everyday Things* (the bible) · Krug, *Don't Make Me Think* (the title is the whole thesis) · Yablonski, *Laws of UX* · Brignull, *Deceptive Patterns* · Weinschenk, *100 Things Every Designer Needs to Know About People*.
- **Frameworks to explore:** Norman's *Seven Stages of Action* in depth · Tognazzini's *First Principles of Interaction Design* (a longer heuristic list) · Shneiderman's *Eight Golden Rules of Interface Design* (a close cousin of Nielsen's 10, worth comparing) · Weinschenk's behavioral list.
- **Method deep-dives:** heuristic evaluation severity scoring · running a proper think-aloud test · card sorting/tree testing for IA · the debate over Nielsen's "5 users is enough."
- **Adjacent numbers to memorize:** the full WCAG 2.2 success-criteria list · Core Web Vitals (LCP, INP, CLS) as the performance side of UX.
- **The frontier:** how these laws bend for AI/chat/voice interfaces (where you're not guiding users through fixed screens but interpreting open-ended intent) — an active, unsettled area.

---

## Part 10 — Sources

Primary and authoritative references used to verify this document:

- Nielsen Norman Group — *10 Usability Heuristics for User Interface Design* (Jakob Nielsen, 1994; updated 2024). nngroup.com/articles/ten-usability-heuristics
- Don Norman — *The Design of Everyday Things* (revised ed., 2013). jnd.org
- Jon Yablonski — *Laws of UX* (2020). lawsofux.com
- W3C — *Web Content Accessibility Guidelines (WCAG) 2.2* (5 Oct 2023). w3.org/TR/WCAG22
- Harry Brignull — *Deceptive Patterns* / deceptive.design (term coined 2010).
- Doherty, W. J. & Thadhani, A. J. — *The Economic Value of Rapid Response Time* (IBM, 1982).
- Nielsen, J. — *Usability Engineering* (1993) — response-time limits (0.1 s / 1 s / 10 s).
- Miller, G. — *The Magical Number Seven, Plus or Minus Two* (1956).
- Fitts, P. — target-acquisition law (1954); Hick (1952) & Hyman (1953) — choice reaction time.
- Pirolli & Card — *Information Foraging Theory* (Xerox PARC).
- Kahneman, D. — Peak-End Rule / *Thinking, Fast and Slow*.

*End of document. Facts verified at compile time; standards (esp. WCAG) evolve — re-check the numbers against the live W3C spec before treating any as final in a shipping product.*
