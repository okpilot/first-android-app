# db-security-reviewer memory

## Tracker

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Every new SECURITY DEFINER RPC omits `revoke execute … from public` (Postgres grants EXECUTE to PUBLIC by default; the `grant … to anon` is additive, not lock-down) | 2026-07-12 | 2 | 2026-07-12 tasks | WATCHING → DEFER to the issue #3 auth-hardening sweep; consolidated ISSUE, not per-RPC. See [revoke-execute-sweep](topics/revoke-execute-sweep.md) |

## Durable knowledge
- **Phase: pre-auth.** GoTrue not wired. Missing `auth.uid()` owner-scoping = INFO tracked under
  #3, never CRITICAL/ISSUE. `with check (true)` on insert/update is intentional pre-auth — do NOT flag.
  When #3 lands (an `auth`-schema fn exists), flip `auth.uid()` from INFO → ISSUE and mark this here.
- **Project pins `set search_path = public`** (NOT `= ''`) on every SECURITY DEFINER fn — consistent
  across contacts/events/event_types/event_comments/tasks. Regression-guard only.
- **NO `revoke execute` exists in ANY migration** (grep-confirmed 2026-07-12) — project-wide, tracked #3.
- **Two viewable-soft-delete tables** use `using (true)` SELECT (archive stays readable), deliberate,
  documented in-header: `event_comments`, `tasks`. NOT an accident — do not flag. All other tables use
  `using (deleted_at is null)`.
- **Shared trigger fn `public.set_updated_at()`** defined in `20260708120000_create_contacts.sql`;
  it is SECURITY INVOKER — out of scope for the `set search_path` rule (item 3 is DEFINER-only).
- **Hard DELETE** allowed only on derived/ephemeral tables (e.g. `event_attendees` join). On a mutable
  entity table it is CRITICAL. Soft-delete = `update … set deleted_at = now()`.

## Topic pointers
- [revoke-execute-sweep](topics/revoke-execute-sweep.md) — the project-wide PUBLIC-execute gap → #3
