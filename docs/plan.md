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
- ✅ **Pushed & in review**: branch `feature/contacts-crm` → **PR #2** into `main`. `/fullpush` green; `/crlocal` converged (4 rounds); cloud CodeRabbit + CI **pass**.

## Roadmap (each step is a thin, visible slice)
1. ~~Walking skeleton~~ ✅ → superseded by the real Contacts slice.
2. ✅ **Contacts, for real** — CRUD UI + trimmed backend, themed, on Android; deployed to homebase.
3. **Next candidates:** DB security hardening (issue — RPC `auth.uid()`, revoke PUBLIC execute, column-level write grants) · **auth (GoTrue)** logins + owner-based RLS · search/filter on the list · adaptive/two-pane layout for wide screens · run on the physical S23+.

## Next slice
Open — likely **auth (GoTrue) + DB hardening** together (the deferred security work naturally pairs), or a smaller UI slice (search/adaptive layout). Merge PR #2 first to bring `main` current.
