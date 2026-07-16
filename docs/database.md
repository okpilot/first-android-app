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
2. **All writes via RPC; reads direct-under-RLS.** Every write (INSERT / UPDATE / soft-delete) goes through a `SECURITY DEFINER` RPC; ordinary reads go direct to the table/view under RLS. One write path per entity would be the natural home for `auth.uid()` owner checks — but auth is **WON'T-DO (Decision 37)**: single-user + tailnet-only, no login planned (see rule #6). *(Updated 2026-07-12, **Decision 26** — a knowing re-reversal of the prior "RPC for what matters, not everything is RPC" wording: uniformity + the auth payoff won over case-by-case. **Migration complete:** `events`, `contacts`, `event_types` and `event_comments` all write via RPC. Rule #4's `event_comments` entry below is now only about its `using (true)` read policy, not its write path.)* *(Hardened 2026-07-15, **Decision 36** — the RPC is now the **sole** write path, not just the convention: `20260715120000_preauth_lockdown.sql` revoked anon's direct `insert/update` grants + dropped the direct write RLS policies on all five still-open tables, and revoked `EXECUTE … from public` on every SECURITY DEFINER RPC. `auth.uid()` owner checks are **WON'T-DO (Decision 37)**; only the optional `SET search_path = ''` hardening (rule #6) remains. Issue #3 is now **closed**.)* *(**Recreate invariant, Decision 38** — a `drop function … ; create or replace …` signature change on a client-facing RPC **discards the old function's ACL** and the new one gets Postgres's default **PUBLIC execute** back. So any post-lockdown signature bump MUST re-issue BOTH `revoke execute … from public` AND `grant execute … to anon, authenticated` on the **new** signature, in the same migration — else the RPC silently reopens to PUBLIC. `add_importance_to_tasks.sql` does this; verify with `has_function_privilege('public', oid, 'execute') = false`.)* **Client-side arity rule:** a Dart model's `toRpcParams()` must send **exactly** the params its target `create_*` RPC declares — the repo blind-spreads `{...toRpcParams()}` into `create`, so an extra or missing key is a runtime **PostgREST PGRST202** (function-not-found), invisible to `flutter analyze` and the hooks. A narrower or different-arity write (a body-only `update`, or `is_done` that only `update` carries) builds an **explicit** param map in the repo (e.g. `{p_id, p_body}` / `{p_id, p_title, p_is_done}`), never a spread. *(learner count 2: `update_comment` `1e7574d`, `create_task` `258cb6c`.)* **Idempotent-create template (Decision 41 / issue #9, 2026-07-16):** every `create_*` takes a trailing optional `p_id uuid default null`, computes `v_id := coalesce(p_id, gen_random_uuid())`, inserts the id **explicitly** with `on conflict (id) do nothing`, and returns `v_id` — so a retry with the same id is a no-op, not a duplicate row (the repo's `_fetchOne(v_id)` returns the row either way). The **client mints the id up front** (`lib/util/ids.dart` `newEntityId()`, in each model's `.draft`) and each form holds one id across re-taps; `p_id` therefore rides in `toRpcParams()` (so `update_*`, which already declares `p_id`, reuses the same map). `create_task_comment` keeps its archived-parent guard folded into the insert and disambiguates a conflict-skip from a rejected parent with a post-insert `if not exists (… id = v_id) then raise`. A new `create_*` that server-mints without `p_id`/`on conflict` is a regression.
3. **Idempotency.** Retryable writes use `ON CONFLICT DO NOTHING / DO UPDATE`.
4. **Soft-delete by default.** Mutable tables get `deleted_at timestamptz NULL` (+ optionally `deleted_by`). No hard `DELETE` except explicitly-annotated exceptions (ephemeral / immutable-fact tables). Read policies filter `deleted_at IS NULL`. **Exception — `event_comments`, `task_comments` and `tasks` (reads only):** their SELECT policy is `using (true)`, not `using (deleted_at is null)`, so archived rows stay readable under a UI "view archived" toggle/section. This breaks the usual soft-delete-means-hidden rule *because* viewing archived items is a feature, not a bug (event comments: Decision 23; tasks: Decision 27; task comments: Decision 33 / Slice 2b). *(Their **writes** are no longer an exception: as of Decision 26 / Slice 3 for event comments — and by construction for `task_comments`, born on the RPC path — add/edit/archive/unarchive route through the `create_*_comment` / `update_*_comment` / `soft_delete_*_comment` / `restore_*_comment` RPCs like every other table, for uniformity, since the `using (true)` policy means there was never a 42501 RETURNING re-check forcing a direct write here.)* *(Server-side archived-parent guard added 2026-07-15, **Decision 36**: the four `task_comment` RPCs now also require the **parent task** be live (`tasks.deleted_at is null`), so an archived task's comment log is frozen server-side — the client already enforced this via `CommentsSection.readOnly`.)* **Join table hard-delete exception — `task_contacts`, `event_attendees` and `task_category_links` (not for soft-delete rationale, but for atomicity):** membership in these many-to-many tables is **derived and mutable** (not a soft-deletable entity with its own lifecycle). On an update-and-replace the old membership rows are hard-DELETEd as part of the atomic `create_*`/`update_*` RPC body, never soft-deleted. The cascade FK (`on delete cascade`) is a safety net, not the normal path (the parent tables are soft-deleted, not hard-deleted). This is **not** a soft-delete exception — these tables have no `deleted_at` column at all.*
5. **RLS on every table**, enabled in the SAME migration as `CREATE TABLE`. `USING` for reads; `WITH CHECK` on write policies.
6. **SECURITY DEFINER functions** always `SET search_path = public`. ~~client-facing ones check `auth.uid()` once auth is wired~~ — **there is NO auth: single-user + tailnet-only is the boundary, login is WON'T-DO (Decision 37).** So `auth.uid()`/owner-RLS is out of scope, not deferred. The `SET search_path = ''` hardening (rule #2's Decision 36 note) is the only remaining optional #3 item.
7. **Standard columns** (usual, not dogma): `id uuid primary key default gen_random_uuid()`, `created_at timestamptz not null default now()`, `updated_at` only where rows mutate.
8. **Constraints live in the DB**, not just the app: FK / NOT NULL / CHECK / UNIQUE.
9. **Pagination = LIMIT/OFFSET, default page size 10**, total via `count(*) OVER()`. (Keyset only later, if a list proves it needs it.)
10. **Migrations are forward-only**, timestamped `YYYYMMDDHHMMSS_description.sql` (Supabase CLI format). Never edit a pushed migration — add a new one.
11. **Record the linchpin verification curl(s).** Any RLS / soft-delete-touching slice records the curl(s) that prove its non-destructive-delete behaviour (the row survives with `deleted_at` set / the embed reads back null / the archived row stays selectable) in `backend/README.md`, as part of the slice — so "verified" is durable, not a one-off run.

## task_categories (Decision 39, Slice A) + task_category_links (Decision 40, Slice B)
### Slice A — entity + manager
A user-owned tag taxonomy for tasks, separate from `event_types`. Table: `id`, `name`
(`check length(trim(name)) > 0`), `color` (`check color ~ '^#[0-9A-Fa-f]{6}$'`, 6-digit #RRGGBB,
DB-authoritative), `created_at`/`updated_at` (bumped by the shared `set_updated_at` trigger),
`deleted_at` (soft-delete). **Created after the Decision 36 lockdown, so RPC-only from day one:**
RLS `SELECT`-only for `anon, authenticated` `using (deleted_at is null)`, `grant select` only — no
insert/update policy or grant. The 3 write RPCs — `create_task_category(p_name, p_color)`,
`update_task_category(p_id, p_name, p_color)` (guards `deleted_at is null`, raises `no_data_found`),
`soft_delete_task_category(p_id)` — follow the full lockdown discipline: `SECURITY DEFINER`,
`SET search_path = public`, `revoke execute … from public`, `grant execute … to anon, authenticated`.

### Slice B — the join (many-per-task)
The `task_category_links` join table mirrors `task_contacts`: composite PK on `(task_id,
category_id)`, both FKs `on delete cascade`, no timestamps or `deleted_at` (membership is derived,
not a soft-deletable entity). Reverse index on `category_id` (so "which tasks carry this category?"
doesn't scan). RLS `SELECT` policy `using (true)` — not a parent-live gate (archived tasks stay
embeddable, their category roster comes along; a soft-deleted category → embedded null when RLS
hides it, client skips). No write policy/grant — membership set only by RPCs.

**Task write RPC signatures (Slice B changes, via drop+recreate):**
- `create_task(p_title text, p_notes text default null, p_contacts uuid[] default '{}', p_importance smallint default 0, p_categories uuid[] default '{}')` → `uuid`. New: unnest-insert categories, same pattern as contacts.
- `update_task(p_id uuid, p_title text, p_is_done boolean, p_notes text, p_contacts uuid[], p_importance smallint, p_categories uuid[])` → `uuid`. **No defaults on `p_contacts`, `p_importance`, or `p_categories` — defensive rule (update omits one → silent wipe → PGRST202 instead).** Deletes + reinserts the category membership, same pattern as contacts.

**Lockdown invariant (Decision 36):** dropping the old sigs discarded the PUBLIC revoke, and recreate
hands it back; the migration **re-issues both** the `revoke execute … from public` AND the
`grant … to anon, authenticated` on the new sigs.

Verify curls: `backend/README.md` → "Verify: task category write RPCs".

## Naming
- RPC functions: `verb_noun` snake_case — `get_*`, `list_*`, `create_*`, `upsert_*`, `soft_delete_*`, `submit_*`. Internal helpers: `_leading_underscore`.

## Not now (add only when a slice needs it)
- **Auth (GoTrue): WON'T-DO (Decision 37).** Single-user + tailnet-only is the security boundary; there is no per-user data to scope, so no login is planned. Revisit only if the app is ever shared, exposed beyond the tailnet, or made multi-tenant.
- **Realtime, storage, full-text search:** YAGNI until proven needed.
