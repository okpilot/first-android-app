---
status: read me first each session
updated: 2026-07-10
---

# Plan — First Android App (learning CRM)

## Goal
Learn app development end-to-end by building a light CRM in Flutter, backed by a
trimmed self-hosted Supabase on homebase. Learning is the point; the CRM is
disposable. Built emergently — thin slices, one at a time.

## Current status (2026-07-10)
- ✅ Environment: Flutter 3.44.5; Web + Linux + **Android** targets all ready (SDK installed, Pixel + S23+ emulators). **App installed & running on the physical S23+** (debug APK against homebase over Tailscale — data round-trips verified).
- ✅ Decisions made — **19** (see `docs/decisions.md`): + design-principles adoption, local backend, Android SDK, Contacts slice, bespoke theme, homebase deploy, git hooks, calendar shell, /replycoderabbit, calendar events, **event types (colour-as-data)**.
- 🔨 **Event types — Slices 1, 2 & 3 shipped (PRs open, not yet merged).** Colour-as-data (Decision 19). **Slice 1** (PR #13): `event_types` table + `events.type_id` FK + `EventType` model + read embed; linchpin curl-verified (embed nulls on soft-delete). **Slice 2** (PR #14, stacked on #13): Settings → Event types manager/editor + `soft_delete_event_type` RPC; 8-swatch palette. **Slice 3** (PR #15, stacked on #14): `p_type_id` on the write RPCs; event-form Type picker (pick-existing + "Manage types…"); full-area **tinted** Day/3-day blocks (no rail); dot + name in Agenda/detail/panel; coloured Month density dots + "+N"; shared `TypeLabel` atom; `tintForType`. All `/fullpush`-green · 48 tests · migrations clean on a fresh DB · end-to-end curl (typed create/update + soft-delete linchpin) · **emulator visual QA light+dark, every surface**. **Not deployed to homebase yet** — deploy the three event-types migrations before the phone sees it. **Next:** merge #13→#14→#15 in order; deploy; then a new slice.
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
**Event types — DONE (Slices 1–3 shipped as stacked PRs #13 → #14 → #15).** No further
event-types work planned; pick the next thin slice from the roadmap below.

**Before the phone sees it:** deploy the four event-types migrations to homebase
(`20260710120000/120100/120200/120300`, currently local-only) via `backend/deploy-homebase.sh`
— it self-issues `notify pgrst, 'reload schema'`. Merge the stack #13 → #14 → #15 in order.

Later candidates (unchanged): DB hardening + auth (GoTrue) — **issue #3**, now also covers
`event_types` write-hardening + the `soft_delete_event_type` `auth.uid()` check · agent fleet
(#6) · Tailscale db-deploy action (#7) · #9/#10 cleanups · overnight/`timestamptz` events ·
full 7-column week · search/filter.
