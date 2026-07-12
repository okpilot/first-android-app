---
status: read me first each session
updated: 2026-07-12
---

# Plan — First Android App (learning CRM)

## Goal
Learn app development end-to-end by building a light CRM in Flutter, backed by a
trimmed self-hosted Supabase on homebase. Learning is the point; the CRM is
disposable. Built emergently — thin slices, one at a time.

## Current status (2026-07-12)
- ✅ Environment: Flutter 3.44.5; Web + Linux + **Android** targets all ready (SDK installed, Pixel + S23+ emulators). **App installed & running on the physical S23+** (debug APK against homebase over Tailscale — data round-trips verified).
- ✅ **App identity — launcher `CRM+` + dark `C⁺` icon (Decision 24) — SHIPPED & MERGED (PR #22 → squash `343bcdc`).** Renamed `android:label` → `CRM+`; generated all mipmap densities + a modern adaptive icon via `flutter_launcher_icons` from the user's dark `C⁺` mark. Reproducible sources (SVG + PNG) committed under `assets/icon/`; adaptive foreground is a clean transparent glyph on a `#0a0a0a` background (no card-outline artifact under the mask); inset driven by `adaptive_icon_foreground_inset: 0` in config. Android-only. Gate green (analyze · 69 tests · web build); `/crlocal` 2 clean rounds; cloud-CR cycle 1 answered (1 finding FIX `1fff1ee`); branch deleted. **On-device S23+ QA PASSED** — installed via `/updatephone` (`8c52f81`); dark C⁺ icon + `CRM+` name verified on the launcher in light + dark, glyph size good.
- ✅ **RPC-for-all-writes (Decision 26) — Slice 0 COMPLETE & DEPLOYED.** Slice 0 (PostgREST auto-reload via DDL-watch triggers) deployed to homebase & verified live (`670787c`, PR #25 + follow-up commit); deploy script reframed to single unconditional `notify pgrst` as cold-start safety net; triggers own running/steady-state + ad-hoc case (Decision 25 amended 2026-07-12). **Next: Slices 1–3** (contacts/event_types/comments writes → RPC). Root-caused from the event-comment 404 = PostgREST stale-schema-cache.
- ✅ Decisions made — **26** (see `docs/decisions.md`): + design-principles adoption, local backend, Android SDK, Contacts slice, bespoke theme, homebase deploy, git hooks, calendar shell, /replycoderabbit, calendar events, **event types (colour-as-data)**, **cloud-CR two-command split (D20)**, **README Features section over a docs site (D21)**, **full LMS-Plus agent fleet (D22)**, **event comments (viewable soft-delete, D23)**, **app identity — `CRM+` + dark `C⁺` icon (D24)**, **PostgREST schema-reload on deploy (D25)**, **RPC for all writes; reads direct (D26)**.
- ✅ **Agent fleet (issue #6) — SHIPPED & MERGED (PR #18 → squash `fba34f6`).** Full 10-agent LMS-Plus reviewer fleet, Flutter-adapted (Decision 22): `.claude/agents/` (10 phase-aware advisory reviewers) + `.claude/rules/agent-workflow.md`/`agent-memory.md` + `.githooks/post-commit` nudge + a CLAUDE.md fleet section + a fleet-aware `/wrapup`. Cloud CR cycle 1 answered (8 fixed, 1 deferred → #3); branch deleted; `main` clean & synced.
- ✅ **Event comments — SHIPPED, MERGED (PR #20 → squash `1c89b64`) & DEPLOYED to homebase.** Add / inline-edit / archive (soft-delete) / view-archived toggle / unarchive on events. Single-table direct-CRUD (no RPC); SELECT policy `using (true)` so archived comments stay readable (Decision 23, database.md convention #4 amendment). Pure-Dart `Comment` model (reads `deleted_at` back), `CommentsRepository` (direct CRUD), self-contained `_CommentsSection` on event detail. 69 tests green; verified via curl (insert/edit/archive/unarchive 200, archived SELECTable, empty body 400, anon DELETE 401). Cloud-CR cycle 1: 3 FIX (`d0aa1f1`) · 1 DEFER → #10 · 2 SKIP; `/replycoderabbit` skipped by user. **Deployed to homebase** via `deploy-homebase.sh` (ledger 9 → **10**); verified live `GET /rest/v1/event_comments` → `200 []`.
- ✅ **Event types — SHIPPED, MERGED & DEPLOYED (Slices 1–3).** Colour-as-data (Decision 19). **Slice 1** (PR #13 → squash): `event_types` table + `events.type_id` FK + `EventType` model + read embed. **Slice 2** (PR #14 → squash): Settings → Event types manager/editor + `soft_delete_event_type` RPC; 8-swatch palette. **Slice 3** (PR #15 → squash): `p_type_id` on the write RPCs; event-form Type picker (pick-existing + "Manage types…"); full-area **tinted** Day/3-day blocks (no rail); dot + name in Agenda/detail/panel; coloured Month density dots + "+N"; shared `TypeLabel` atom; `tintForType`. All three squash-merged in order; each cloud-CR answered · **52 tests** · emulator visual QA light+dark. **Deployed to homebase** — all 4 event-types migrations applied via `deploy-homebase.sh` (ledger at **9**; `create_event` carries `p_type_id`).
- ✅ **Cloud-CR tooling split — SHIPPED & MERGED (PR #16 → squash `c2a3fc6`).** Replaced the single `/replycoderabbit` with **`/coderabbit`** (triage) + **`/replycoderabbit`** (reply-only) + shared `scripts/cr-findings.sh` (36-assertion test). Decision 20. Designed via 3 critic rounds + 3 `/crlocal` rounds, then **dogfooded on its own PR** — the live `/coderabbit → /fullpush → /replycoderabbit` run FIX-NOW'd two real bugs in the new commands (`170f363`: 5 cloud-CR findings; `5468f0f`: unanchored marker lookup matched the wrong comment). `main` clean & synced.
- ✅ **Calendar events + attendees — SHIPPED & DEPLOYED (PR #8 merged → `6f14d66`).** `events` + `event_attendees` tables (3 migrations) + `create/update/soft_delete_event` RPCs; `Event` model + `EventsRepository`; event form (all-day toggle, 24h time pickers, attendee picker) + detail; the four calendar views wired to real data (blocks with lane-splitting, bounded all-day band, month dots + panel, agenda). `/fullpush` green · **33 tests** · migrations clean on a fresh DB · `/crlocal` converged · cloud CodeRabbit fully answered (2 fixed, 2 deferred → #9/#10, 2 skipped false-positives) · **emulator visual QA light+dark** · CI green. **Live on homebase** (`GET /rest/v1/events` → `200 []`). Decision 18.
- 🔧 **Deploy tooling fixed (PR #11 → `5947599`):** `deploy-homebase.sh`'s exists-check was word-split through `ssh → docker exec` and always re-applied every migration; now pipes the check over stdin with `psql -v :'name'` quoting → genuinely idempotent. (Amends Decision 14.)
- 🧰 **Follow-ups filed:** #6 (LMS-Plus-style agent fleet, Flutter-adapted) · #7 (Tailscale GitHub Action to auto-deploy migrations to homebase) · #9 (idempotent event write RPCs — client id / `ON CONFLICT`) · #10 (dedup test fakes + labelled-field widget).
- ✅ **Contacts — first real vertical slice**: full CRUD (list/detail/add-edit/soft-delete) with states, injectable repo (hermetic tests), **bespoke mono/Linear-Attio theme** (Decision 13). Runs on Android/web/Linux.
- ✅ **Backend**: trimmed Supabase (Postgres + PostgREST + Caddy). Local dev **and deployed to homebase** (`https://homebase.tail7ab4bc.ts.net:8452`, tailnet-only HTTPS, Decision 14). Schema source of truth = `backend/migrations/`; applied to homebase via `backend/deploy-homebase.sh`.
- ✅ **Mechanical git hooks** (`.githooks/`, Decision 15): pre-commit format+analyze, commit-msg, pre-push secret scan.
- ✅ **Merged**: **PR #2** squash-merged into `main` (commit `fa4fc45`, 2026-07-08). `/fullpush` green; `/crlocal` converged; cloud CodeRabbit + CI passed. Branch deleted (local + remote).
- ✅ **Calendar shell — MERGED** (PR #4 squash → `7dd0995`, 2026-07-09; branch deleted, Decision 16): adaptive nav shell (Contacts · Calendar; `NavigationBar`↔`NavigationRail`) + `CalendarScreen` with four views (Month · 3-day · Day · Agenda), Monday-start, pure date logic, shared `EmptyState`. **No events yet** (chrome only). CI + cloud CodeRabbit passed (1 minor finding fixed + replied).

## Roadmap (each step is a thin, visible slice)
1. ~~Walking skeleton~~ ✅ → superseded by the real Contacts slice.
2. ✅ **Contacts, for real** — CRUD UI + trimmed backend, themed, on Android; deployed to homebase.
3. **Calendar** — ~~shell (four views)~~ 🔨 in progress → then **events** (schedule/CRUD).
4. **Next candidates:** DB security hardening (issue #3 — RPC `auth.uid()`, revoke PUBLIC execute, column-level write grants) · **auth (GoTrue)** logins + owner-based RLS · search/filter on the list · run on the physical S23+ · full 7-column week (wide-screen adaptive).

## Next slice
**RPC-for-all-writes — Decision 26 (Slice 0 ✅ done & deployed; Slices 1–3 remaining).** Standardize every write onto PostgREST RPCs; reads stay
direct. Plan: `~/.local/share/claude-config/claude/plans/stuck-lazy-sutton.md`.
- ✅ **Slice 0 — DDL-watch auto-reload triggers DEPLOYED & VERIFIED** (`670787c`, PR #25 + follow-up `chore/remove-manual-pgrst-reload` pending merge): deployed to homebase, verified live (create+drop test objects callable via `/rpc/` with no manual NOTIFY), deploy script reframed as cold-start safety net (Decision 25 amended 2026-07-12).
- ⏭️ **RESUME — Slice 1:** contacts writes → RPC (also rewrites database.md rule #2 — the audited-rule reversal). Then **Slice 2** event_types, **Slice 3** comments (rewrites rule #4 exception).
Queued after: **in-app empty-state hints — issue #21 (Decision 21)** (contextual hints on empty
Contacts / Calendar / comments states); then **auth (GoTrue)** + owner-based RLS (#3).

Later candidates: DB hardening + auth (GoTrue) — **issue #3**, now also covers
`event_types` write-hardening + the `soft_delete_event_type` `auth.uid()` check · Tailscale
db-deploy action (#7) · #9/#10 cleanups · overnight/`timestamptz` events · full 7-column week ·
search/filter.
