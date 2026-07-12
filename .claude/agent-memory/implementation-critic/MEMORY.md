# implementation-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring
> implementation deviations vs the approved plan for THIS project so future pre-commit reviews
> focus where builds actually drift. Curated at `/wrapup`.

## Recurring deviations (none logged yet)
_First run pending. Seed watch-items carried from the project's conventions:_
- After an `await` in a `State`, is there `if (!mounted) return` before touching `context`/`setState`?
- `startMin`/`endMin` math — right unit (minutes from midnight, `0..1439`), both null iff `allDay`?
- Nullable model fields dereferenced without a guard (`Event.startMin`/`endMin`/`type`, `Contact.dob`)?
- Repository/model signature change → is the hand-written `_FakeXRepo` in `test/` updated too?
- Fallbacks match sibling code (`EventType` bad-hex → `#888888`; `toWrite()` empty → null)?
- `FutureBuilder` screens keep the `_lastData` stale-guard (failed refresh keeps stale data)?

## Positive signals
- Event-comments slice (2026-07-11): clean pre-commit review, 0 blocking. `_CommentsSection`
  faithfully mirrored the `event_types_screen.dart` `_load`/`_lastData`/`identical(future,_future)`
  stale-guard; `_run` captured `ScaffoldMessenger` before every await + re-checked `mounted`;
  `edit` sent `toWrite()` (event_id+body only, deleted_at untouched → can't accidentally
  (un)archive); migration matched plan (`select using(true)`, no delete grant, trigger reuse).
  When a new stateful list/section copies an existing green screen's load pattern verbatim, the
  stale-guard/mounted checks tend to be right — verify the copy is faithful rather than re-deriving.

- PostgREST reload-after-migrate slice (2026-07-12, `fix/postgrest-reload-after-migrate`): clean
  pre-commit review, 0 blocking. Bash + docs only (no Dart). `deploy-homebase.sh` sends
  `notify pgrst, 'reload schema';` piped over STDIN through `psql_remote` (docker exec -i), guarded
  `applied > 0`. Verified: single quotes survive inside the double-quoted `printf` arg; `pgrst`
  channel + `reload schema` payload is PostgREST's documented schema-cache signal; STDIN pipe dodges
  the ssh→docker→psql `-c` word-split the file already warns about (lines 32-40); NOTIFY commits at
  DB regardless of LISTEN so `set -euo pipefail`+`ON_ERROR_STOP=1` can't abort the deploy. Decision 25
  appended (not rewritten). For infra/bash slices, trace the quoting through every shell hop and
  confirm the NOTIFY channel/payload against PostgREST's contract rather than eyeballing it.

- Contacts write-RPCs slice (2026-07-12, `feat/contacts-write-rpcs`, Decision 26 Slice 1): clean
  pre-commit review, 0 blocking. Straight port of the `20260709120200_event_write_rpcs.sql` /
  `SupabaseEventsRepository` template to contacts. Verified the port matched rather than re-deriving:
  `create_contact`/`update_contact` are `security definer` + `set search_path = public`, server-side
  `trim(p_name)` + `nullif(trim(...),'')`, update guards `deleted_at is null` + raises `no_data_found`,
  fully-typed grants — byte-for-byte posture of the event RPCs. Repo `id as String` cast + `_fetchOne`
  re-select mirror the events repo exactly (server timestamps via `Contact.fromJson`). `toRpcParams`
  matches `Event.toRpcParams` posture (p_name trimmed, optional fields raw → server normalizes);
  `ymd` still imported/used for p_dob; `_emptyToNull` + `toWrite` fully removed with no orphaned
  `Contact` caller (grep: remaining `toWrite` hits are `EventType`/`Comment`, the not-yet-converted
  Slice 2/3 entities). Migration is a genuinely NEW function (single def, no CREATE OR REPLACE chain).
  docs rule #2 re-reversal is dated + scoped with the migration-in-progress caveat; `event_types`
  doc-comment correctly dropped "like contacts" and now cites the completed conversion. Lesson: when a
  slice is an explicit port of a green template, diff the two side-by-side and confirm the divergences
  are only the entity-specific ones (no attendees array, no all_day CASE) — the rest should match.

