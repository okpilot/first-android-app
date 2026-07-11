# Attack-surface matrix — red-team (First Android App)

> **Protected topic file — never pruned, never inlined into MEMORY.md.** The threat-vector →
> coverage matrix. Update it in place after every red-team review: add new vectors the diff
> introduces, update `Covered by` when a check is recommended/lands, and transition `Status`.
> `Status` legend: `INFO pre-auth` (expected #3) · `gap` (reachable, no check) · `covered`
> (a curl/widget/integration check exists) · `pending (auth #3)` (goes live when auth lands).

## Current vectors (pre-auth — seeded 2026-07)

| Vector | Surface | Covered by | Status |
|---|---|---|---|
| anon full CRUD over live rows | `anon` can read/insert/update/delete any non-deleted row via PostgREST, bypassing the RPCs | anon-scope curl (recommended, documents posture) | INFO pre-auth (#3) — expected, not an attack |
| RPC EXECUTE granted to PUBLIC | Postgres default `EXECUTE` to `PUBLIC` on `SECURITY DEFINER` RPCs; `grant … to anon` is additive, not a lock-down | `db-security-reviewer` ISSUE at the gate; `revoke execute … from public` sweep | INFO pre-auth (#3) — its sweep, not a red-team attack |
| Soft-delete → hard-delete | Three `soft_delete_*` RPCs live (contact, event, event_type) — all `update … set deleted_at = now() where … deleted_at is null`, no `DELETE`. Must flag, not erase | soft-delete-doesn't-hard-delete curl: after RPC, `select … where id=…` still returns the row with `deleted_at` set — **NOT yet written** (backend/README.md has only a contacts `select` curl) | **gap** — recommend the survives-with-deleted_at curl for all three RPCs |
| Soft-deleted type → dangling embed | Soft-deleting an `event_type` must make `events?select=…,event_types(…)` embed `null` (type_id FK has NO on-delete; row hidden by SELECT policy, not gone) | Client tolerance **covered** by `test/event_test.dart` (null embed → `Event.type == null`, lines 104-122; null contact embed skipped, lines 54-63). DB-layer producing the null: **NOT** documented by curl | **partial** — client covered; recommend the DB embed-returns-null curl |
| RLS present on new table | A new `create table` reachable by `anon` without RLS = unfiltered exposure | `db-security-reviewer` static check; red-team confirms the *surface* | covered (hygiene) — red-team maps the anon surface |
| Cross-user data access | User A reads/mutates user B's rows | — | pending (auth #3) — flips to CRITICAL/ISSUE when auth lands |
| Owner-scoping | RPC/policy scopes rows to the caller (`auth.uid()`) | — | pending (auth #3) — flips to ISSUE when auth lands |
| event_attendees hard-DELETE via update_event | `update_event` runs `delete from event_attendees where event_id = p_id` to replace the set (annotated exception, database.md #4 — membership is derived). Guarded: bails with `no_data_found` if the event is unknown/soft-deleted, so a hidden event's set can't be silently rewritten | The `if not found` guard is the control; no curl asserts it. Pre-auth anon can already call it | INFO pre-auth (#3) — intended design + guarded; not an attack today |

## Notes
- **Phase flip to watch:** when an `auth`-schema function appears (or the fixed auth-file list
  changes), move `cross-user data access` and `owner-scoping` from `pending (auth #3)` to required
  checks (recommend an integration/curl check that A can't reach B's rows) and downgrade the two INFO
  pre-auth rows only if the posture actually changes.
