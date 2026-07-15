# db-security-reviewer — memory

> Transition tracker, curated in place (never raw secrets, never a dated session log). Records
> recurring DB-security patterns for THIS project. Curated at `/wrapup`.

## Project phase (flip these as issue #3 progresses)
- **Auth (GoTrue): NOT wired.** `auth.uid()` owner checks → **INFO, tracked under #3**, not a
  blocker. `with check (true)` is intentional pre-auth. When #3 lands, flip the `auth.uid()` rule
  from INFO → ISSUE and update this line.

## Known project-wide gaps (tracked under #3)
- **`revoke execute … from public` — SWEPT & RESOLVED (Decision 36, `20260715120000_preauth_lockdown`).**
  All 21 client-facing SECURITY DEFINER RPCs now revoke PUBLIC execute; the direct anon write path on
  the 5 mutable tables (contacts, event_types, event_comments, tasks, task_comments) is CLOSED (writes
  are RPC-only). No longer deferrable — a NEW RPC missing the revoke, or a NEW mutable table opening a
  direct anon write path, is now a **regression → ISSUE (FIX)**.
- **Post-lockdown add-when-recreating-via-`create or replace`:** replacing a function with
  `create or replace` (no drop) PRESERVES the ACL, so a revoke done in an earlier statement/migration
  survives — do NOT flag a recreated RPC as "lost its revoke". (Verified: lockdown part 3 recreates the
  4 task_comment RPCs after part 2's revoke; revoke survives.)

## Confirmed-good baseline patterns (regression guards — flag if a NEW migration breaks them)
- Every table enables RLS in the same migration as `create table`.
- Every `SECURITY DEFINER` function sets `search_path = public`.
- Mutable tables soft-delete (`deleted_at`); read policies filter `deleted_at is null`. Hard
  DELETE only on the annotated `event_attendees` join.
  - **Documented `using (true)` read exception — THREE tables: `event_comments` (Decision 23),
    `task_comments` (Decision 33 / Slice 2b), `tasks` (reads only, Decision 27)** (database.md #4):
    SELECT (and for the comment tables, UPDATE) use `using (true)`, NOT `deleted_at is null`, so
    archived rows stay readable under a "view archived" toggle. Still soft-delete only — no DELETE
    grant/policy; comment tables' body `check (length(trim(body)) > 0)` blocks blanking. Writes now
    route through `create_/update_/soft_delete_/restore_*` RPCs (Decision 26). Do NOT flag their
    `using (true)` as a missing `deleted_at` filter.
- `FORCE ROW LEVEL SECURITY` is deliberately NOT used (would break the SECURITY-DEFINER soft-delete
  bypass) — do not require it.
- **Event-trigger functions** (`returns event_trigger`, e.g. `public.pgrst_watch`, Decision 25):
  do NOT flag the two headline checks. (a) `revoke execute … from public` is N/A — Postgres
  forbids calling an event-trigger function directly ("cannot be called directly"), it's fired only
  by the trigger mechanism and is not RPC-exposed. (b) `set search_path = ''` (not `= public`) is
  CORRECT, not a rule-#6 miss — rule #6's `= public` is scoped to SECURITY DEFINER; these are
  SECURITY INVOKER, reference no schema objects, so empty search_path is stronger (zero injection
  surface). Not-SECURITY-DEFINER is the right choice — NOTIFY needs no elevated privilege.

## False positives raised (none yet)
_None._
