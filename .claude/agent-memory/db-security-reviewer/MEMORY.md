# db-security-reviewer — memory

> Transition tracker, curated in place (never raw secrets, never a dated session log). Records
> recurring DB-security patterns for THIS project. Curated at `/wrapup`.

## Project phase (flip these as issue #3 progresses)
- **Auth (GoTrue): NOT wired.** `auth.uid()` owner checks → **INFO, tracked under #3**, not a
  blocker. `with check (true)` is intentional pre-auth. When #3 lands, flip the `auth.uid()` rule
  from INFO → ISSUE and update this line.

## Known project-wide gaps (tracked under #3 — DEFER acceptable until #3 lands)
- **`revoke execute … from public` is missing on every RPC.** Postgres grants EXECUTE to PUBLIC
  by default and no migration revokes it. Flag on each NEW RPC (ISSUE, ref #3); DEFER to the #3
  sweep is fine while #3 is open.

## Confirmed-good baseline patterns (regression guards — flag if a NEW migration breaks them)
- Every table enables RLS in the same migration as `create table`.
- Every `SECURITY DEFINER` function sets `search_path = public`.
- Mutable tables soft-delete (`deleted_at`); read policies filter `deleted_at is null`. Hard
  DELETE only on the annotated `event_attendees` join.
  - **Documented exception — `event_comments`** (database.md #4, Decision 23): SELECT/UPDATE use
    `using (true)`, NOT `deleted_at is null`, so archived comments stay readable and
    archive/unarchive/edit are plain direct UPDATEs (no soft-delete RPC). Still soft-delete only —
    no DELETE grant/policy, body `check (length(trim(body)) > 0)` blocks blanking. Do NOT flag its
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
