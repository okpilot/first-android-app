# First Android App — a learning CRM (Flutter + trimmed self-hosted Supabase)

A hands-on project to learn app development by building a light CRM. The CRM is a
disposable vehicle — **learning is the goal**. Built the *emergent* way: thin
vertical slices, never big features up front.

## Stack
- **Client:** Flutter (Dart) — one codebase → Android + Web + Linux desktop. iOS later (needs a Mac).
- **Backend:** Postgres, served the Supabase way — **trimmed, self-hosted on `homebase`**:
  Postgres + PostgREST (REST/RPC) + GoTrue (auth), fronted by the existing Caddy.
  No Kong / Realtime / Storage / Studio. (~80–130 MB idle.)
- **Client SDK:** `supabase_flutter`.

## How we work (the workflow)
Emergent, slice by slice. For each change:
1. **Explore** — understand what exists before touching it.
2. **Propose the next thin slice** — the smallest end-to-end step; confirm before building anything big.
3. **Plan** — for non-trivial work, state the plan and validate it before coding.
4. **Implement** the slice (UI + logic + data for ONE thing).
5. **Review** the diff against the plan, in-session (visible).
6. **Record** — append a line to `docs/decisions.md` for any decision made.

Skips are allowed but **must be stated, never silent**.

## Branching & the push gate
- **Branch per slice** — never build on `main`. `main` stays green.
- **Before every push, run the `/fullpush` gate** (`.claude/commands/fullpush.md`):
  `flutter analyze` + `flutter test` + `flutter build web`, then **`/crlocal`** (mandatory
  CodeRabbit local review — `.claude/commands/crlocal.md`), then **ask for explicit push approval**.
- CodeRabbit is installed org-wide, so the cloud bot also reviews the PR on push — that's the authoritative gate; `/crlocal` is the cheaper pre-push preview.
- **CI/CD** (GitHub Actions: analyze + test + build) is added *with Slice 1*, when there's a Flutter project to run against.
- **At end of session, run `/wrapup`** (`.claude/commands/wrapup.md`) — sync docs, dispose of every open finding, leave `main` clean.

## NEVER DO
- **NEVER** build a large feature from a vague ask — propose the next thinnest slice and confirm first.
- **NEVER** commit or push without the user's explicit go-ahead.
- **NEVER** put secrets in committed files (settings, source, docs). Use env / `.env` (gitignored).
- **NEVER** rewrite a past decision in `docs/decisions.md` — append, or amend in place with a date.
- **NEVER** hit raw Postgres from the Flutter client — always via PostgREST/GoTrue under RLS.

## Binding docs (read these)
- `docs/plan.md` — read first each session: goal, status, next slice.
- `docs/decisions.md` — the append-only decision ledger.
- `docs/database.md` — DB conventions (apply as slices need them).
- `docs/design-principles.md` — how we apply the UI/UX principles (light wrapper; advisory, not a gate). Its two source-verified encyclopedias (`docs/UI-Principles-*.md`, `docs/UX-Principles-*.md`) are on-demand references — reach for their Build Checklists **only at UI slices**, not every session.
- `HANDOVER.md` — where we left off.

## Environment
- Flutter 3.44.5 at `~/flutter` (not on PATH — use `~/flutter/bin/flutter`).
  Web + Linux desktop ready; Android SDK not yet installed.
- Run: `~/flutter/bin/flutter run -d chrome` (web) · `-d linux` (desktop).
