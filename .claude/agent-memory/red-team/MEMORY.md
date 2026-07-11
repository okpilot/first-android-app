# red-team — memory

> Transition tracker, **curated in place at `/wrapup`** — never a dated log (history is in git).
> This file is a **small index**: the real content is the protected threat-vector → coverage matrix
> in `topics/attack-surface.md`. Keep the matrix there; keep this file tiny.

## Topic pointer
- [attack-surface](topics/attack-surface.md) — the threat-vector → coverage matrix
  (`Vector | Surface | Covered by | Status`). Read it first, update it after every review.

## Durable knowledge (stable facts for this project)
- **Pre-auth phase (issue #3).** `anon` full CRUD, RPC EXECUTE to `PUBLIC`, and no owner-scoping are
  EXPECTED → INFO, not attacks. Owner-scoping / cross-user rows flip to CRITICAL/ISSUE once auth lands.
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
- **`revoke execute … from public` gap** is `db-security-reviewer`'s ISSUE at the gate — INFO/#3 here,
  do not re-raise it as an attack.
