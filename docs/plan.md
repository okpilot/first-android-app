---
status: read me first each session
updated: 2026-07-07
---

# Plan — First Android App (learning CRM)

## Goal
Learn app development end-to-end by building a light CRM in Flutter, backed by a
trimmed self-hosted Supabase on homebase. Learning is the point; the CRM is
disposable. Built emergently — thin slices, one at a time.

## Current status (2026-07-07)
- ✅ Environment: Flutter 3.44.5 installed; Web + Linux desktop targets ready.
- ✅ Decisions made — stack, method, backend (see `docs/decisions.md`).
- ✅ Foundation docs laid: this file, `CLAUDE.md`, `decisions.md`, `database.md`, `HANDOVER.md`.
- ⬜ No app code yet. No backend stood up yet.

## Roadmap (each step is a thin, visible slice)
1. **Walking skeleton (local only):** one screen listing a few hard-coded contacts, running in Chrome. No backend. — *next*
2. Add "create contact" (in-memory) — learn Flutter state.
3. Persist locally — learn storage.
4. Stand up the trimmed backend on homebase; one `contacts` table + first migration.
5. Wire the app to the backend (read, then write) — the client↔backend split.
6. Add auth (GoTrue) when a slice needs per-user data.
7. Build the Android version (install SDK) when ready for phones.

## Next slice
Step 1 — walking skeleton in the browser. Awaiting the user's go-ahead and any
design preference (what a "contact" shows, how the list looks).
