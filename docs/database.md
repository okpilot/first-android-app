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
2. **All writes via RPC; reads direct-under-RLS.** Every write (INSERT / UPDATE / soft-delete) goes through a `SECURITY DEFINER` RPC; ordinary reads go direct to the table/view under RLS. One write path per entity is the natural home for `auth.uid()` owner checks when auth (issue #3) lands. *(Updated 2026-07-12, **Decision 26** — a knowing re-reversal of the prior "RPC for what matters, not everything is RPC" wording: uniformity + the auth payoff won over case-by-case. **Migration complete:** `events`, `contacts`, `event_types` and `event_comments` all write via RPC. Rule #4's `event_comments` entry below is now only about its `using (true)` read policy, not its write path.)* *(Hardened 2026-07-15, **Decision 36** — the RPC is now the **sole** write path, not just the convention: `20260715120000_preauth_lockdown.sql` revoked anon's direct `insert/update` grants + dropped the direct write RLS policies on all five still-open tables, and revoked `EXECUTE … from public` on every SECURITY DEFINER RPC. `auth.uid()` owner checks + `SET search_path = ''` hardening (rule #6) remain the only open #3 items.)* **Client-side arity rule:** a Dart model's `toRpcParams()` must send **exactly** the params its target `create_*` RPC declares — the repo blind-spreads `{...toRpcParams()}` into `create`, so an extra or missing key is a runtime **PostgREST PGRST202** (function-not-found), invisible to `flutter analyze` and the hooks. A narrower or different-arity write (a body-only `update`, or `is_done` that only `update` carries) builds an **explicit** param map in the repo (e.g. `{p_id, p_body}` / `{p_id, p_title, p_is_done}`), never a spread. *(learner count 2: `update_comment` `1e7574d`, `create_task` `258cb6c`.)*
3. **Idempotency.** Retryable writes use `ON CONFLICT DO NOTHING / DO UPDATE`.
4. **Soft-delete by default.** Mutable tables get `deleted_at timestamptz NULL` (+ optionally `deleted_by`). No hard `DELETE` except explicitly-annotated exceptions (ephemeral / immutable-fact tables). Read policies filter `deleted_at IS NULL`. **Exception — `event_comments`, `task_comments` and `tasks` (reads only):** their SELECT policy is `using (true)`, not `using (deleted_at is null)`, so archived rows stay readable under a UI "view archived" toggle/section. This breaks the usual soft-delete-means-hidden rule *because* viewing archived items is a feature, not a bug (event comments: Decision 23; tasks: Decision 27; task comments: Decision 33 / Slice 2b). *(Their **writes** are no longer an exception: as of Decision 26 / Slice 3 for event comments — and by construction for `task_comments`, born on the RPC path — add/edit/archive/unarchive route through the `create_*_comment` / `update_*_comment` / `soft_delete_*_comment` / `restore_*_comment` RPCs like every other table, for uniformity, since the `using (true)` policy means there was never a 42501 RETURNING re-check forcing a direct write here.)* *(Server-side archived-parent guard added 2026-07-15, **Decision 36**: the four `task_comment` RPCs now also require the **parent task** be live (`tasks.deleted_at is null`), so an archived task's comment log is frozen server-side — the client already enforced this via `CommentsSection.readOnly`.)* **Join table hard-delete exception — `task_contacts` and `event_attendees` (not for soft-delete rationale, but for atomicity):** membership in these many-to-many tables is **derived and mutable** (not a soft-deletable entity with its own lifecycle). On an update-and-replace the old membership rows are hard-DELETEd as part of the atomic `create_*`/`update_*` RPC body, never soft-deleted. The cascade FK (`on delete cascade`) is a safety net, not the normal path (the parent tables are soft-deleted, not hard-deleted). This is **not** a soft-delete exception — these tables have no `deleted_at` column at all.*
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
