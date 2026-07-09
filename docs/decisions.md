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

---

## OPEN QUESTIONS
- [x] Backend hosting: **self-host trimmed on homebase** (vs Supabase cloud). Settled 2026-07-07; revisit only if homebase load becomes a problem.
- [x] First walking-skeleton slice entity: **`contacts`** (name, dob, email, phone, company, remarks). Settled 2026-07-08 — Slice 1.

## IDEAS / NOTES
- The `okpilot/selfhost` repo on homebase is where the backend stack (a new `stacks/` dir + a Caddy route) will live, committed like the others.
- **Styling / theming (for the first styling slice — not yet):** Flutter needs no shadcn-style component library — Material 3 is built in. Default plan: stock Material 3 + `ColorScheme.fromSeed(seedColor: …)` (one seed → full light+dark palette). References to reach for when we theme: **Material Theme Builder** (https://material-foundation.github.io/material-theme-builder/ — visual editor, exports `ThemeData`); **`flex_color_scheme`** pub package (dozens of polished pre-made themes); **`shadcn_ui`** / **`forui`** packages if we ever want the specific flat shadcn aesthetic. Decide emergently when a slice calls for it.
