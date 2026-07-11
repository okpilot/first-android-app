# Backend — trimmed Supabase (local dev)

The Supabase-shaped data layer for the app, run **locally** for development:
**Postgres + PostgREST + a Caddy gateway** (giving the `/rest/v1` path so
`supabase_flutter` works unmodified). GoTrue (auth) is deferred to the first auth slice.
This mirrors what will run on `homebase` in `okpilot/selfhost` behind the existing Caddy.

See `docs/decisions.md` (Decisions 5 & 10) and `docs/database.md` for the rules.

## One-time
```bash
cd backend
./gen-env.sh          # writes .env (gitignored) + ../dev-defines.json with a matching anon key
```

## Run
```bash
cd backend
docker compose up -d          # first run applies migrations + seed on a fresh volume
docker compose logs -f db     # watch [init] lines
docker compose down           # stop (keeps data)
docker compose down -v        # stop + wipe (re-inits from migrations/ + seed.sql on next up)
```

Gateway: <http://localhost:8000> · data path `/rest/v1/…` · Postgres on `127.0.0.1:5433`.

## Smoke test
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "http://localhost:8000/rest/v1/contacts?select=name&order=name"
```

## Verify: event comments (viewable soft-delete, no RPC)
`event_comments` is the one table whose SELECT policy is `using (true)`, so archived
(`deleted_at IS NOT NULL`) rows stay readable — that's the "show archived" feature, and it's
also why archive/edit/unarchive are plain direct UPDATEs (the archived row survives PostgREST's
RETURNING re-check, so no `soft_delete_*` RPC is needed here). These curls prove archiving is
**non-destructive** and that there's no hard-delete surface:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
EID=$(curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?select=id&limit=1" | python3 -c 'import sys,json;print(json.load(sys.stdin)[0]["id"])')
# insert a comment (direct, no RPC)
CID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  "$REST/event_comments" -d "{\"event_id\":\"$EID\",\"body\":\"hello\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)[0]["id"])')
# archive (set deleted_at) — the row comes back (no 42501), proving the direct UPDATE works
curl -s -X PATCH -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" -H "Prefer: return=representation" \
  "$REST/event_comments?id=eq.$CID" -d '{"deleted_at":"2026-07-11T12:00:00Z"}'
# the archived row is STILL selectable with deleted_at set (not erased) — the feature
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID&select=id,body,deleted_at"     # -> row present, deleted_at non-null
# guards: empty body rejected, and anon has no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/event_comments" -d "{\"event_id\":\"$EID\",\"body\":\"   \"}"  # -> 400
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID"                                # -> 401 (no delete grant)
```

## Layout
```text
docker-compose.yml   db + rest + gateway
gen-env.sh           writes .env + dev-defines.json (dev secrets, gitignored)
.env.example         template (safe to commit)
init/init.sh         runs once on a fresh volume: roles -> migrations -> seed
migrations/*.sql     forward-only, timestamped. Never edit one that has run; add a new one.
seed.sql             dev-only sample data (not a migration)
caddy/Caddyfile      /rest/v1 -> PostgREST, + permissive CORS for the Flutter web target
```

## Conventions in play (docs/database.md)
- RLS on `contacts`; anon may read/insert/update **non-deleted** rows (no auth yet).
- **Soft-delete only** — no hard `DELETE` grant. Deletes go through the
  `soft_delete_contact(uuid)` `SECURITY DEFINER` RPC (a direct UPDATE of `deleted_at`
  fails the SELECT policy via PostgREST's RETURNING — that's why the RPC exists).
- `updated_at` is bumped by a trigger on every update.
- **`event_comments` is the exception to "soft-deleted = hidden":** its SELECT policy is
  `using (true)` so archived comments stay readable (the "show archived" toggle). Because the
  archived row survives the RETURNING re-check, archive/unarchive/edit are plain direct UPDATEs —
  no `soft_delete_*` RPC (see the verify block above). Still no hard-`DELETE` grant.

## To homebase (later)
Move this stack into `okpilot/selfhost/stacks/`, drop the local Caddy gateway (the
existing homebase Caddy adds the route + TLS), add GoTrue when the auth slice needs it,
and regenerate real secrets — never reuse these dev values.
