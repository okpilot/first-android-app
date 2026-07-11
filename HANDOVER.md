> Cross-session work tracker. Update in place. Last updated: 2026-07-11.

# Handover

**Status: EVENT COMMENTS — IMPLEMENTED, PR #20 open (feat/event-comments) — cloud-CR cycle 1 triaged, reply pending.**
Add / inline-edit / archive / toggle-archived / unarchive on events. Single-table, direct-CRUD under RLS (no RPC); SELECT policy `using (true)` so archived comments stay readable (Decision 23, database.md #4 amendment). Comment model reads `deleted_at` back; CommentsRepository direct CRUD (edit is body-only); self-contained _CommentsSection on event detail. 69 tests green; curl-verified (insert/edit/archive/unarchive 200, archived SELECTable, empty body 400, anon DELETE 401); emulator visual QA light+dark.
**This session (session 12) — `/coderabbit` on PR #20:** 6 cloud findings → **3 FIX** (doc/memory-accuracy in `d0aa1f1`: plan.md 63→69 tests + branch-ready-not-SHIPPED; code-reviewer memory async-safety wording; learner memory `discarded_futures` now-enabled), **1 DEFER → #10** (duplicate inert `_FakeCommentsRepo` in two test files), **2 SKIP** (red-team + semantic/test-writer memories already resolved in current source). Pushed via `/fullpush` (gate green · analyze · 69 tests · web build · `/crlocal` 2 rounds clean). Disposition comment on PR #20. **Caught+removed a stray `CRM+ logo design (5).zip`** an over-broad `git add -A` had swept into the commit (amended out; still untracked on disk).
**RESUME = run `/replycoderabbit` on PR #20** once the cloud bot re-reviews `d0aa1f1`, then squash-merge + deploy the migration to homebase.

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
