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
