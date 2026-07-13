# Decision 26 write-RPC ports — semantic review detail

Four straight CLEAN ports of direct INSERT/UPDATE → SECURITY DEFINER RPCs. The reusable 4-check
shape (confirm all four on any future port): (1) server `nullif(trim(...),'')` reproduces the old
client `_emptyToNull` EXACTLY (trimmed value or NULL — no field silently re-normalized); (2) the RPC
writes every human column the old map wrote — none dropped; (3) `id as String` cast is valid because
the RPC `returns uuid` (scalar → JSON string); (4) `_fetchOne`'s `.single()` is correct, NOT a
`maybeSingle` case.

## Contacts (commit 1988e26, Slice 1)
`create_contact`/`update_contact`. Verified behaviorally equivalent, not just structural. `.single()`
correct: the just-written live row is visible under `contacts_select using (deleted_at is null)`, so
0 rows means something went wrong and SHOULD throw. Mirrors `SupabaseEventsRepository` byte-for-byte.

## Event-types (commit 20970ea, Slice 2)
`create_event_type(p_name,p_color)` / `update_event_type(p_id,p_name,p_color)` — single-def NEW
migration (no CREATE OR REPLACE chain). `update` refetches by input `type.id` not the RPC return;
`_fetchOne` `_columns='id, name, color'` == `EventType.fromJson` field set exactly. Legitimate deltas
vs contacts: fewer params, no `nullif` normalization (no optional text fields), explicit column list.

## Comments (commit 3296258, Slice 3 — FINAL)
`create_comment(p_event_id,p_body)` / `update_comment(p_id,p_body)` (body-only → an edit can't move a
comment) / `soft_delete_comment(p_id)` / `restore_comment(p_id)` — single-def NEW migration
(`20260712150000`). `_fetchOne` `_columns='id, event_id, body, created_at, updated_at, deleted_at'`
== `Comment.fromJson` (incl. `deleted_at`→`isArchived`). Guards match UI exactly: update/soft_delete
guard `deleted_at is null`, restore guards `deleted_at is not null`; `no_data_found` raised before
`_fetchOne` → thrown → surfaced by `_run`'s catch→snackbar.
**Key delta — why `.single()` is safe here for a DIFFERENT reason:** under event_comments'
`using (true)` SELECT policy an archived row STAYS selectable, so no concurrent soft/restore can hide
the just-written row from the re-select — strictly safer than contacts/event_types. Do NOT flag it.

## Non-atomic re-fetch is by-design (do NOT flag as a race)
RPC-then-`_fetchOne` is two round-trips (vs the old single `insert…returning`). A concurrent
soft-delete between them would make `.single()` throw instead of returning the row — but that is the
correct error signal, matches the events repo, and is deliberate.
