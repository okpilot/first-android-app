> Cross-session work tracker. Update in place. Last updated: 2026-07-09.

# Handover

**Status: Calendar EVENTS + attendees — SHIPPED & DEPLOYED. PR #8 merged (squash → `6f14d66`);
the 3 event migrations are live on homebase and verified. Deploy-tooling fix PR #11 merged
(squash → `5947599`). `main` clean and synced at `5947599`; no open branches.**
Full slice down to the DB: `events` + `event_attendees` (3 migrations) +
`create/update/soft_delete_event` SECURITY DEFINER RPCs; `Event` model + `EventsRepository`
(+ fakes); event form (all-day toggle, **24h** time pickers, searchable attendee picker) +
detail; the four calendar views wired to real data (timeline blocks with lane-splitting +
bounded all-day band, month dots + selected-day panel, agenda grouped by day). New theme
tokens (`EventBlockStyle`, mono `switchTheme` + `timePickerTheme`), shared `InitialsAvatar`.
**`/fullpush` green · `/crlocal` converged · cloud CodeRabbit on PR #8 fully answered
(2 fixed post-review, 2 deferred → #9/#10, 2 skipped false-positives it conceded) · 33 tests ·
SQL curl-verified · emulator visual QA light+dark · CI green.** Decision 18.

**Homebase deploy is LIVE:** `events` + `event_attendees` tables (RLS on), 3 RPCs, ledger has all
5 migrations, PostgREST cache reloaded — `GET /rest/v1/events` → `200 []` (empty; prod carries no
seed). Deploys go through `./backend/deploy-homebase.sh` — **now genuinely idempotent** (PR #11
fixed a broken remote exists-check) — and may prompt a **one-time Tailscale SSH re-auth** (visit
the printed URL, then it continues; re-run is safe, already-applied migrations are skipped).

**RESUME = pick the next slice — no blocker.** Candidates: **agent fleet (#6)** · **auth (GoTrue) +
DB hardening (#3** — adds `auth.uid()` ownership to the event RPCs; RLS is anon-permissive until
then**)** · **Tailscale GH Action to auto-deploy migrations (#7)**. Plus the two just-filed
duplication/idempotency cleanups (**#9**, **#10**).

_Follow-up issues open: **#3** (DB security hardening) · **#6** (LMS-Plus-style agent fleet,
Flutter-adapted) · **#7** (Tailscale GitHub Action to auto-deploy migrations) · **#9** (idempotent
event write RPCs — client id / `ON CONFLICT`) · **#10** (dedup test fakes + labelled-field widget)._

_(Previous: Calendar shell merged PR #4 → `7dd0995`; `/replycoderabbit` PR #5 → `4e210e2`;
Contacts PR #2 → `fa4fc45`.)_

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

## Done previous runs
- 2026-07-08 (s1): styling = stock M3 (Decision 8); planned + built the walking skeleton (parked).
- 2026-07-07: Flutter installed; LMS Plus conventions verified; foundation docs; pushed to github.com/okpilot/first-android-app; CodeRabbit adopted (PR #1); `/wrapup` added.
