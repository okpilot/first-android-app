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
- ✅ Environment: Flutter 3.44.5; Web + Linux + **Android** targets all ready now.
- ✅ Decisions made — 12 (see `docs/decisions.md`): stack, method, backend, CodeRabbit, styling, design-principles adoption, local dev backend, Android SDK, Contacts slice.
- ✅ Design principles adopted (Decision 9) — `docs/design-principles.md` + two encyclopedias in `docs/`.
- ✅ **Local dev backend running** (`backend/`): Postgres + PostgREST + Caddy gateway; `contacts` table + RLS + soft-delete RPC + seed. Verified via curl.
- ✅ **Android SDK installed** (portable, home dir); Pixel emulator working.
- ✅ **Contacts feature built & running end-to-end on Android** (list/detail/add/edit/soft-delete against the real backend). Local gate green (analyze + 5 tests + web build).
- 🔨 All work is **local, unpushed** on branch `slice-1-walking-skeleton` (used as the continuous dev line). Nothing on GitHub since Decision 7.
- ⬜ homebase deploy deferred (Decision 10). Auth (GoTrue) deferred. Bespoke theme deferred.

## Roadmap (each step is a thin, visible slice)
1. ~~Walking skeleton~~ ✅ (parked) → superseded by the real Contacts slice.
2. ✅ **Contacts, for real** — full CRUD UI + trimmed backend (Postgres/PostgREST/RLS), running on Android.
3. **Next candidates:** bespoke mono/Linear-Attio theme · adaptive/two-pane layout for wide screens · search/filter on the list · deploy backend to homebase (public HTTPS) · auth (GoTrue) when a slice needs per-user data.

## Next slice
Open — pick from the candidates above. Everything is local & unpushed; when ready to
push, reorganize the local dev line into proper per-slice branches/PRs and run the gate.
