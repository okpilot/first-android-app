---
status: read me first each session
updated: 2026-07-08
---

# Plan — First Android App (learning CRM)

## Goal
Learn app development end-to-end by building a light CRM in Flutter, backed by a
trimmed self-hosted Supabase on homebase. Learning is the point; the CRM is
disposable. Built emergently — thin slices, one at a time.

## Current status (2026-07-08)
- ✅ Environment: Flutter 3.44.5; Web + Linux + **Android** targets all ready (SDK installed, Pixel + S23+ emulators).
- ✅ Decisions made — **15** (see `docs/decisions.md`): + design-principles adoption, local backend, Android SDK, Contacts slice, bespoke theme, homebase deploy, git hooks.
- ✅ **Contacts — first real vertical slice**: full CRUD (list/detail/add-edit/soft-delete) with states, injectable repo (hermetic tests), **bespoke mono/Linear-Attio theme** (Decision 13). Runs on Android/web/Linux.
- ✅ **Backend**: trimmed Supabase (Postgres + PostgREST + Caddy). Local dev **and deployed to homebase** (`https://homebase.tail7ab4bc.ts.net:8452`, tailnet-only HTTPS, Decision 14). Schema source of truth = `backend/migrations/`; applied to homebase via `backend/deploy-homebase.sh`.
- ✅ **Mechanical git hooks** (`.githooks/`, Decision 15): pre-commit format+analyze, commit-msg, pre-push secret scan.
- ✅ **Merged**: **PR #2** squash-merged into `main` (commit `fa4fc45`, 2026-07-08). `/fullpush` green; `/crlocal` converged; cloud CodeRabbit + CI passed. Branch deleted (local + remote).
- 🔨 **Calendar shell — in progress** on `slice-calendar-shell` (Decision 16): adaptive nav shell (Contacts · Calendar; `NavigationBar`↔`NavigationRail`) + `CalendarScreen` with four views (Month · 3-day · Day · Agenda), Monday-start, pure date logic, shared `EmptyState`. **No events yet** (chrome only). Verified on Android emulator + web (rail/bar) in light + dark; analyze clean, 18 tests. Pending `/fullpush` → push.

## Roadmap (each step is a thin, visible slice)
1. ~~Walking skeleton~~ ✅ → superseded by the real Contacts slice.
2. ✅ **Contacts, for real** — CRUD UI + trimmed backend, themed, on Android; deployed to homebase.
3. **Calendar** — ~~shell (four views)~~ 🔨 in progress → then **events** (schedule/CRUD).
4. **Next candidates:** DB security hardening (issue #3 — RPC `auth.uid()`, revoke PUBLIC execute, column-level write grants) · **auth (GoTrue)** logins + owner-based RLS · search/filter on the list · run on the physical S23+ · full 7-column week (wide-screen adaptive).

## Next slice
**Calendar — events.** After the shell merges: `events` table + migration + RLS + `soft_delete_event` RPC, an `Event` model, `EventsRepository` (+ fake for hermetic tests), and real events wired into all four views (the timelines finally get blocks; Month gets a designed selected-day panel; Agenda groups by day). Then the deferred **auth (GoTrue) + DB hardening** pairing (issue #3).
