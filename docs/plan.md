---
status: read me first each session
updated: 2026-07-09
---

# Plan — First Android App (learning CRM)

## Goal
Learn app development end-to-end by building a light CRM in Flutter, backed by a
trimmed self-hosted Supabase on homebase. Learning is the point; the CRM is
disposable. Built emergently — thin slices, one at a time.

## Current status (2026-07-09)
- ✅ Environment: Flutter 3.44.5; Web + Linux + **Android** targets all ready (SDK installed, Pixel + S23+ emulators).
- ✅ Decisions made — **18** (see `docs/decisions.md`): + design-principles adoption, local backend, Android SDK, Contacts slice, bespoke theme, homebase deploy, git hooks, calendar shell, /replycoderabbit, **calendar events**.
- 🔎 **Calendar events + attendees — PR #8 OPEN (awaiting cloud CodeRabbit + merge).** `events` + `event_attendees` tables (3 migrations) + `create/update/soft_delete_event` RPCs; `Event` model + `EventsRepository`; event form (all-day toggle, 24h time pickers, attendee picker) + detail; the four calendar views wired to real data (blocks with lane-splitting, bounded all-day band, month dots + panel, agenda). `/fullpush` green · **31 tests** · migrations clean on a fresh DB · `/crlocal` converged (4 rounds) · **emulator visual QA light+dark** · CI green. Decision 18.
- 🧰 **Follow-ups filed:** #6 (LMS-Plus-style agent fleet, Flutter-adapted) · #7 (Tailscale GitHub Action to auto-deploy migrations to homebase).
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
**Land PR #8:** `/replycoderabbit` once the cloud review posts → dispose findings → merge → `./backend/deploy-homebase.sh` (apply the 3 event migrations to homebase) → delete the merged branch. Then pick from: the **agent fleet** (#6) · **auth (GoTrue) + DB hardening** (#3, adds `auth.uid()` ownership checks to the event RPCs) · the **Tailscale db-deploy action** (#7). Later candidates: overnight/`timestamptz` events, full 7-column week, range-fetch, search/filter.
