---
date: 2026-07-07
status: active
project: First Android App (learning CRM)
---

# Decisions & Ideas Ledger

> Append-only, numbered, dated log. New decisions go at the bottom with the next
> number. Amend in place with a dated sub-note — never silently rewrite. Standing
> summary at the top for quick orientation.

## Standing decisions (summary)
- **Stack:** Flutter (Dart) client → Android / Web / Linux desktop; trimmed
  self-hosted Supabase (Postgres + PostgREST + GoTrue) on homebase behind Caddy.
- **Method:** emergent — thin vertical slices, YAGNI, schema grows by migration.
- **Conventions:** modeled on the (verified) LMS Plus conventions, scaled down.

---

## Decision 1: Build with Flutter, one codebase for all platforms (2026-07-07)
**Context:** Wanted an Android app now and a web interface later with minimal duplicated work; user is on Linux.
**Decided:** Use Flutter/Dart — one codebase compiles to Android + Web + Linux desktop (iOS later, needs a Mac). Start with Web + Linux desktop (both run on the dev machine today); defer the Android SDK.
**Principle:** One codebase, many targets — don't build the UI twice.

## Decision 2: Dart is the only app language; web is not TypeScript (2026-07-07)
**Context:** User assumed a web app requires TypeScript.
**Decided:** Write everything in Dart. Flutter compiles Dart → JavaScript for the browser automatically. No TS / JS / Kotlin by hand.
**Principle:** The browser runs JS, but we don't hand-write it — Dart compiles to it.

## Decision 3: Practice project is a disposable light CRM (2026-07-07)
**Context:** Need a concrete thing to build to learn on. User already self-hosts EspoCRM but does not want to reuse it.
**Decided:** Build a light CRM from scratch as a learning vehicle. The product is disposable; learning is the point.
**Principle:** The vehicle serves the learning, not the other way round.

## Decision 4: Build the emergent way (2026-07-07)
**Context:** User builds through discovery; cannot/does not want to specify large features up front — layout and schema should emerge.
**Decided:** Work in thin vertical slices (walking skeleton first). Grow the schema by forward-only migration, one field/table at a time. Apply YAGNI. Every "add X" = smallest working version → review → next slice.
**Principle:** Discover the design by building it, not before.

## Decision 5: Backend = Postgres, served the Supabase way, trimmed + self-hosted (2026-07-07)
**Context:** User's verified conventions are deeply Postgres/RPC/RLS-shaped; a Flutter client can't safely hit raw Postgres. Full self-hosted Supabase is too heavy; an earlier PocketBase idea wouldn't reuse the Postgres muscle memory.
**Decided:** Self-host a **trimmed** Supabase on homebase — Postgres + PostgREST (REST/RPC) + GoTrue (auth), routed through the existing Caddy (no Kong). Skip Realtime/Storage/Studio/imgproxy. ~80–130 MB idle (less if we reuse an existing Postgres). Flutter uses `supabase_flutter`.
**Principle:** Take Postgres's power and Supabase's conventions; leave the weight behind.

## Decision 6: Model conventions on LMS Plus — verified, then scaled down (2026-07-07)
**Context:** LMS Plus is a mature project with established conventions; a single extraction pass idealized several DB claims.
**Decided:** Adopt LMS Plus conventions, but only after two independent audit rounds verified them. Corrections: it is NOT "everything is RPC" (RPC for multi-table/immutable/sensitive; direct RLS access otherwise); pagination is LIMIT/OFFSET (default 10), not keyset; hard DELETEs exist only as annotated exceptions; secrets were leaked in its settings (anti-pattern to avoid). Scale the tooling down — principles, not the full 10-agent ceremony.
**Principle:** Inherit *verified* principles, not idealized ones; earn ceremony as the project grows.

