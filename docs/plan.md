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
- 🔨 **Event types — Slices 1 & 2 shipped (PRs open, not yet merged).** Colour-as-data (Decision 19). **Slice 1** (PR #13): `event_types` table + `events.type_id` FK + `EventType` model + read embed; linchpin curl-verified (embed nulls on soft-delete). **Slice 2** (PR #14, stacked on #13): Settings → Event types manager/editor + `soft_delete_event_type` RPC; 8-swatch palette; **emulator visual QA light+dark**. Both `/fullpush`-green · 45 tests · `/crlocal` triaged. **Not deployed to homebase yet** (no calendar rendering until Slice 3). **Slice 3 (assign + show) is next.**
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
**Event types — Slice 3 (assign + show).** The visible payoff, per the approved plan
(`~/.local/.../plans/synthetic-petting-sunset.md`) and Decision 19:
- **Migration:** `create_event`/`update_event` gain a trailing `p_type_id uuid default null`
  (drop + recreate + regrant — a new param is a new signature; `default null` keeps an
  un-updated client working). Then `Event.toRpcParams()` sends `p_type_id`.
- **Assign:** a **Type** picker in the event form (select existing + on-the-fly create, which
  reuses the Slice-2 editor screen).
- **Show:** full-area **tinted** Day/3-day blocks (NO rail; theme-split per-swatch alpha,
  calibrate on the emulator) · a **dot + type name inline** in Agenda/detail · coloured Month
  **"+N"** dots (needs the small `_DayCell` re-spec).
- **Then:** deploy all event-types migrations to homebase; emulator visual QA light+dark.

**Blocker to clear first:** none for the code. Before Slice 3 ships to the phone, deploy the
Slice 1+2 migrations to homebase (currently local-only). Stacked PRs #13 → #14 should merge in
order.

Later candidates (unchanged): DB hardening + auth (GoTrue) — **issue #3**, now also covers
`event_types` write-hardening + the `soft_delete_event_type` `auth.uid()` check · agent fleet
(#6) · Tailscale db-deploy action (#7) · #9/#10 cleanups · overnight/`timestamptz` events ·
full 7-column week · search/filter.
