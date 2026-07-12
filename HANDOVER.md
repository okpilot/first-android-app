> Cross-session work tracker. Update in place. Last updated: 2026-07-12 (RPC-for-all-writes COMPLETE — Slice 3 (event_comments) MERGED (PR #29 → `1e7574d`) & DEPLOYED; Decision 26 done, 4/4 entities on RPC writes. Resume = phone QA, then pick a backlog item (#21 or #3/auth)).

# Handover

**Status: RPC-FOR-ALL-WRITES (Decision 26) — ✅ COMPLETE & DEPLOYED. All four entities (events, contacts, event_types, event_comments) write via SECURITY DEFINER RPCs; reads stay direct. Slices 0–3 merged, deployed & verified live on homebase. Only phone QA of the RPC write paths remains owed; then the backlog (#21 empty-state hints, #3 auth/hardening, …).**
Standardizing every write (INSERT/UPDATE/soft-delete) onto PostgREST RPCs; reads stay direct `select`. Triggered by root-causing the event-comment 404 as a **PostgREST stale-schema-cache** bug (Decision 25 — the deploy script now reloads PostgREST; live-remediated, comments work on the phone). Full approved plan: `~/.local/share/claude-config/claude/plans/stuck-lazy-sutton.md`. Also persisted as project memory `rpc-writes-migration.md`.
- ✅ **Slice 0 — DDL-watch triggers DEPLOYED & VERIFIED, MERGED** (`670787c`, PR #25 + follow-up PR #26 → `2e366d7`): `pgrst_watch()` + `pgrst_ddl_watch`/`pgrst_drop_watch` auto-reload PostgREST on any DDL. Deployed to homebase; verified live (create+drop test objects callable via `/rpc/` with no manual NOTIFY); triggers own running/steady-state + ad-hoc case; deploy script keeps a single unconditional `notify pgrst` as fresh-DB cold-start net (Decision 25 amended 2026-07-12; `CREATE EVENT TRIGGER`+ledger `INSERT` fire no NOTIFY, so a from-scratch deploy needs it). `main` clean & synced.
- ✅ **Slice 1 — contacts writes → RPC — MERGED (PR #27 → squash `2370fcf`) & DEPLOYED** (branch `feat/contacts-write-rpcs` deleted): migration `20260712130000_contact_write_rpcs.sql` adds `create_contact` / `update_contact` SECURITY DEFINER RPCs (server-side trim + nullif normalization, update guards deleted_at + raises no_data_found, grants to anon+authenticated); `Contact.toRpcParams()` replaces `toWrite()` (+`_emptyToNull` removed); `contacts_repository` routed to RPCs + `_fetchOne` refetch; `docs/database.md` rule #2 re-reversed (Decision 26 dated); `.coderabbit.yaml` SQL rule + a new CLAUDE.md rule-reversal-sync workflow line (learner, count 2); `backend/README.md` verify curls; `event_types_repository.dart` doc-comment patched. **71 tests green, all migrations on fresh postgres:16, RPCs exercised as anon.** Fleet all clean (db-security PASS). Cloud CR cycle 1 answered: 1 finding (`revoke execute from public`) → **DEFER → #3** (standing project-wide gap; triage+reply on #27). **Deployed to homebase** (ledger 11 → **12**); RPC verified live via the DDL-watch auto-reload (blank-name `create_contact` → 400 check violation, NO manual NOTIFY — Slice 0 paying off).
- ✅ **Slice 2 — event_types writes → RPC — MERGED (PR #28 → squash `a17ea81`) & DEPLOYED** (branch `feat/event-types-write-rpcs` deleted): migration `20260712140000_event_type_write_rpcs.sql` adds `create_event_type` / `update_event_type` SECURITY DEFINER RPCs (server-side `trim(p_name)`, update guards deleted_at + raises no_data_found, grants to anon+authenticated); `EventType.toRpcParams()` replaces `toWrite()`; `event_types_repository` routed to RPCs + `_fetchOne` refetch; `database.md` rule #2 now lists event_types as converted (only event_comments remains); the two stale event_types migration headers corrected in-slice; `backend/README.md` verify curls (incl. malformed-colour→400); `.coderabbit.yaml` SQL rule names the event_comments exception. **73 tests green, all 13 migrations on fresh postgres:16, RPCs exercised.** Full fleet clean (db-security DEFERRABLE — 1 INFO #3 revoke gap). `/crlocal` converged 3 rounds (1 apply, 1 skip, 1 DEFER→#9 = two-phase write retry window, now project-wide across all `create_*`). Cloud CR cycle 1 answered: 1 finding (misleading `#3` tag on the yaml exception) → **FIX `7b38ea8`**; triage+reply on #28. **Deployed to homebase** (ledger → **13**); RPC verified live via DDL-watch auto-reload (blank-name `create_event_type` → 400, no manual NOTIFY).
- ✅ **Slice 3 — event_comments writes → RPC — MERGED (PR #29 → squash `1e7574d`) & DEPLOYED** (branch `feat/comment-write-rpcs` deleted): migration `20260712150000_comment_write_rpcs.sql` adds `create_comment(p_event_id,p_body)` / `update_comment(p_id,p_body)` **body-only** / `soft_delete_comment(p_id)` (archive) / `restore_comment(p_id)` (unarchive — new inverse op) SECURITY DEFINER RPCs. **For uniformity, NOT to dodge 42501** (comments' `using(true)` SELECT has no RETURNING re-check — documented in-header). `Comment.toRpcParams()` replaces `toWrite()`; `comments_repository` → `.rpc()` + `_fetchOne`; interface unchanged (UI + fakes untouched). **The reversal (first real test of the promoted rule-reversal-sync rule):** `database.md` rule #2 (migration complete) + rule #4 (now a reads-only exception); **Decision 23 amended in-place** (dated, twice — main bullet + Implementation subsection, + a later precision note on the direct-write claim); `create_event_comments.sql` header; `.coderabbit.yaml` exception removed; `backend/README.md` both surfaces + full RPC verify curls. **73 tests, all 14 migrations on fresh postgres:16, 4 RPCs round-trip + guards fire + updated_at trigger empirically confirmed.** Full fleet clean (plan-critic 2 ISSUE folded; db-security CLEAN, 1 INFO #3). `/crlocal` 3 rounds (1 apply, 1 skip, 1 DEFER→#3). Cloud CR: 2 findings → **1 FIX `976107e`** (Decision 23 direct-write precision) + **1 SKIP** (updated_at trigger false positive); triage+reply on #29. **Deployed to homebase** (ledger → **14**); all 4 RPCs verified live via DDL-watch auto-reload (FK-violation / P0002 raises prove registration, no manual NOTIFY).
- 📱 **RESUME = Phone QA of the Slice 1–3 RPC write paths** (add/edit a contact + an event type + a comment against homebase via `/updatephone` → S23+) — deferred across all three slices. Then pick a backlog item: **#21** (in-app empty-state hints — easy visible win) or **#3** (auth/GoTrue + DB hardening — the big one; most of this migration's deferrals point here).
- 🔎 **Noted (not filed):** the `no_data_found` raises in the update/soft_delete/restore RPCs surface as **HTTP 500** via PostgREST (consistent across contact/event_type/comment update RPCs, not a Slice 3 regression; app catches + snackbars). Candidate follow-up: map `no_data_found` → a 4xx uniformly.
- Also open: **issue #23** (error handling — `catch (_)` discards exceptions; log them). **issue #21** (in-app empty-state hints) still queued for after this.

---

**Previous: APP IDENTITY — launcher `CRM+` + dark `C⁺` icon (Decision 24) — SHIPPED & MERGED (PR #22 → squash `343bcdc`).**
Renamed `android:label` `first_android_app` → **`CRM+`**; generated all mipmap densities + a modern adaptive icon via `flutter_launcher_icons` from the user's dark `C⁺` mark (dark chosen over light). Reproducible sources (2 SVG + 2 PNG) committed under `assets/icon/`: legacy `image_path` = the full designed tile; adaptive foreground = a clean **transparent glyph** on a `#0a0a0a` background (the opaque tile makes a bad adaptive foreground — its border/rounded corners read as a card-outline under the mask); `adaptive_icon_foreground_inset: 0` in the config so the C⁺ matches the legacy framing (still inside the 72dp safe circle). Android-only (iOS/web/Linux untouched). SVG→PNG via a throwaway `cairosvg` venv (no system SVG tools on the box). Commits **`0e312f9`** (feat) + **`1fff1ee`** (cloud-CR fix). Gate green (analyze · **69 tests** · web build); `/crlocal` 2 clean rounds. **Cloud-CR cycle 1 answered:** 1 finding → **1 FIX** (`1fff1ee`, config-driven inset); triage + reply comments on #22.
**✅ On-device QA PASSED** — installed on the S23+ via `/updatephone` (`8c52f81`, debug APK vs homebase); the dark C⁺ icon + `CRM+` name verified on the launcher in light + dark, glyph size good. Branch deleted (local + remote); `main` clean & synced. Process note: `implementation-critic` ran on `0e312f9` (APPROVED, its 1 inset suggestion fixed) but was **not** re-run on the trivial CR-fix `1fff1ee`, and `/crlocal` was skipped on the final pushes at the user's "just push directly" — all stated deviations.
**RESUME = the queued in-app empty-state hints slice — issue #21** (Decision 21) — contextual hint text on the empty Contacts / Calendar / comments states, no new table. (App-icon slice fully done: shipped, merged & QA'd.)

---

**Previous: EVENT COMMENTS — SHIPPED, MERGED (PR #20 → squash `1c89b64`) & DEPLOYED to homebase.**
Add / inline-edit / archive / toggle-archived / unarchive on events. Single-table, direct-CRUD under RLS (no RPC); SELECT policy `using (true)` so archived comments stay readable (Decision 23, database.md #4 amendment). Comment model reads `deleted_at` back; CommentsRepository direct CRUD (edit is body-only); self-contained _CommentsSection on event detail. 69 tests green; curl-verified (insert/edit/archive/unarchive 200, archived SELECTable, empty body 400, anon DELETE 401); emulator visual QA light+dark. PR #20 squash-merged to `main`; branch deleted (local + remote); `main` clean & synced.
**✅ Deployed to homebase** — `20260711120000_create_event_comments.sql` applied via `deploy-homebase.sh` (ledger 9 → **10**); verified live: `GET /rest/v1/event_comments` → `200 []`. The S23+ can now use comments.
**Session 12 recap — `/coderabbit` cycle 1 on PR #20:** 6 cloud findings → **3 FIX** (doc/memory-accuracy `d0aa1f1`: plan.md 63→69 tests + branch-ready wording; code-reviewer memory async-safety; learner memory `discarded_futures` now-enabled) · **1 DEFER → #10** (duplicate inert `_FakeCommentsRepo`) · **2 SKIP** (already resolved). Then squash-merged. **`/replycoderabbit` was explicitly skipped by the user** — the 6 findings stay triaged+dispositioned on (now-merged) PR #20 but the reply was never posted. Also added `*.zip` to `.gitignore` (a stray logo zip had been swept into a commit and amended out).
**RESUME = start the queued in-app empty-state hints slice — issue #21** (Decision 21) — contextual hint text on the empty Contacts / Calendar / comments states, no new table. (Event comments fully shipped + deployed; nothing owed.)

**Previous: AGENT FLEET (issue #6) — SHIPPED & MERGED (PR #18 → squash `fba34f6`).**
Full **10-agent LMS-Plus reviewer fleet** ported to this project, Flutter-adapted (Decision 22,
revised 2026-07-11 from "build 2, earn 8" → **full port**). PR #18 **squash-merged to `main`**
(`fba34f6`, 7 commits collapsed); branch deleted (local + remote), stale ref pruned; `main` clean
& synced. Gate was green (analyze · **52 tests** · web build); the fleet's CR-local converged over
**4 rounds (26 findings)**; the `/wrapup` change got **2 adversarial critics + 2 clean CR-local rounds**.
**Cloud CodeRabbit cycle 1 answered:** 9 findings → **8 fixed** (`f80bc5e` + polish `870ba1d`),
**1 deferred → #3** (SECURITY DEFINER `search_path` → `pg_temp` hardening); triage + reply comments
on #18. (Cloud CR's final review sat at `060f099`, 5 commits behind the merge — never re-reviewed
the fixes, but every finding was disposed against current source before merging.)
**RESUME = build the queued next slice: in-app empty-state hints** (small Flutter slice, Decision 21).
red-team curl recs → **#19**; DB `search_path` hardening → **#3**.

- **10 agents** in `.claude/agents/` (phase-aware, advisory): plan-critic, db-security-reviewer
  (= the `security-auditor` role), implementation-critic, semantic-reviewer, code-reviewer, red-team,
  learner, doc-updater, test-writer, coderabbit-sync. Shared rules `.claude/rules/agent-workflow.md`
  + `agent-memory.md`; wiring via a bash `.githooks/post-commit` nudge + a CLAUDE.md fleet section;
  `/wrapup` gained an Agent-pipeline check. Built via `/plan` + 3 `plan-critic` rounds (dogfood) +
  8 parallel authors + a consistency review + 5 reviewer smoke-tests. The fleet caught a real
  day-one `.coderabbit.yaml` drift (unconditional `auth.uid()`), fixed in the PR.
- **Follow-ups filed this session:** **#19** (red-team's two `backend/README.md` curl checks —
  soft-delete persistence via a privileged read + soft-deleted-type → embed-null); **#3** commented
  (the `search_path` → `pg_temp` hardening, deferred from the cloud review).

**Status: EVENT TYPES (colour-as-data, Decision 19) — SHIPPED, MERGED & DEPLOYED (Slices 1–3).**
PRs **#13 → #14 → #15** all squash-merged to `main` in order (`9873585` / `44c230a` / `9a0ca28`);
all **4** event-types migrations applied to homebase via `deploy-homebase.sh` (ledger at **9**;
`create_event` now carries `p_type_id`). Cloud CodeRabbit answered on every PR. `main` clean & synced.

**Cloud-CR tooling split — PR #16 MERGED** (squash → `c2a3fc6`, `chore/coderabbit-commands` deleted,
Decision 20). Replaced the single over-merged `/replycoderabbit` with **`/coderabbit`** (triage) +
**`/replycoderabbit`** (reply-only) + shared **`scripts/cr-findings.sh`** (36-assertion fixture test).
Designed via **3 adversarial critic rounds** + hardened via **3 `/crlocal` rounds** pre-push, then the
first live **dogfood** of `/coderabbit → /fullpush → /replycoderabbit` on the PR itself surfaced (and
FIX-NOW'd) two real bugs in the new commands: **round 1** — 5 cloud-CR findings (`170f363`: invalid
`gh api --jq --arg`, colon-unsafe crfinding payload, silent-drop of unmapped inline findings, crreply
author-scoping, exact-id-formula doc); **round 2** (self-found while replying) — the marker lookups
used an unanchored `test("<!-- crtriage -->")`, so a finding that *quotes* a marker matched the wrong
comment (`5468f0f`: anchored all three lookups to `^`). No cloud re-review triggered → merged.

- **Slice 1 (#13):** `event_types` table (RLS, `#RRGGBB` CHECK, soft-delete) + nullable
  `events.type_id` FK + pure-Dart `EventType` model + `event_types(...)` read embed. **Linchpin
  curl-verified:** the top-level to-one embed returns `null` (not error/hidden row) after a type
  is soft-deleted → non-destructive delete works via RLS alone. gate-green · 38 tests.
- **Slice 2 (#14):** `soft_delete_event_type` RPC + `EventTypesRepository` + a 3rd **Settings**
  nav destination → **Event types** manager (empty state, swatch+name list) → editor (name +
  keyboard-operable 8-swatch grid + non-destructive Delete). `event_type_palette` (8 named
  swatches — slate dropped — + `colorFromHex`/`hexFromColor` alpha-strip). **Emulator visual QA
  light+dark** (create/edit/delete round-trip). gate-green · 45 tests.
- **Slice 3 (#15):** `p_type_id uuid default null` on `create_event`/`update_event` (drop+recreate
  +regrant + `notify pgrst, 'reload schema'`) + `Event.toRpcParams`. Event-form **Type picker**
  (pick-existing-only sheet: types + No type + "Manage types…"; inline create deferred).
  **Colour-as-data:** retired `EventBlockStyle.rail`; `tintForType` (HSL-lighten + `alphaBlend`
  on dark); full-area **tinted** Day/3-day blocks + all-day band (no rail, neutral hairline, type
  name in Semantics); shared **`TypeLabel`** atom (dot + name) in Agenda/panel/detail; coloured
  Month **density dots + "+N"** (no-type → neutral ink; out-of-month grey). analyze clean · **48
  tests** · migrations clean on a fresh DB · end-to-end curl (typed create/update + soft-delete
  linchpin → embed null) · **emulator visual QA light+dark, every surface**.
- **DEPLOYED to homebase** — all 4 event-types migrations (`20260710120000/120100/120200/120300`)
  applied via `backend/deploy-homebase.sh`; ledger at **9**, `create_event` carries `p_type_id`,
  PostgREST schema reloaded. (Homebase stack has been live for the whole feature.)

**RESUME = build the queued next slice (in-app empty-state hints).** The docs detour is done and
**merged**. This session was a docs-only detour: explored a docs page, briefly built then **dropped**
a separate VitePress docs site (3 adversarial critics → **Decision 21**), and instead added a
**capability-level Features section to `README.md`**, synced HANDOVER/plan, and added the
**`/updatephone`** command. **PR #17** (`docs/readme-features`) is **MERGED** (squash → `8d8d69e`,
branch deleted). Cloud CodeRabbit raised 3 minor doc findings on a later review — 2 fixed (`7354faf`:
plan decision count 20→21; this HANDOVER's MD018 heading reflow), 1 skipped (next-slice pointer
already aligned); triage + reply posted on the PR. Next slice, queued by Decision 21: in-app
**empty-state hints** (small Flutter slice). Standing candidates unchanged: **auth (GoTrue)** +
owner-based RLS (unblocks the DB-hardening issue #3), or search/filter on Contacts.

_Open follow-up issues: **#3** (DB security hardening — also covers `event_types` write-hardening +
the `soft_delete_event_type` `auth.uid()` check) · **#6** (agent fleet) · **#7** (Tailscale db-deploy
action) · **#9** (idempotent event RPCs) · **#10** (dedup test fakes) · **#12** (signed Android release)._

_(Merged this session: PR #16 — the `/coderabbit` + `/replycoderabbit` split (`c2a3fc6`). Earlier: the
PRs #13/#14/#15 event-types stack + homebase migrations. Calendar events #8 → `6f14d66`;
deploy fix #11 → `5947599`; Calendar shell #4 → `7dd0995`; `/replycoderabbit` #5 → `4e210e2`;
Contacts #2 → `fa4fc45`. The app also runs on the physical **S23+** against homebase.)_

## How to bring the dev env back up (next session)
1. **Backend:** `cd backend && docker compose up -d` (data persists; `down -v` to re-seed).
   Health: `curl -s -H "apikey: $(grep SUPABASE_ANON_KEY .env|cut -d= -f2)" -H "Authorization: Bearer $(grep SUPABASE_ANON_KEY .env|cut -d= -f2)" http://127.0.0.1:8000/rest/v1/contacts?select=name`
   (If `backend/.env` / `dev-defines*.json` are missing, run `bash backend/gen-env.sh`.)
2. **Android env (not persisted in PATH):** `source ~/.android-env` in each shell. Then:
   - Emulator (windowed): `DISPLAY=:0 $ANDROID_HOME/emulator/emulator -avd pixel_api35 -gpu swiftshader_indirect &`
   - `adb reverse tcp:8000 tcp:8000` (device→host tunnel; re-set after every emulator restart)
   - Run: `~/flutter/bin/flutter build apk --debug --dart-define-from-file=dev-defines.android.json && adb install -r build/app/outputs/flutter-apk/app-debug.apk && adb shell am start -n com.example.first_android_app/.MainActivity`
   - (`flutter run` can't attach its VM service inside this emulator — build+install+`am start` is the reliable path.)
3. **Web:** `~/flutter/bin/flutter run -d chrome --dart-define-from-file=dev-defines.json`
   (config now uses `127.0.0.1`, not `localhost`, to dodge the IPv6 `::1` issue.)

## Done this run (2026-07-08, session 2)
- ✅ **Adopted UI/UX principle docs** — lighter than first planned (2 critics said over-adopted): moved both encyclopedias into `docs/`, bound only the thin wrapper `docs/design-principles.md`; advisory-not-a-gate. Decision 9. Committed `f431822`.
- ✅ **Local dev backend** (`backend/`): Postgres + PostgREST + Caddy gateway (Supabase-shaped), `contacts` table + RLS + `soft_delete_contact` RPC + `updated_at` trigger + seed. All CRUD verified via curl. Decision 10.
- ✅ **Android SDK installed** portably (no sudo): JDK 17 `~/jdks`, SDK `~/Android/Sdk`, env `~/.android-env`; `android/` platform added; Pixel AVD `pixel_api35`. Decision 11.
- ✅ **Contacts feature** (Decision 12): injectable repository (`SupabaseContactsRepository` + fake for tests), list/detail/add-edit screens, loading/empty/error states, guarded soft-delete, date picker. Stock M3 (bespoke theme deferred).
- ✅ Runs end-to-end on the Android emulator (verified via `adb screencap` — 4 contacts load from Postgres). Local gate green (analyze + 5 tests + web build).
- 🐛 Bugs found & fixed: `setState`-returns-Future (caught by tests); `publishableKey` vs legacy anon JWT; **debug manifest clobbered Flutter's `INTERNET` permission** (the "Operation not permitted" fetch failures); `.order()` defaulted to desc.

## Loose ends / deferred
- ✅ **PR #2 merged** (squash → `fa4fc45`, 2026-07-08); branch deleted local + remote.
- 🎨 **Theme (Decision 13) + git hooks (Decision 15) DONE.** Hooks: `.githooks/` — run `scripts/setup-hooks.sh` after a fresh clone to activate (`core.hooksPath`).
- 🔒 **DB security hardening — DEFERRED, tracked in issue #3** (cloud CR + local CR): (a) `soft_delete_contact` needs an `auth.uid()` ownership check; (b) `revoke execute … from public` before granting the RPC; (c) column-level write grants so anon can't write `created_at/updated_at/deleted_at`. All pair naturally with the **auth (GoTrue)** slice. New forward-only migrations + re-run `deploy-homebase.sh`.
- ✅ **homebase deploy DONE** (Decision 14): `selfhost/stacks/firstapp-crm/` running, API at `https://homebase.tail7ab4bc.ts.net:8452` (tailnet-only, Tailscale TLS), started empty. Schema applied via `backend/deploy-homebase.sh` (migrator over the tailnet; source of truth = `backend/migrations/`). App config: gitignored `dev-defines.homebase.json`.
  - ⚠️ **selfhost commit `ff5513f` is UNPUSHED** — `git push` from a non-interactive SSH couldn't auth to GitHub. Finish with: `ssh king@homebase 'cd ~/selfhost && git push origin main'` from your terminal.
  - To run the app against homebase: the **emulator can't reach the tailnet**; use the real **S23+ with the Tailscale app** (`flutter build apk --dart-define-from-file=dev-defines.homebase.json` → `adb install`). Local dev still uses `dev-defines.android.json` (10.0.2.2 / adb reverse).
- ⏸️ **Auth (GoTrue) deferred** to the first per-user slice; RLS policies are anon-permissive for now (tighten to owner-based then).
- ✅ Bespoke mono/Linear-Attio **theme** DONE (Decision 13, `lib/theme.dart`, light+dark, one 3-weight type scale). **adaptive/two-pane** wide layout still a candidate next slice.
- ⚠️ `flutter build linux` may still choke on the spaces in the absolute path (CMake/ninja) — untested; flag if we target Linux desktop.
- 🧹 Stray background `flutter run -d web-server` processes may linger from debugging (failed to bind :8080); harmless, `pkill -f "flutter run"` to clear.

## Done this run (2026-07-08, session 3)
- ✅ **Bespoke mono/Linear-Attio theme** (D13) + unified 3-weight type scale after a typography QA (`lib/theme.dart`, `lib/util/format.dart`).
- ✅ **S23+ emulator profile** (`galaxy_s23plus` AVD, 1080×2340).
- ✅ **Backend deployed to homebase** (D14) — `selfhost/stacks/firstapp-crm/` + `backend/deploy-homebase.sh`.
- ✅ **Mechanical git hooks** (D15) — `.githooks/` (format/analyze, conventional commits, secret scan).
- ✅ **Push & consolidate**: renamed branch, `/fullpush`, `/crlocal` (4 rounds → 16 fixed, 1 deferred), opened **PR #2**; disposed cloud CR's 8 findings (4 fixed, 3 → hardening issue, 1 skipped false-positive).

## Done this run (2026-07-08, session 4)
- ✅ **Squash-merged PR #2** into `main` (`fa4fc45`); deleted branch (local + remote), pruned stale refs; `main` clean and synced.
- ✅ Synced `docs/plan.md` + `HANDOVER.md` to merged state; DB hardening now points at **issue #3**.

## Done this run (2026-07-09, session 5) — Calendar shell
- ✅ **Prototyped the calendar** in a throwaway interactive artifact; aligned to the mono theme; chose views **Month · 3-day · Day · Agenda** (phone-first; full 7-col week deferred to a wide-screen slice). Decision 16.
- ✅ **Plan through 3 adversarial critics** (scope/YAGNI, Flutter correctness, design/UX) before build; fixes folded in (DST-safe date math, no `pumpAndSettle` timer, AA-safe dimming, `find.text('Contacts')` test fix, TabBar over SegmentedButton, …).
- ✅ **Built the calendar shell** — `HomeShell` (adaptive `NavigationBar`↔`NavigationRail`), `CalendarScreen` (TabBar + 4 views), `lib/util/calendar.dart` (pure, no `intl`), shared `EmptyState`. **No events** (chrome only). analyze clean · **18 tests** · web build.
- ✅ **Visual QA vs the artifact** (light + dark, emulator + web) caught & fixed: loose grid → hairline grid, left-packed tabs → even, floating nav → grouped, empty-state collisions → contained chips, Day header redundancy removed.
- ✅ **`/fullpush` + `/crlocal`** (2 rounds → 2 correctness fixes: Month↔timeline `_focused` sync, timeline width via `LayoutBuilder`).
- ✅ **PR #4 opened**; CI `build` green + cloud CodeRabbit reviewed → **1 minor finding fixed** (hide period nav on Agenda). Awaiting merge.
- ⏭️ **Deferred (stated):** full 7-column week (wide-screen adaptive), Drawer ≥1200 dp, keyboard grid traversal, now-line visual confirm (hidden behind empty chip until events).

## Done this run (2026-07-09, session 6) — Calendar events + attendees
- ✅ **Prototyped** the events flow in a throwaway artifact; confirmed field set (title · all-day · date · start/end · location · attendees · notes) and two entry points (FAB + tap-empty-slot) with the user.
- ✅ **Plan through 3 adversarial critics** (scope/YAGNI · correctness · design/UX) before build; fixes folded in — cross-midnight CHECK limitation documented, `contacts` embed is to-one (+ null-skip), cached fetch future, corrected owner-RLS-bypass rationale, event-block **border** token, stacked-avatar rings, count-aware Semantics, mono switch/time-picker themes.
- ✅ **Backend** (`backend/migrations/2026070912*`): `events` + `event_attendees` + 3 RPCs; RLS SELECT-only for anon (writes via definer RPCs). **curl-verified** create/update/soft-delete, the embed shape, and every CHECK guard (overnight rejected = documented single-day limitation). Seed events added (dev-only, relative to `current_date`).
- ✅ **Dart**: `Event` model (int-minutes, pure), `EventsRepository` (+ Supabase impl), shared `InitialsAvatar`, `EventFormScreen` / `AttendeePickerScreen` / `EventDetailScreen`, and a full **data-driven rewrite of `CalendarScreen`** (lane-packed timeline blocks, all-day band, month dots + panel, agenda). Wired `EventsRepository` through `main`→`app`→`home_shell`.
- ✅ **Time picker forced to 24-hour** (no AM/PM) per user request.
- ✅ **Bugs found & fixed during QA:** `setState(() => …)` arrow returned a Future (crashed init); `Positioned` wrapped in `IgnorePointer` (parent-data assert when today in span); `borderRadius` + non-uniform border (event block + all-day pill) → uniform border + flush rail.
- ✅ analyze clean · **31 tests** (added `event_test`, `event_form_screen_test`, event-driven calendar tests) · web build · **emulator visual QA light+dark**.
- ✅ **`/fullpush` + `/crlocal`** (4 rounds → 6 fixed incl. a critical `update_event` no-op + a major RLS gap on `event_attendees`; 1 skipped = false-positive `int.clamp` typing). Committed + **pushed → PR #8**; CI build green; cloud CR review in progress at session end.
- ✅ **Filed follow-up issues #6 (agent fleet) + #7 (Tailscale db-deploy action)** — user wants both tracked; build after this PR.
- 📝 Notes: `dev-defines.json` still points at `localhost:8000` (IPv6 `::1` fails on **web**; emulator path uses `dev-defines.android.json` + `adb reverse` + `127.0.0.1`). Emulator `hw.keyboard` was flipped to `yes` so the physical keyboard types into fields.

## Done this run (2026-07-09, session 7) — Land + deploy events; fix deploy tooling
- ✅ **Cloud CodeRabbit on PR #8 fully disposed** once its review posted: 8 findings →
  **3 fixed** (`a9170cd`: `mounted` guards after `await` in the form's pickers; a trim-before-save
  test; a reload-failure `_ErrorState` test), **2 deferred** → issues **#9** (idempotent write RPCs)
  + **#10** (dedup test fakes + `_Field` widget), **2 skipped** as false positives (the `int.clamp`
  → `num` claims — `int.clamp(int,int)` is statically `int` since Dart 2.19; CR **conceded** both
  on the thread), **1 nitpick** folded into the fix. Every finding answered inline via
  `/replycoderabbit`.
- ✅ **PR #8 merged** (squash → `6f14d66`); branch deleted (local + remote), `main` synced.
- ✅ **Deployed the 3 event migrations to homebase** and verified live (tables + RLS + RPCs +
  ledger; PostgREST reloaded; `GET /rest/v1/events` → `200 []`). Prod carries **no seed**.
- 🐛 **Found & fixed a real bug in `backend/deploy-homebase.sh`:** its per-migration exists-check
  ran `psql -c "…"` through `ssh → docker exec`, so the space-containing query was **word-split on
  the remote side** and always returned empty — the script re-applied *every* migration and only
  worked on a fresh DB (re-runs failed `relation … already exists`). Fixed to pipe the check over
  **stdin** with `psql -v :'name'` quoting (survives all three hops; robust to odd filenames).
  Landed via **PR #11** (own branch, `/crlocal` clean 2 rounds, cloud CR's 1 nitpick fixed
  `060d2ed` + replied) → merged (squash → `5947599`).
- 📝 Note: homebase deploys may prompt a one-time **Tailscale SSH re-auth**; the deploy is now
  idempotent so a re-run after auth is safe.

## Done this run (2026-07-10, session 8) — Event types Slice 3 (assign + show)
- ✅ **`/plan` through 2 adversarial critics** (correctness/scope · design/a11y) on the code-grounded
  Slice-3 plan; folded fixes: the `pgrst` schema-reload NOTIFY, the drop-vs-`create or replace`
  overload hazard, the repo-threading + test-breakage map, a concrete `tintForType` formula, block
  Semantics carrying the type name, tinted-secondary-text AA, a shared `TypeLabel` atom.
- ✅ **Two user decisions:** Month = **density dots coloured** (not deduped-by-type — it emptied
  no-type days + undercounted); picker = **pick-existing-only** (inline create deferred).
- ✅ **Built** the migration + Dart (see the Slice-3 status bullet above). analyze clean · **48 tests**.
- ✅ **Verified:** all four migrations apply on a fresh throwaway DB; end-to-end curl on local dev
  (typed create/update, null-type, soft-delete → embed null); **emulator visual QA light+dark** on
  Month/panel/Day/detail/form/picker.
- ✅ **`/fullpush`** (analyze · 48 tests · web + debug apk · fresh-DB migrations · `/crlocal`);
  committed `036082e`; **PR #15** (stacked on #14).

## Done this run (2026-07-10, session 9) — Land the event-types stack; build the /coderabbit split
- ✅ **Merged the whole event-types stack** #13 → #14 → #15 (squash) and **deployed all 4 migrations
  to homebase** (ledger 5 → 9; `create_event` gains `p_type_id`). Verified live each time.
- 🩹 **Recovered a stacked-PR foot-gun:** merging #13 with `--delete-branch` auto-closed #14 (its base
  branch vanished). Reopened + retargeted #14 to `main`; thereafter **retarget the next PR's base to
  `main` before merging** (did so for #15 → it survived). Rebased the stack tree-identically each step.
- ✅ **Answered cloud CodeRabbit on #14 & #15** (by hand, the way the new commands will): #14 — 2 dart
  bugs fixed (`_load` stale-guard + refresh-error snackbar) + a Completer ordering test + a coverage
  nitpick, deferrals to #3; #15 — extracted `fillForType` (DRY nitpick). Both merged.
- ✅ **Built the `/coderabbit` + `/replycoderabbit` split** (Decision 20) on `chore/coderabbit-commands`:
  new `coderabbit.md` (triage), reply-only `replycoderabbit.md`, shared `scripts/cr-findings.sh`
  (36-assertion fixture test), wiring into `/wrapup` + `CLAUDE.md`. **3 critic rounds** (9 reports) +
  **3 `/crlocal` rounds** (10→2→2, all fixed; caught a real `--paginate` page-1 bug). `/fullpush`:
  analyze · 52 tests · web build · CR-local (round 4 rate-limited). **PR #16 open, awaiting cloud CR.**
- 🧠 Memory updated: homebase stack is confirmed **deployed** (was "later slice").

## Done this run (2026-07-10, session 10) — Dogfood + land the /coderabbit split (PR #16)
- ✅ **First live run of the new flow on PR #16** itself: `/coderabbit` (triage) → `/fullpush` →
  `/replycoderabbit` (reply). The dogfood found two real bugs in the new commands, both **FIX NOW**:
  - **Round 1 (`170f363`)** — 5 cloud-CR findings, all verified against source & fixed: invalid
    `gh api --jq --arg` (→ `env.ME`); colon-unsafe `crfinding` payload (subjects like `fix: …` truncated
    → split on first two colons only); `cr-findings.sh` silently dropped unmapped inline findings (→ emit
    under a synthetic run + stderr warn); crreply upsert not author-scoped; exact stable-id formula doc.
  - **Round 2 (`5468f0f`, self-found while replying)** — the `crtriage`/`crreply` comment lookups used
    an **unanchored** `test("<!-- crtriage -->")`, so a comment whose *finding description* quotes the
    literal marker matched too — I overwrote the triage comment with the reply once before catching it.
    Anchored all three lookups to `^` (marker is always the body's first line); restored + sanitized the
    triage comment. **This class of bug is exactly what the split exists to catch.**
- ✅ **Triage + reply recorded durably on the PR** as `<!-- crtriage -->` / `<!-- crreply -->` comments,
  joined by line-free `id`; all 5 findings answered *Fixed in `170f363`* (SHA resolved live).
- ✅ **PR #16 squash-merged** → `c2a3fc6`; branch deleted (local + remote); `main` clean & synced.
  No cloud re-review had triggered on the round-2 push at merge time (user confirmed, merged as-is).
- ⏭️ **Note for next time:** `/fullpush`'s `/crlocal` loop is low-value on a docs/command-tooling-only
  diff (no Dart) — the user cut it short here; the cloud bot is the real gate anyway.

## Done this run (2026-07-11, session 11) — Land the agent fleet (PR #18)
- ✅ **`/coderabbit` on PR #18 — clean carry-forward.** All 9 findings were the *same* stale review
  (`4676963616` @ `060f099`, 5 commits behind HEAD); already triaged/fixed/deferred in cycle 1.
  Re-verified every fix persists in current source (8 present, 1 correctly deferred → #3). No new
  commit, no crtriage change.
- ✅ **`/replycoderabbit` — idempotent no-op.** Existing `<!-- crreply -->` already covers all 9 ids;
  re-resolved the fix SHA live by commit subject → single match `f80bc5e`; nothing to post.
- ✅ **Squash-merged PR #18** → `fba34f6` (`feat: adopt the full LMS-Plus agent fleet…`); deleted the
  remote branch + pruned the stale local ref; local `main` fast-forwarded, clean & synced. Fleet
  (10 agents + rules + post-commit nudge + agent-memory trackers) now on `main`.

## Done this run (2026-07-11, session 12) — Event comments
- ✅ **Built event comments on events.** Add / inline-edit / archive / toggle-archived / unarchive. Single `event_comments` table (id, event_id FK, body, created_at, updated_at, deleted_at) under RLS.
- ✅ **SELECT policy `using (true)` — archived comments stay readable** (Decision 23, database.md #4 amendment) so the UI can surface them under a toggle. Because archived rows survive PostgREST's RETURNING re-check, archive/unarchive/edit are plain direct UPDATEs — no soft-delete RPC needed (unlike `soft_delete_event_type` / `soft_delete_contact`).
- ✅ **Dart:** pure-Dart `Comment` model (the only model that reads `deleted_at` back); `CommentsRepository` (interface + SupabaseCommentsRepository, direct CRUD); self-contained `_CommentsSection` on `EventDetailScreen`.
- ✅ **Tests:** 69 green (comment_test + comments_section_test + calendar_screen_test + widget_test coverage; test-writer added 6 for the load-failure/stale-guard/button-gating branches). **curl-verified:** insert/edit/archive/unarchive 200 · archived still SELECTable · empty body 400 · anon DELETE 401 (no grant).
- ✅ **Branch ready:** `feat/event-comments` awaiting push/merge. Gate: analyze · 69 tests · web build.

## Done previous runs
- 2026-07-08 (s1): styling = stock M3 (Decision 8); planned + built the walking skeleton (parked).
- 2026-07-07: Flutter installed; LMS Plus conventions verified; foundation docs; pushed to github.com/okpilot/first-android-app; CodeRabbit adopted (PR #1); `/wrapup` added.
