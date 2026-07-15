# red-team — memory

> Transition tracker, **curated in place at `/wrapup`** — never a dated log (history is in git).
> This file is a **small index**: the real content is the protected threat-vector → coverage matrix
> in `topics/attack-surface.md`. Keep the matrix there; keep this file tiny.

## Topic pointer
- [attack-surface](topics/attack-surface.md) — the threat-vector → coverage matrix
  (`Vector | Surface | Covered by | Status`). Read it first, update it after every review.

## Durable knowledge (stable facts for this project)
- **Pre-auth phase (issue #3), post-lockdown (Decision 36, `20260715120000`).** CLOSED: direct anon
  writes (RPC is sole write path on all 5 mutable tables) and RPC EXECUTE-to-PUBLIC (revoked on all
  21). A NEW table re-opening a direct anon write path, or a NEW RPC re-granting PUBLIC execute, is
  now a REAL finding. STILL INFO/expected: anon/authenticated READ any live row; no owner-scoping.
  **No auth is planned — single-user + tailnet-only, login is WON'T-DO (Decision 37)** — so
  owner-scoping / cross-user rows are `N/A (no auth, D37)`, not "pending"; they flip to CRITICAL/ISSUE
  only IF that decision is ever revisited (shared / publicly exposed / multi-tenant).
- **No E2E/Playwright suite.** "Covered" = a by-hand curl, a widget test in `test/`, or an
  integration test exists — not a spec. Recommend those; never map to specs.
- **Highest-value vector reachable today:** soft-delete must be non-destructive (soft-deleted
  `event_type` → event embeds `event_types` as `null`; the row survives with `deleted_at` set).

## Recurring failure modes (none yet)

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Linchpin soft-delete/RLS verification curl run live but not recorded in `backend/README.md` (I re-raise it every RLS slice) | #13 → #19 | 2 | 3a87cc8 | PROMOTED → `docs/database.md` #11 (`4911243`); recorded for event_comments in `backend/README.md` |

## Positive signals (none yet)
- _(none yet)_

## Known false-positive traps
- **drop-then-recreate RPC is correct**, not a data-loss vector — this project changes RPC signatures
  via `drop function if exists …; create or replace …`. Read the latest definition before flagging.
- **The pre-lockdown `revoke execute … from public` gap** (every RPC before Decision 36) was
  `db-security-reviewer`'s tracked ISSUE — it is now SWEPT/CLOSED (`20260715120000`), so don't re-raise
  the *historical* gap. **But a NEW RPC that re-grants PUBLIC execute post-D36 IS a real finding** —
  the "don't re-raise" suppression applies only to the already-closed pre-lockdown gap.