- Event-types write-RPCs slice (2026-07-12, `feat/event-type-write-rpcs`, Decision 26 Slice 2): clean
  pre-commit review, 0 blocking. Third straight port of the same template (events→contacts→event_types).
  Verified by side-by-side diff vs Slice 1: `create_event_type(p_name,p_color)` /
  `update_event_type(p_id,p_name,p_color)` are `security definer` + `set search_path = public`,
  server-side `trim(p_name)`, update guards `deleted_at is null` + raises `no_data_found`; grant
  signatures `(text,text)` / `(uuid,text,text)` match the function param lists exactly. Genuinely NEW
  function (single def, no CREATE OR REPLACE chain to resolve). Repo: interface unchanged (fakes in
  `event_types_screen_test.dart` untouched, correct), `id as String` cast + `_fetchOne` re-select
  mirror contacts, `_fetchOne` selects `_columns='id, name, color'` (event_types keeps an explicit
  column list vs contacts' bare `.select()` — pre-existing, correct). `toWrite`→`toRpcParams` rename
  fully swept: only remaining `toWrite` hits are `Comment` (the not-yet-converted Slice 3 entity).
  Rule-reversal-sync honoured: database.md rule #2 parenthetical + BOTH stale headers
  (`create_event_types.sql`, `soft_delete_event_type_rpc.sql`) corrected in-slice, README verify curl
  added. Lesson reinforced: for an explicit template port, diff the two files side-by-side and confirm
  divergences are only entity-specific (fewer params, no nullif normalization needed since event_types
  has no optional text fields) — the security posture must be byte-for-byte.

- App-icon/name slice (2026-07-11, `slice/app-icon-and-name`): clean pre-commit review, 0 blocking.
  Config/asset-only (no Dart). Verified the way that actually catches the trap: decode the PNG alpha,
  don't trust colortype. Adaptive foreground (`crm-plus-dark-fg-1024.png` + generated
  `ic_launcher_foreground.png`) had corner alpha=0 = transparent glyph; legacy tile
  (`crm-plus-dark-1024.png`) corner alpha=255 rgb(10,10,10)=#0a0a0a opaque — correct split. colors.xml
  `#0a0a0a` matched `adaptive_icon_background`; anydpi-v26 refs resolved. For icon slices, pixel-sample
  corner-vs-center alpha rather than reading the SVG or PNG header alone.

- PostgREST DDL-watch triggers slice (2026-07-12, `slice/pgrst-ddl-watch`): clean pre-commit review,
  0 blocking. SQL-only migration (`20260712120000_pgrst_ddl_watch.sql`). Verified: `notify pgrst,
  'reload schema'` on `ddl_command_end` + `sql_drop` event triggers is the canonical Supabase
  auto-reload mechanism; `execute function` (not `execute procedure`) is valid PG11+ / correct on
  homebase's postgres:16; one shared `returns event_trigger` function on both triggers is valid;
  `create or replace` + `drop event trigger if exists; create event trigger` applies cleanly on a
  fresh DB and re-applies safely; `set search_path = ''` (not `= public`) is right here because the
  body only NOTIFYs and references zero schema objects — rule #6's `= public` governs SECURITY
  DEFINER *client-facing* fns, not an internal non-definer event trigger. Timestamp orders after
  20260711120000. Plan honoured: triggers ONLY; manual reload in `backend/deploy-homebase.sh` left
  intact (removal deferred to follow-up). Only runtime caveat = PostgREST needs `db-channel-enabled`
  (default true) + channel `pgrst` — that's config, not a migration defect, and the plan already
  gates the deploy-script change on verifying auto-reload on homebase first. For event-trigger
  migrations: confirm `returns event_trigger`, `execute function`, and that `search_path=''` is safe
  only when the body touches no objects.

## Durable, verified facts (load-bearing)
- **`CREATE EVENT TRIGGER` does NOT fire `ddl_command_end`** (proven locally on postgres:15/16:
  creating a second event trigger while `pgrst_ddl_watch` was active emitted no NOTICE; only
  `CREATE TABLE` did). Consequence: the `20260712120000_pgrst_ddl_watch.sql` migration emits ZERO
  `NOTIFY pgrst` during its OWN application. On a FRESH homebase where PostgREST is already up with
  an empty cache, applying all migrations does not reload it — every endpoint 404s until a
  `docker restart firstapp-postgrest` (or the next DDL). This is why `deploy-homebase.sh` keeps a
  single UNCONDITIONAL `notify pgrst` at the end as a cold-start net (the triggers own the
  running/steady-state + ad-hoc-psql case; the script one-liner owns fresh-DB cold start). General
  lesson: when a slice removes a "redundant" reload/refresh, check the cold-start/first-load path,
  not just the steady state.

## Known false-positive traps (do not flag these)
- An internal event-trigger / NOTIFY-only function pinning `set search_path = ''` (not `= public`)
  is CORRECT — rule #6's `= public` is for SECURITY DEFINER client-facing RPCs. Don't demand `=
  public` on a non-definer function that references no schema objects.
- Missing `auth.uid()` / login checks are expected pre-auth (issue #3) — not a defect.
- `with check (true)` policies and RPCs granted to `anon` are intentional pre-auth.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a dropped-function regression.
- Hard `DELETE` on the annotated `event_attendees` join is allowed; soft-delete is only required
  on mutable entity tables.
