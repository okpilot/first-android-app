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
- `FORCE ROW LEVEL SECURITY` is deliberately NOT used (would break the SECURITY-DEFINER soft-delete
  bypass) — do not require it.

## False positives raised (none yet)
_None._
