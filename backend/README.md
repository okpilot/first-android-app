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

## To homebase (later)
Move this stack into `okpilot/selfhost/stacks/`, drop the local Caddy gateway (the
existing homebase Caddy adds the route + TLS), add GoTrue when the auth slice needs it,
and regenerate real secrets — never reuse these dev values.
