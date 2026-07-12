---
date: 2026-07-07
status: reference (apply incrementally as slices need it)
project: First Android App (learning CRM)
---

# Database conventions (binding, applied emergently)

> Conventions carried from LMS Plus and **verified by two independent audits**.
> These are the rules for DB work — but per the emergent method we ADD schema one
> slice at a time via forward-only migrations, not all up front. Companion to the
> stack decision (`decisions.md` #5).

## Core principles
1. **Atomic multi-table writes = one function.** Any operation touching 2+ tables goes in a single Postgres `SECURITY DEFINER` function (RPC), never multi-step client calls. Atomic rollback on failure.
2. **All writes via RPC; reads direct-under-RLS.** Every write (INSERT / UPDATE / soft-delete) goes through a `SECURITY DEFINER` RPC; ordinary reads go direct to the table/view under RLS. One write path per entity is the natural home for `auth.uid()` owner checks when auth (issue #3) lands. *(Updated 2026-07-12, **Decision 26** — a knowing re-reversal of the prior "RPC for what matters, not everything is RPC" wording: uniformity + the auth payoff won over case-by-case. **Migration complete:** `events`, `contacts`, `event_types` and `event_comments` all write via RPC. Rule #4's `event_comments` entry below is now only about its `using (true)` read policy, not its write path.)* **Client-side arity rule:** a Dart model's `toRpcParams()` must send **exactly** the params its target `create_*` RPC declares — the repo blind-spreads `{...toRpcParams()}` into `create`, so an extra or missing key is a runtime **PostgREST PGRST202** (function-not-found), invisible to `flutter analyze` and the hooks. A narrower or different-arity write (a body-only `update`, or `is_done` that only `update` carries) builds an **explicit** param map in the repo (e.g. `{p_id, p_body}` / `{p_id, p_title, p_is_done}`), never a spread. *(learner count 2: `update_comment` `1e7574d`, `create_task` `258cb6c`.)*
3. **Idempotency.** Retryable writes use `ON CONFLICT DO NOTHING / DO UPDATE`.
4. **Soft-delete by default.** Mutable tables get `deleted_at timestamptz NULL` (+ optionally `deleted_by`). No hard `DELETE` except explicitly-annotated exceptions (ephemeral / immutable-fact tables). Read policies filter `deleted_at IS NULL`. **Exception — `event_comments` and `tasks` (reads only):** their SELECT policy is `using (true)`, not `using (deleted_at is null)`, so archived rows stay readable under a UI "view archived" toggle/section. This breaks the usual soft-delete-means-hidden rule *because* viewing archived items is a feature, not a bug (comments: Decision 23; tasks: Decision 27). *(Its **writes** are no longer an exception: as of Decision 26 / Slice 3, add/edit/archive/unarchive route through the `create_comment` / `update_comment` / `soft_delete_comment` / `restore_comment` RPCs like every other table — for uniformity, since the `using (true)` policy means there was never a 42501 RETURNING re-check forcing a direct write here.)*
5. **RLS on every table**, enabled in the SAME migration as `CREATE TABLE`. `USING` for reads; `WITH CHECK` on write policies.
6. **SECURITY DEFINER functions** always `SET search_path = public`, and client-facing ones check `auth.uid()`.
7. **Standard columns** (usual, not dogma): `id uuid primary key default gen_random_uuid()`, `created_at timestamptz not null default now()`, `updated_at` only where rows mutate.
8. **Constraints live in the DB**, not just the app: FK / NOT NULL / CHECK / UNIQUE.
9. **Pagination = LIMIT/OFFSET, default page size 10**, total via `count(*) OVER()`. (Keyset only later, if a list proves it needs it.)
10. **Migrations are forward-only**, timestamped `YYYYMMDDHHMMSS_description.sql` (Supabase CLI format). Never edit a pushed migration — add a new one.
11. **Record the linchpin verification curl(s).** Any RLS / soft-delete-touching slice records the curl(s) that prove its non-destructive-delete behaviour (the row survives with `deleted_at` set / the embed reads back null / the archived row stays selectable) in `backend/README.md`, as part of the slice — so "verified" is durable, not a one-off run.

## Naming
- RPC functions: `verb_noun` snake_case — `get_*`, `list_*`, `create_*`, `upsert_*`, `soft_delete_*`, `submit_*`. Internal helpers: `_leading_underscore`.

## Not now (add only when a slice needs it)
- **Auth (GoTrue):** the first slices can be local / anonymous; add logins when a slice actually needs per-user data.
- **Realtime, storage, full-text search:** YAGNI until proven needed.
