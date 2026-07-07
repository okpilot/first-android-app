---
date: 2026-07-07
status: active
project: First Android App (learning CRM)
---

# Decisions & Ideas Ledger

> Append-only, numbered, dated log. New decisions go at the bottom with the next
> number. Amend in place with a dated sub-note — never silently rewrite. Standing
> summary at the top for quick orientation.

## Standing decisions (summary)
- **Stack:** Flutter (Dart) client → Android / Web / Linux desktop; trimmed
  self-hosted Supabase (Postgres + PostgREST + GoTrue) on homebase behind Caddy.
- **Method:** emergent — thin vertical slices, YAGNI, schema grows by migration.
- **Conventions:** modeled on the (verified) LMS Plus conventions, scaled down.

---

## Decision 1: Build with Flutter, one codebase for all platforms (2026-07-07)
**Context:** Wanted an Android app now and a web interface later with minimal duplicated work; user is on Linux.
**Decided:** Use Flutter/Dart — one codebase compiles to Android + Web + Linux desktop (iOS later, needs a Mac). Start with Web + Linux desktop (both run on the dev machine today); defer the Android SDK.
**Principle:** One codebase, many targets — don't build the UI twice.

## Decision 2: Dart is the only app language; web is not TypeScript (2026-07-07)
**Context:** User assumed a web app requires TypeScript.
**Decided:** Write everything in Dart. Flutter compiles Dart → JavaScript for the browser automatically. No TS / JS / Kotlin by hand.
**Principle:** The browser runs JS, but we don't hand-write it — Dart compiles to it.

## Decision 3: Practice project is a disposable light CRM (2026-07-07)
**Context:** Need a concrete thing to build to learn on. User already self-hosts EspoCRM but does not want to reuse it.
**Decided:** Build a light CRM from scratch as a learning vehicle. The product is disposable; learning is the point.
**Principle:** The vehicle serves the learning, not the other way round.

## Decision 4: Build the emergent way (2026-07-07)
**Context:** User builds through discovery; cannot/does not want to specify large features up front — layout and schema should emerge.
**Decided:** Work in thin vertical slices (walking skeleton first). Grow the schema by forward-only migration, one field/table at a time. Apply YAGNI. Every "add X" = smallest working version → review → next slice.
**Principle:** Discover the design by building it, not before.

## Decision 5: Backend = Postgres, served the Supabase way, trimmed + self-hosted (2026-07-07)
**Context:** User's verified conventions are deeply Postgres/RPC/RLS-shaped; a Flutter client can't safely hit raw Postgres. Full self-hosted Supabase is too heavy; an earlier PocketBase idea wouldn't reuse the Postgres muscle memory.
**Decided:** Self-host a **trimmed** Supabase on homebase — Postgres + PostgREST (REST/RPC) + GoTrue (auth), routed through the existing Caddy (no Kong). Skip Realtime/Storage/Studio/imgproxy. ~80–130 MB idle (less if we reuse an existing Postgres). Flutter uses `supabase_flutter`.
**Principle:** Take Postgres's power and Supabase's conventions; leave the weight behind.

## Decision 6: Model conventions on LMS Plus — verified, then scaled down (2026-07-07)
**Context:** LMS Plus is a mature project with established conventions; a single extraction pass idealized several DB claims.
**Decided:** Adopt LMS Plus conventions, but only after two independent audit rounds verified them. Corrections: it is NOT "everything is RPC" (RPC for multi-table/immutable/sensitive; direct RLS access otherwise); pagination is LIMIT/OFFSET (default 10), not keyset; hard DELETEs exist only as annotated exceptions; secrets were leaked in its settings (anti-pattern to avoid). Scale the tooling down — principles, not the full 10-agent ceremony.
**Principle:** Inherit *verified* principles, not idealized ones; earn ceremony as the project grows.

## Decision 7: Adopt CodeRabbit + a scaled cr-local/fullpush push gate (2026-07-07)
**Context:** CodeRabbit is installed org-wide on `okpilot` (so it reviews every repo's PRs), and the `coderabbit` CLI is installed + Pro. The user requires cr-local before every push, per their LMS Plus `/fullpush` gate.
**Decided:** Adopt, scaled to this project: (a) `.coderabbit.yaml` (lean, Dart + SQL path_instructions, no secrets); (b) `.claude/commands/crlocal.md` — run `coderabbit review --base main --type committed`, triage apply/skip/defer reading source, min 2 rounds (3 for SQL/security), stop when ≥min and last round clean, ceiling 4 fix-commits; (c) `.claude/commands/fullpush.md` — analyze + test + build + crlocal + explicit push approval; (d) **branch per slice**, `main` stays green. CI/CD (GitHub Actions) added with Slice 1.
**Principle:** cr-local before every push; the cloud bot on the PR is the authoritative gate. Earn heavier ceremony (multi-agent pipeline, e2e, scanners) as the project grows.

---

## OPEN QUESTIONS
- [x] Backend hosting: **self-host trimmed on homebase** (vs Supabase cloud). Settled 2026-07-07; revisit only if homebase load becomes a problem.
- [ ] First walking-skeleton slice: which single CRM entity to start with (likely `contacts`)? — decide when we start building.

## IDEAS / NOTES
- The `okpilot/selfhost` repo on homebase is where the backend stack (a new `stacks/` dir + a Caddy route) will live, committed like the others.