## Decision 7: Adopt CodeRabbit + a scaled cr-local/fullpush push gate (2026-07-07)
**Context:** CodeRabbit is installed org-wide on `okpilot` (so it reviews every repo's PRs), and the `coderabbit` CLI is installed + Pro. The user requires cr-local before every push, per their LMS Plus `/fullpush` gate.
**Decided:** Adopt, scaled to this project: (a) `.coderabbit.yaml` (lean, Dart + SQL path_instructions, no secrets); (b) `.claude/commands/crlocal.md` — run `coderabbit review --base main --type committed`, triage apply/skip/defer reading source, min 2 rounds (3 for SQL/security), stop when ≥min and last round clean, ceiling 4 fix-commits; (c) `.claude/commands/fullpush.md` — analyze + test + build + crlocal + explicit push approval; (d) **branch per slice**, `main` stays green. CI/CD (GitHub Actions) added with Slice 1.
**Principle:** cr-local before every push; the cloud bot on the PR is the authoritative gate. Earn heavier ceremony (multi-agent pipeline, e2e, scanners) as the project grows.

## Decision 8: Styling = stock Material 3 for now; theming deferred (2026-07-08)
**Context:** Coming from the TS/React world, the user styles with shadcn/ui. Flutter needs no such component library — Material 3 is built into the framework, and a "theme" is a `ThemeData` object (shadcn's CSS-variable block ≈ `ThemeData`; `ColorScheme.fromSeed(seedColor:)` turns one seed color into a full accessible light+dark palette).
**Decided:** Slice 1 (and until a slice actually calls for styling) uses **stock Material 3** — `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo))`. No component library, no custom theme. References bookmarked for the first styling slice (see IDEAS/NOTES): Material Theme Builder, `flex_color_scheme`, and `shadcn_ui`/`forui` if we ever want the flat shadcn aesthetic.
**Principle:** Good-looking defaults for free; earn a custom theme emergently, when a slice needs it.

## Decision 9: Adopt the UI/UX principle encyclopedias — as references, applied proportionally (2026-07-08)
**Context:** The user added two large source-verified reference docs (UI + UX Principles Encyclopedia & Build Checklist). An initial adoption plan over-reached (promote both full docs to "binding, read every session", make their ~60 checklist items a push gate). Two adversarial critics converged: that violates the project's own earn-ceremony / YAGNI ethos before a single styled screen exists.
**Decided:** Adopt them **lighter**: (a) both encyclopedias moved into `docs/` unchanged (verified content preserved, internal cross-refs intact); (b) a thin operative wrapper `docs/design-principles.md` is the only thing bound in CLAUDE.md — the encyclopedias are its on-demand references, pulled **only at UI slices**; (c) checklist review is **advisory guidance at UI slices, never a push gate** (the gate stays analyze/test/build/CodeRabbit per Decision 7); (d) apply **proportionally** — a slice-type→checklist-group map, review only relevant groups; (e) numbers split into load-bearing WCAG AA defaults we honor (contrast 4.5:1/3:1, target ≥24px, focus, keyboard, not-color-alone) vs advisory rules-of-thumb (60-30-10, 66ch, grid, motion timings); (f) a web-cue→Flutter translation table + M3-conflict flags (dark-mode ≠ `#121212`; body ≠ hard-16px — M3 wins per Decision 8); (g) multi-platform (Android/web/Linux) responsive+adaptive reaffirmed as a standing constraint with Flutter teeth (Material window classes 600/840/1200, adaptive NavigationBar→Rail→Drawer, honor `textScaler`, Linux min window, **Material-everywhere carve-out** resolving the docs' "honor native conventions" line). Docs are a July-2026 snapshot; re-verify against the live spec where a slice depends on a number.
**Principle:** References earn their weight at the slice that needs them; don't bind prose you won't read or gate on rules you haven't reached.

## Decision 10: Run the backend locally for development; homebase deploy deferred (2026-07-08)
**Context:** Building the first real feature (Contacts) "with the backend". homebase was unreachable (SSH timed out) and the user said push nothing. Standing up the trimmed Supabase on homebase needs interactive Tailscale auth + a push — both off the table.
**Decided:** Run the trimmed stack **locally** in `backend/` via docker-compose — **Postgres + PostgREST + a Caddy gateway** that exposes the Supabase `/rest/v1` path so `supabase_flutter` works unmodified (mirrors the homebase shape). **GoTrue (auth) is deferred** to the first auth slice (database.md "Not now") — anon-role access under RLS for now. Dev secrets live in gitignored `backend/.env`; the Flutter client gets URL + anon key via `--dart-define-from-file`. Homebase deploy (into `okpilot/selfhost`, public HTTPS) is a deliberate later slice. **Soft-delete goes through a `soft_delete_contact` SECURITY DEFINER RPC** because a direct UPDATE of `deleted_at` fails the SELECT policy via PostgREST's RETURNING (42501) — a single-table exception to "direct under RLS", consistent with database.md's "soft-delete via function".
**Principle:** Develop against a faithful local copy of the real stack; promote to homebase when it's a deliberate, reachable step.

## Decision 11: Install the Android SDK now — the app is genuinely multi-target (2026-07-08)
**Context:** Decision 1 deferred the Android SDK (web + Linux first). The user asked to run the actual APK on Android now.
**Decided:** Install the full Android toolchain **portably into the home dir** (no `sudo` available): Temurin **JDK 17** (`~/jdks`), Android **cmdline-tools + SDK** (`~/Android/Sdk`, API 35 image + platform/build-tools 36), env in `~/.android-env`. Added the `android/` platform to the project (`flutter create --platforms=android .`). A **debug-only manifest overlay** (`android/app/src/debug/AndroidManifest.xml`) keeps Flutter's `INTERNET` permission **and** adds `usesCleartextTraffic` so the debug build reaches the local HTTP backend; release builds are unaffected. Emulator reaches the host backend via `adb reverse` (or `10.0.2.2`). Verified: the Contacts feature runs on a Pixel emulator, loading real data from Postgres.
**Principle:** One codebase, three targets — earn each target when a real need (running on Android) arrives.

## Decision 12: Contacts is the first real vertical slice — full CRUD, backed & tested (2026-07-08)
**Context:** The static walking-skeleton (Slice 1) was parked as "useless". Contacts is now built for real.
**Decided:** A proper slice: `contacts` table (6 fields + standard/soft-delete columns) → PostgREST under RLS → `supabase_flutter` → an **injectable repository** (so widget tests use a fake, keeping CI hermetic) → list / detail / add-edit screens with **loading/empty/error states**, guarded soft-delete, date picker. Styling stays **stock Material 3** (Decision 8) — a bespoke mono/Linear-Attio theme is its own later slice. Applied the newly-adopted design principles (Decision 9) proportionally: hierarchy, 8-pt spacing, designed states, labels-not-placeholders, ≥48px targets.
**Principle:** Thin but *whole* — one feature, all the way down (UI → logic → data → backend), states and tests included.

## Decision 13: Bespoke monochrome theme (Linear/Attio) + one type scale (2026-07-08)
**Context:** With the Contacts feature working, stock Material 3 (indigo, tonal, rounded) looked "completely wrong" against the flat/tight/monochrome direction we'd converged on in the prototype (direction D + mono palette). This is the "theming slice" Decision 8 anticipated.
**Decided:** A single bespoke `ThemeData` in `lib/theme.dart` translating the prototype tokens — near-black ink as the *only* accent, `surfaceTint` transparent (kills M3 tonal elevation → truly flat), small radii (10/8px), hairline dividers, `VisualDensity.compact`, neutral-gray avatars, ink-filled buttons. **Both light and dark** first-class (`ThemeMode.system`). After a typography QA (fonts/weights were drifting because `TextField`/`CircleAvatar`/`InputDecoration` used their own defaults), consolidated to **one documented type scale, exactly three weights**: w600 titles/names/buttons · w500 field labels · w400 values/body — referenced everywhere instead of ad-hoc `copyWith`.
**Principle:** One theme file, one type scale — hierarchy from deliberate size+weight, never accident. Supersedes the "stock M3 for now" half of Decision 8.

## Decision 14: Backend deployed to homebase — tailnet-only; schema stays in the app repo (2026-07-08)
**Context:** Time to make the backend real. Chosen: deploy to homebase (Decision 10 revisited). Also settled the ongoing workflow so schema doesn't get duplicated across repos.
**Decided:** Deployed the trimmed stack to homebase as `okpilot/selfhost/stacks/firstapp-crm/` — **infra only** (Postgres 16 + PostgREST + Caddy gateway + PostgREST roles), fronted by the main Caddy at **`https://homebase.tail7ab4bc.ts.net:8452`** with a Tailscale TLS cert. **Tailnet-only** (the S23+ reaches it with the Tailscale app; no public internet exposure while there's no auth). Real secrets generated on the server into a gitignored `.env`; **started empty** (no seed). **The schema is NOT in selfhost** — `backend/migrations/` in *this* repo is the single source of truth, applied to any environment (local docker, homebase) by **`backend/deploy-homebase.sh`**, a forward-only migrator over the tailnet that tracks applied files in `public._migrations`. So a future change = new migration + UI here → test locally → run the migrator against homebase; selfhost is touched once and rarely again. App points at homebase via gitignored `dev-defines.homebase.json`.
**Principle:** Infra and schema are different things — the server is a dumb host (selfhost), the schema lives with the app and is applied to environments. No copy-paste between repos.
**Amendment (2026-07-09, PR #11):** The migrator's idempotency was broken — its per-migration exists-check ran `psql -c "…"` through `ssh → docker exec`, so the space-containing query got word-split on the remote side and always returned empty; the script re-applied *every* migration and only worked against a fresh DB (re-runs failed `relation … already exists`). Fixed to pipe the check over **stdin** with `psql -v :'name'` quoting (survives all three hops; the apply + ledger-insert paths already used stdin and were fine). The migrator is now genuinely idempotent — re-runs skip already-applied files. (Also: a homebase deploy may prompt a one-time Tailscale SSH re-auth; safe to let it continue or re-run after.)

## Decision 15: Mechanical git hooks — scaled from LMS Plus, no Node (2026-07-08)
**Context:** The project had no mechanical enforcement (a deliberate scale-down per Decision 6). The user has a mature lefthook + Claude-Code-hook setup in LMS Plus and wanted the equivalent here, in the same logic. Most LMS Plus hooks are Node/TS-specific (biome, commitlint, pnpm) and don't transfer.
**Decided:** Add tracked git hooks under `.githooks/` (activated by `scripts/setup-hooks.sh` → `git config core.hooksPath .githooks`; no lefthook/Node dependency), mirroring the LMS Plus three-layer structure adapted to Flutter/Dart: **pre-commit** (blocking) = `dart format --set-exit-if-changed` on staged Dart + `flutter analyze`; **commit-msg** (blocking) = Conventional Commits via a shell regex (commitlint's intent, no Node); **pre-push** (blocking) = a security scan that refuses to push `.env`/`dev-defines*` files or diffs containing private keys / JWTs. `/crlocal` deliberately stays a step inside `/fullpush` (manual review gate), NOT mechanized. Heavier LMS Plus layers (Claude-Code PreToolUse guards, security-auditor subagent, review-gate) are deferred — add when earned.
**Principle:** Deterministic tier catches the mechanical misses (format/analyze/commit-format/secrets); human+CR review stays in the push gate. Earn each guard; don't port ceremony wholesale across stacks.

## Decision 16: Calendar — a four-view shell first, events next (2026-07-08)
**Context:** User asked to "add a calendar to schedule events." Per the emergent method we prototyped it in a throwaway interactive artifact, aligned it to the mono theme, and chose the views *before* writing Flutter — settling on **Month · 3-day · Day · Agenda**, phone-first. This slice ships only the calendar *chrome* (navigation + views + date logic); **scheduling/events are the very next slice**.
**Decided:** (a) The app's first **navigation shell** (`HomeShell`) — **adaptive**: bottom `NavigationBar` <600 dp, side `NavigationRail` ≥600 dp (Drawer ≥1200 dp deferred), honoring the standing multi-platform constraint (Decision 9) now that web/Linux ship; both screens in an `IndexedStack` to preserve state. (b) `CalendarScreen` = AppBar (period label + prev/next/today) + a full-width `TabBar` switcher + `TabBarView` of the four views; **Monday-start**; pure date logic in `lib/util/calendar.dart` (DST-safe `DateTime(y,m,d)` math, **no `intl`**), unit-tested. (c) **Week = 3-day on phone**; the full 7-column week is deferred to a later adaptive/wide-screen slice. (d) **Zero new packages** — `table_calendar` rejected (covers only Month, fights the mono theme); hand-built hairline month grid + hour timelines. (e) Extracted a shared `EmptyState` widget (Contacts adopted it). (f) The plan passed **3 adversarial critics** + a **light+dark visual-fidelity QA vs the artifact** before being called done — fixes folded in: hairline grid, evenly-split tabs, grouped period nav, **ink** (not red) now-line, `inkSoft` (AA-safe) out-of-month dimming, contained "No events yet" chips, and a static (no-timer) now-line so widget tests settle.
**Principle:** Prototype → align views/style → thin shell first, data next. A calendar's chrome is worth one slice; events earn their own.

## Decision 17: Adopt `/replycoderabbit` — always answer the cloud bot (2026-07-09)
**Context:** The push gate (Decision 7) covered `/crlocal` (local pre-push preview) but had no step for replying to the **cloud** CodeRabbit review on the PR — the authoritative gate. This session I fixed a cloud-CR finding on PR #4 but left the thread unanswered until the user flagged it.
**Decided:** Adopt a scaled **`.claude/commands/replycoderabbit.md`** (from LMS Plus): after disposing findings, reply inline to every `coderabbitai[bot]` comment on the PR citing the fix commit (or skip/defer reason), one general comment for outside-diff findings, then verify across **both** the `pulls/.../comments` (inline) and `issues/.../comments` (general) endpoints that no root finding is unanswered. Wired it into `/wrapup`'s findings-disposition step. Heavier LMS Plus CR tooling (`coderabbit` full triage, `coderabbit-sync` agent, `automerge`) stays unadopted until earned.
**Principle:** Never leave a CodeRabbit finding unanswered; the reply cites the fix commit so a reviewer can verify. Closing the loop with the authoritative gate is part of the push workflow, not optional.

## Decision 18: Calendar events + attendees — date/time model + RPC write path (2026-07-09)
**Context:** Making the calendar real after the shell (Decision 16): create/edit/delete events and assign contacts as attendees. Prototyped in a throwaway artifact and approved; the build plan was run through **3 adversarial critics** (scope/YAGNI · correctness · design/UX) before coding, fixes folded in.
**Decided:**
- **Data model — `date` + `time` + `all_day`, NOT `timestamptz`.** No auth, single user, all local; the calendar's date logic is already local + DST-safe, so this dodges timezone complexity we don't need yet. **Trade-off (accepted + documented): single-day, non-overnight events only** — a `time`-only end with no end-date plus the `end_time > start_time` CHECK makes a 21:00→01:00 event impossible. Revisit with `timestamptz` if overnight/multi-timezone ever matter. Model stores times as `int?` minutes-from-midnight (pure Dart, no `TimeOfDay`), bridged to the picker at the UI boundary.
- **Attendees = a join table** `event_attendees(event_id, contact_id)` (composite PK, FKs `on delete cascade` — both entities are soft-deleted, so cascade is a safety net not the normal path). The `contacts` embed is **to-one** and comes back **null** for a soft-deleted attendee (RLS hides it); the client skips nulls.
- **Writes go through SECURITY DEFINER RPCs** (`create_event` / `update_event` / `soft_delete_event`), because an event + its attendees is a **multi-table** write (`database.md` #1/#2, atomic). They run as the table **owner → bypass RLS**, so `events`/`event_attendees` grant anon **SELECT only** (least privilege; no direct insert/update). **Corrected rationale:** the bypass is because SECURITY DEFINER runs as owner — NOT because the fn returns a scalar (the `soft_delete_contact` 42501 was a PostgREST REST-layer re-check, which doesn't apply inside a function). `update_event` **replaces** the attendee set; the hard-DELETE of join rows is the annotated exception to soft-delete-by-default (#4 — membership is derived, not a soft-deletable entity).
- **Reads = a direct embedded PostgREST select** (`events?select=…,event_attendees(contact_id, contacts(id,name,company))`), RLS-filtered, sorted in Dart (all-day first, then start time — `.order()` would put NULL/all-day last).
- **UI/theme:** the four views became data-driven; the timeline uses **greedy lane-packing** for overlapping events (improved on the plan's inset-only approach per the design critic — full occlusion hides data). New tokens in `theme.dart`: an `EventBlockStyle` ThemeExtension (fill **+ hairline border** + ink rail — border-defined so blocks read in light AND dark), plus mono `switchTheme` and `timePickerTheme`; the time picker is forced to **24-hour** (no AM/PM). Extracted a shared `InitialsAvatar` (with a `ring` param so stacked attendee faces separate in mono).
- **QA:** SQL curl-verified (RPCs, embed shape, all CHECK guards incl. overnight rejection); **31 unit + widget tests**; and a **visual QA on the Android emulator in light + dark** across every screen (the canonical run path — web has the known IPv6/origin backend issue).
**Principle:** Multi-table writes earn one atomic SECURITY DEFINER RPC; the model stays as simple as the single-user/local reality allows (date+time, not timestamptz); prototype → critics → build → visual QA.

## Decision 19: Event types — colour-as-data + a Settings home (design direction, 2026-07-09)
**Context:** Next feature: user-defined **event types** (categories) with colours, assignable to events. Explored in two throwaway artifacts (a quick concept, then a full-fidelity tap-through matching the real Day timeline / Agenda / form / detail), QA'd in-browser light + dark, and **approved by the user**. **Build not started** — data model + RPC + thin slicing go through adversarial critics before any Dart.
**Decided (design direction only):**
- **One type per event** — a category, not multi-label tags. `events` gains a **nullable** `type_id`; "No type" stays valid.
- **Colour is data, never chrome.** The app stays mono (theme.dart: "the accent IS the ink"); the *only* colour anywhere is a type's identity, surfaced as (a) a small filled **dot** in lists / pickers / detail / Agenda and (b) the **whole Day/3-day event block** coloured by type. Buttons/text/chrome stay ink. Linear/Attio discipline.
  - **Amended 2026-07-10:** the initial plan used a coloured **left rail** on the block (from the existing `EventBlockStyle.rail`); the user rejected it as an AI-slop tell ("accent bar on a card") — the design-principles skill lists the same cliché. Blocks are now **full-area coloured, no rail**. **Decided: Tint** (soft wash of the type colour + **ink** text) over Solid (bold fill + white text) — Solid was too loud for the mono system, risked white-on-amber contrast, and fought the quiet dot language; Tint keeps ink text primary and colour secondary. The `EventBlockStyle` extension will carry a **fill + text-colour** pair instead of a rail. **Corrected in Slice 3 (2026-07-10):** the extension keeps **fill + hairline border** (the no-type default); the *text* colour is derived in-widget, and a typed block swaps its fill for `tintForType(...)` while keeping the same border — so the border carries objecthood and colour is pure enrichment. `EventBlockStyle.rail` was removed outright.
  - The Event-types manager list shows **swatch + name only** — no per-type event count (user's call).
- **Month density dots are coloured by type** — the user's explicit call (overrode the initial "keep Month mono" proposal); no-type = neutral grey dot. **Busy days use "Deduped +N":** up to 3 dots for the *distinct types* present that day, then a `+N` count of the remaining events — chosen over capped-chronological (showed 3 identical dots for a day of meetings) and plain dedupe (hid busyness).
  - **Amended 2026-07-10 (Slice 3):** switched from deduped-by-type to **density dots, coloured** — up to 3 dots by *event count* (each coloured by that event's type; no-type → neutral ink), then `+N` = remaining events. Two adversarial critics caught that dedupe-by-type both **emptied no-type-only days** (0 distinct types → 0 dots) and **undercounted busyness** (3 same-type events read as one dot + "+2"). The user chose density-coloured. Out-of-month days stay grey (colour = "this month").
- **Curated palette, no freeform picker** — 9 muted mid-luminance swatches (blue · teal · green · amber · orange · red · purple · pink · slate) chosen to read on both `#FDFDFF` and `#121316`. Freeform RGB rejected as slop-prone.
  - **Amended 2026-07-10:** dropped to **8 swatches** — **slate removed** (a desaturated grey-blue collapses into the no-type neutral in both themes). Implemented in `lib/util/event_type_palette.dart` as named swatches (each carries a screen-reader label).
- **Management home = a new Settings destination.** Promote the nav to 3 tabs (Contacts · Calendar · Settings); **Settings → Event types** is the manager + editor, and types are *also* creatable on-the-fly from the event form's Type picker sheet. **Delete is non-destructive to events:** they keep their schedule and fall back to "No type" (can't be undone).
  - **Amended 2026-07-10 (Slice 3):** the form's Type picker is **pick-existing-only** — inline type-create was deferred (a scope-trim the user chose). The picker sheet offers the existing types, "No type", and a **"Manage types…"** action that opens the existing Settings manager; the list refreshes on return. Inline create-and-select is a tracked follow-up.
- **Implementation status (amended 2026-07-10):** the design was built in thin slices (supersedes this entry's opening "Build not started" note). **Slice 1** shipped — `event_types` table + `events.type_id` FK + `EventType` model + read embed (PR #13). **Slice 2** shipped — Settings → Event types manager/editor + `soft_delete_event_type` RPC, palette dropped to 8 swatches (PR #14). **Slice 3** shipped — `p_type_id` on the write RPCs, the event-form Type picker, full-area **tinted** Day/3-day blocks (no rail), dot + name in Agenda/detail/panel, coloured Month density dots + "+N"; a shared `TypeLabel` atom; `tintForType` (HSL-lightened + `alphaBlend` on dark) calibrated on the emulator light+dark (PR #15).

**Principle:** Introduce colour only as user-owned data in minimal tokens (a dot + a full-area block tint — the left rail was dropped, see the 2026-07-10 amendment above), never in chrome; give app config a real home (Settings) as the app matures; prototype → approve → critics → build.

## Decision 20: Split cloud-CodeRabbit handling into `/coderabbit` (triage) + `/replycoderabbit` (reply) (2026-07-10)
**Context:** Decision 17 adopted a single `/replycoderabbit` that both triaged and replied. In practice that conflated two moments — deciding (right after the review) and responding (a later sweep, sometimes a different session) — and a one-off "adaptation" this session quietly merged even more logic into it. LMS Plus keeps them as two commands. The redesign ran through **3 adversarial critic rounds (9 reports, verified against live PRs #14/#15)**, which killed several plausible-but-wrong approaches.
**Decided:**
- **Two commands, split by moment:** **`/coderabbit`** triages the cloud review (investigate each finding vs current source → FIX/DEFER/SKIP, using `/crlocal`'s rubric; implements FIX-NOW after approval; **never pushes**), then **`/fullpush`** pushes, then **`/replycoderabbit`** posts the reply (**never triages**). Wired into `/wrapup` in that order.
- **One shared `scripts/cr-findings.sh`** does fetch+normalize (the single source of truth for the hard-won CodeRabbit quirks), emitting the **union of ALL review runs**; each command applies its own logic. Fixture-tested; `[]`+exit 0 on clean, non-zero only on real failure.
- **Handoff = a machine-readable PR comment**, not context or a gitignored file. `/coderabbit` upserts a `<!-- crtriage -->` comment with hidden `<!-- crfinding:<id>:<verdict>:<ref> -->` lines; `/replycoderabbit` joins on `<id>` and upserts a `<!-- crreply -->` comment.
- **Stable finding identity** — a line-number-free content hash (lines move when code is fixed) that is the join/idempotency/loop-termination key; a re-raised already-disposed finding matches its prior verdict instead of bouncing the two commands forever. The **exact byte formula lives in `scripts/cr-findings.sh`** (its single source of truth): first 12 hex of `sha1(path + "\n" + normalized_title)`, where `normalized_title` is lowercased, trimmed, and internal-whitespace-collapsed (note the `\n` separator and the 12-char truncation — the ledger points at the script rather than restating the formula, to avoid drift).
- **Currency is NOT git-ancestry** (rebases make review commits diverge from head) and **NOT "latest review"** (actionable findings can sit in an older run than a later nitpick-only run). It's the union, validated against current source. Fix SHAs are resolved **live at reply time** (`git log`), never stored (rebases rewrite them).
**Refines:** Decision 17 (which stays as the "always answer the cloud bot" principle; this splits *how*).
**Principle:** One rulebook, two surfaces — triage before reply, decide once and record it durably on the PR, and anchor everything on a rebase-stable content identity, never on SHAs or line numbers.
- **Merged & dogfooded 2026-07-10 (PR #16 → `c2a3fc6`).** The first live `/coderabbit → /fullpush → /replycoderabbit` run was on the split's own PR, and it FIX-NOW'd two real bugs the pre-push `/crlocal` rounds had missed: **(1)** the comment lookups used an **unanchored** `test("<!-- crtriage -->")`, so a finding whose *description quotes* the literal marker string matched the wrong comment (I briefly overwrote the triage comment with the reply) → anchor all lookups to `^` (the marker is always the body's first line), and don't embed literal markers in human-facing finding text; **(2)** the `crfinding` payload was colon-delimited but the ref (a `fix: …` Conventional-Commit subject) contains colons → parse `id`+`verdict`+`remainder-of-line`, splitting on the first two colons only. Also fixed: invalid `gh api --jq --arg` (use `env.ME`), silent-drop of unmapped inline findings in `cr-findings.sh` (emit under a synthetic run + warn), crreply author-scoping. **Lesson:** eating our own dog food on the tooling PR is the cheapest place to find tooling bugs.

## Decision 21: No separate docs site — a README Features section instead (2026-07-10)
**Context:** Explored the idea of a user-facing documentation page. Initially picked a **separate docs website** (VitePress) motivated by "a real user-facing feature," and built a first thin slice locally (scaffold + one "Features" page, content pulled from the real screens). Before committing, ran **3 adversarial critics** (premise/scope · docs-IA · tooling).
**Decided — reverse the approach:** drop the separate site; put a **`## Features` section in `README.md`** instead, written at **capability level** (no button labels, no palette counts, no status) so it can't rot as the UI changes. Rationale from the critics: the app has no external audience (single-user, self-hosted); a docs site teaches Node/VitePress rather than the stated goal (Flutter); it's the biggest non-app artifact for a **disposable** CRM; and hand-kept UI-specific docs drift within a few slices. README lives next to the code, so drift shows up in the same diff.
- **Queued as the next slice:** in-app **empty-state hints** (the half of the critic's alternative that reaches the user at the moment of need) — a small Flutter slice.
- VitePress scaffold removed (never committed). Notes retained if a docs site is ever revisited: keep it **in-repo** (don't split the repo); add CI `paths` filters + a `pnpm docs:build` job; `cleanUrls` needs Caddy `try_files`.
**Principle:** Documentation follows the "disposable CRM, learning is the goal" premise — favour the lowest-maintenance surface that lives next to the code (README + in-app copy) over a parallel product; describe capabilities, not UI trivia, so docs don't rot; prototype → critics → decide.

## Decision 22: Adopt the LMS-Plus agent fleet as a framework — build 2 reviewers now, earn the rest (2026-07-10)
**Context:** Issue #6 — port LMS Plus's 10-agent reviewer fleet (`.claude/agents/`), Flutter-adapted. Decisions 6/7/15 deliberately shipped none of it (inherit principles, earn each agent as the project grows). This is a proven AI workflow the user runs on LMS Plus. Planned the wiring, then ran **2 adversarial critics** (wiring-logic + Flutter/Supabase technical accuracy) — both returned REVISE and caught real defects that were folded in before building.
**Decided — the two-layer principle (copied from LMS Plus):** mechanical gates stay in the deterministic `.githooks/` (format+analyze, commit-msg, secret-scan); **judgement reviewers are Claude subagents (Agent tool), invoked at a workflow moment, findings flow into the chat — advisory.** No Claude subagent blocks a `git push` here (no Node to wire one into a hook, and the human approval step in `/fullpush` is the real gate). This is the one honest divergence from LMS Plus, which runs its security-auditor as a blocking pre-push hook.
**Built now (issue #6 acceptance minimum):**
- **`plan-critic`** — reads a plan before user approval (workflow step 3), pokes holes (wrong Dart signatures/model fields, missed callers incl. **test fakes**, wrong defaults, pattern violations, DB-security-surface gaps). Keeps the "CREATE OR REPLACE chain" false-positive guard (our RPCs use `drop … ; create or replace …` to change signatures — correct, not breaking). **Supersedes** the ad-hoc "run critics before approval" hand-habit (adds a persisted checklist + memory). Model: inherits session.
- **`db-security-reviewer`** — runs **inside `/fullpush`, before `/crlocal`**, fired by the same deterministic `backend/migrations/**/*.sql` trigger `/fullpush` already uses; **advisory**. **Phase-aware:** auth (GoTrue) is NOT wired (issue #3), so a missing `auth.uid()` owner check is **INFO/tracked-#3, never CRITICAL** (the critics caught that the naive checklist would have blocked every pre-auth push). Checklist grounded in `docs/database.md` + the real migrations: RLS-present (NOT `FORCE` — unused here and would break the SECURITY-DEFINER soft-delete bypass), `SET search_path`, **`revoke execute … from public`** (issue #3's actionable-today check — the highest-value item, was missing), soft-vs-hard delete. Secrets + "no raw pg from client" dropped (covered by the pre-push hook / cloud CR / architecture). **Model pinned to `opus`** — it's the security reviewer; don't let quality silently inherit a cheaper session model.
- **Framework:** `.claude/agents/` + committed `.claude/agent-memory/<agent>/MEMORY.md` pattern-trackers; `/wrapup` step 4 extended to curate them.
**Two explicit scope decisions (surfaced, not buried):**
1. **Port 2 now, adopt the other 8 on recurrence (≥2×)** — same earn-rule as the git hooks. In a solo low-volume learning repo that trigger may rarely trip, and 3 of the 8 (`semantic-reviewer`, `code-reviewer`, `doc-updater`) will likely **fold into existing gates** (`/crlocal`, cloud CodeRabbit, `/wrapup`) rather than become standalone agents. This narrows the issue's "full fleet eventually" — a deliberate call, not under-delivery. The full 10-agent wiring table lives in the session plan and the agent files.
2. **Agent memory is committed** (curated pattern trackers, not secret dumps; `.md` skips the Dart-only pre-commit hook), curated at `/wrapup`. Per-run raw findings stay in the chat and are dispositioned via `/wrapup` FIX/DEFER/SKIP.
**Refines:** Decisions 6/7/15 (earn the ceremony) — this adopts the fleet *as* an earned, reviewed, documented framework.
**Principle:** Two layers — deterministic hooks for mechanical truth, advisory Claude reviewers for judgement; adopt a proven workflow as a reviewed framework, build only what the next slice uses, keep every reviewer honest about what it does and doesn't gate.

**Revised 2026-07-11 — port the FULL fleet now (the "build 2, earn 8" scope above is reversed):**
The user directed (explicitly, twice) that this is a **proven workflow to adopt whole, not a
ceremony to earn piecemeal** — so all 10 agents are built now, not just the acceptance-minimum 2.
The original earn-the-rest rationale is kept above for the record; the reversal's reasoning: a
proven fleet is ported as a coherent system (the reviewers reference each other + shared rules),
and the "3 will fold into existing gates" prediction was my framing, not the user's. Planned via
`/plan` + **3 `plan-critic` rounds** (dogfooding the built agent; round 1 APPROVED w/ 4 suggestions,
round 2 caught 2 consistency gaps, round 3 clean).
- **The 10 = 2 already built + 8 new.** `security-auditor`'s role **is** `db-security-reviewer`
  (the phase-aware, `/fullpush`-wired security gate) — not a separate agent. New: `implementation-critic`,
  `semantic-reviewer`, `code-reviewer`, `red-team`, `learner`, `doc-updater`, `test-writer`,
  `coderabbit-sync`.
- **Wiring** (full pipeline in `.claude/rules/agent-workflow.md`): plan-critic (plan time) ·
  implementation-critic (pre-commit) · post-commit parallel code-reviewer/semantic-reviewer/
  doc-updater/test-writer → learner → conditional red-team (migrations/auth) + coderabbit-sync
  (rule/config files) · db-security-reviewer (pre-push). A new bash **`.githooks/post-commit`**
  nudges the post-commit batch (no Node; LMS's reminder-banner equivalent). Memory format in
  `.claude/rules/agent-memory.md`. **`/wrapup` gains an Agent-pipeline check** — a per-commit list of
  which reviewers ran (+ ceiling-escalations) and the disposition of `learner`'s proposals — plus
  fleet-memory curation, so end-of-session verifies the fleet actually ran. (Two critics trimmed it
  from 6 audit items to 2: the rest were redundant with the findings/memory sections or unverifiable
  rubber-stamps.)
- **Model tiers:** db-security-reviewer = opus (gates); doc-updater + coderabbit-sync = haiku; the
  rest inherit the session model. `coderabbit-sync` has no memory; `red-team` keeps a protected
  `topics/attack-surface.md` matrix.
- **Deferred (not this slice):** promoting db-security-reviewer to a headless *blocking* pre-push
  hook (LMS's one mechanical agent gate) — revisit when auth lands (#3); pre-auth there's nothing
  to hard-block. And a `review-gate` edit-blocking equivalent (protocol suffices for now).
**Revised principle:** Adopt a proven multi-agent workflow **whole** — port the system, not a
subset — but keep it Flutter-honest (phase-aware, no cargo-culted TS/Next rules) and advisory
(the human `/fullpush` approval remains the only real gate).

## Decision 23: Event comments — viewable soft-delete (2026-07-11)
**Context:** Adding comments on events so users can track metadata / decisions / follow-ups. Single-user, no author yet (auth lands later with issue #3). Comments should stay readable even when archived — the UI shows a "Show archived" toggle to reveal them.
**Decided:**
- **Viewable soft-delete:** Unlike every other soft-deletable table, `event_comments`' SELECT policy is `using (true)`, NOT `using (deleted_at is null)`. Archived rows (`deleted_at IS NOT NULL`) stay READABLE so the app can surface them under a toggle.
- **No soft-delete RPC needed.** The normal pattern for soft-delete is a SECURITY DEFINER RPC (like `soft_delete_contact` / `soft_delete_event_type`) because a direct UPDATE of `deleted_at` fails PostgREST's RETURNING re-check against `using (deleted_at is null)` (42501 — row is gone after the mutation, so it can't pass the SELECT policy). Here, the SELECT policy is `using (true)`, so an archived row *survives* the re-check → **archive / unarchive / edit are all plain direct UPDATEs**, no RPC overhead. This is the *only* table with this SELECT-always policy; it is a deliberate, documented exception (database.md #4 amendment).
- **Why safe:** Because archived comments stay readable, the UI's visibility is unconditional (no "you've hidden this row" surprise). The `deleted_at` column is never written by the client directly (only via the repository's `archive` / `unarchive` helpers). The repository fetches by `event_id`, but that filter is **organizational, not an access boundary** — pre-auth, `select using (true)` lets anon read any comment via direct PostgREST, exactly the anon-permissive posture the other tables have. Owner/event-scoped access control lands with auth (issue #3).
- **Implementation:** `event_comments` table (id, event_id FK, body, created_at, updated_at, deleted_at) under RLS. Single migration, direct-CRUD repository (CommentsRepository), self-contained UI section (_CommentsSection) on event detail. Comment model reads `deleted_at` back (unlike other models) so the UI can distinguish archived.
**Principle:** Soft-delete is a convention with documented exceptions — this table's exception is justified by its read-always-archived design.

---

## OPEN QUESTIONS
- [x] Backend hosting: **self-host trimmed on homebase** (vs Supabase cloud). Settled 2026-07-07; revisit only if homebase load becomes a problem.
- [x] First walking-skeleton slice entity: **`contacts`** (name, dob, email, phone, company, remarks). Settled 2026-07-08 — Slice 1.

## IDEAS / NOTES
- The `okpilot/selfhost` repo on homebase is where the backend stack (a new `stacks/` dir + a Caddy route) will live, committed like the others.
- **Styling / theming (for the first styling slice — not yet):** Flutter needs no shadcn-style component library — Material 3 is built in. Default plan: stock Material 3 + `ColorScheme.fromSeed(seedColor: …)` (one seed → full light+dark palette). References to reach for when we theme: **Material Theme Builder** (https://material-foundation.github.io/material-theme-builder/ — visual editor, exports `ThemeData`); **`flex_color_scheme`** pub package (dozens of polished pre-made themes); **`shadcn_ui`** / **`forui`** packages if we ever want the specific flat shadcn aesthetic. Decide emergently when a slice calls for it.
