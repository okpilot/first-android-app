> Cross-session work tracker. Update in place. Last updated: 2026-07-08.

# Handover

**Status: Contacts slice DONE and MERGED. PR #2 squash-merged into `main` (commit
`fa4fc45`, 2026-07-08); branch deleted (local + remote); `main` clean and synced. Full
CRUD, bespoke mono theme, running on Android/web/Linux, backend deployed to homebase
(tailnet). Resume = next slice (auth + DB hardening, issue #3) off a fresh branch.**

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

## Done previous runs
- 2026-07-08 (s1): styling = stock M3 (Decision 8); planned + built the walking skeleton (parked).
- 2026-07-07: Flutter installed; LMS Plus conventions verified; foundation docs; pushed to github.com/okpilot/first-android-app; CodeRabbit adopted (PR #1); `/wrapup` added.
