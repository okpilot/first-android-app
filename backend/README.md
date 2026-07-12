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

## Verify: event comment write RPCs (Decision 26, Slice 3)
As of Slice 3, comment writes route through `create_comment` / `update_comment` /
`soft_delete_comment` / `restore_comment` RPCs (for uniformity — this table's `using (true)`
SELECT means a direct write would also work; there's no 42501 to dodge). These curls prove the
RPC write path AND that archiving stays **non-destructive** with no hard-delete surface — the
archived row remains selectable (the "show archived" feature) because SELECT is `using (true)`:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
EID=$(curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?select=id&limit=1" | python3 -c 'import sys,json;print(json.load(sys.stdin)[0]["id"])')
# create: padded body trimmed server-side -> returns the new uuid
CID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_comment" \
  -d "{\"p_event_id\":\"$EID\",\"p_body\":\"  hello  \"}" | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID&select=body"                   # -> body "hello" (trimmed)
# edit (body only): returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_comment" \
  -d "{\"p_id\":\"$CID\",\"p_body\":\"edited\"}"
# archive: sets deleted_at; the row is STILL selectable (using(true)) — the feature
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_comment" -d "{\"p_id\":\"$CID\"}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID&select=id,body,deleted_at"     # -> row present, deleted_at non-null
# restore (unarchive): clears deleted_at back to null
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/restore_comment" -d "{\"p_id\":\"$CID\"}"
# guards: blank body -> check violation; edit of an archived row -> no_data_found; no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_comment" \
  -d "{\"p_event_id\":\"$EID\",\"p_body\":\"   \"}"                # -> 400
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID"                                # -> 401 (no delete grant)
```

## Verify: contact write RPCs (Decision 26, Slice 1)
`create_contact` / `update_contact` are the RPC write path for contacts. These curls prove the
server-side normalization, and — the one genuinely new guard — that `update_contact` refuses a
soft-deleted / absent row (`no_data_found`) rather than silently mutating a hidden row:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create: padded name trimmed, empty email nullified server-side -> returns the new uuid
NID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"  Ada  ","p_dob":null,"p_email":"   ","p_phone":"123","p_company":null,"p_remarks":null}' \
  | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/contacts?id=eq.$NID&select=name,email,phone"             # -> name "Ada", email null, phone "123"
# update: fields change, returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_contact" \
  -d "{\"p_id\":\"$NID\",\"p_name\":\"Bob\",\"p_dob\":null,\"p_email\":\"b@x.io\",\"p_phone\":null,\"p_company\":null,\"p_remarks\":null}"
# blank name -> check violation (contacts_name_check)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"   ","p_dob":null,"p_email":null,"p_phone":null,"p_company":null,"p_remarks":null}'  # -> 400
# the new guard: soft-delete the row, then update_contact on it -> no_data_found (row not resurrected)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_contact" -d "{\"p_id\":\"$NID\"}"
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_contact" \
  -d "{\"p_id\":\"$NID\",\"p_name\":\"X\",\"p_dob\":null,\"p_email\":null,\"p_phone\":null,\"p_company\":null,\"p_remarks\":null}"
  # -> {"code":"P0002", ... "contact <uuid> not found or already deleted"} — the guard rolled back
```

## Verify: event type write RPCs (Decision 26, Slice 2)
`create_event_type` / `update_event_type` are the RPC write path for event types. Same shape as
the contact RPCs — server-side name trim, and `update_event_type` refuses a soft-deleted / absent
row (`no_data_found`):
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create: padded name trimmed -> returns the new uuid
TID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"  Focus  ","p_color":"#4E7BC9"}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_types?id=eq.$TID&select=name,color"                # -> name "Focus", color "#4E7BC9"
# update: rename + recolor, returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_event_type" \
  -d "{\"p_id\":\"$TID\",\"p_name\":\"Deep work\",\"p_color\":\"#22A06B\"}"
# blank name -> check violation (event_types name check)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"   ","p_color":"#4E7BC9"}'                        # -> 400
# malformed colour -> check violation (color ~ '^#[0-9A-Fa-f]{6}$', fires through the RPC)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"Bad","p_color":"red"}'                            # -> 400
# the new guard: soft-delete the row, then update_event_type on it -> no_data_found
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_event_type" -d "{\"p_id\":\"$TID\"}"
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_event_type" \
  -d "{\"p_id\":\"$TID\",\"p_name\":\"X\",\"p_color\":\"#4E7BC9\"}"
  # -> {"code":"P0002", ... "event type <uuid> not found or already deleted"} — the guard rolled back
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
  `using (true)` so archived comments stay readable (the "show archived" toggle). Its **writes**
  are no longer an exception — as of Decision 26 / Slice 3 they route through
  `create_comment` / `update_comment` / `soft_delete_comment` / `restore_comment` RPCs like every
  other table (for uniformity; the `using (true)` policy means there was never a 42501 forcing a
  direct write). Still no hard-`DELETE` grant.

## To homebase (later)
Move this stack into `okpilot/selfhost/stacks/`, drop the local Caddy gateway (the
existing homebase Caddy adds the route + TLS), add GoTrue when the auth slice needs it,
and regenerate real secrets — never reuse these dev values.
