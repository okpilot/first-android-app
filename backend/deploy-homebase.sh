#!/usr/bin/env bash
# Apply forward-only migrations from THIS repo to the homebase database over the tailnet.
#
# Schema source of truth = backend/migrations/. The homebase `selfhost` stack holds only
# infrastructure (containers + roles); it has NO migrations. This is how a schema change
# reaches production: write a new backend/migrations/NNNN_*.sql, test locally, then run
# this. Applied migrations are tracked in a public._migrations table (forward-only).
#
# Usage:  ./backend/deploy-homebase.sh
# Requires: tailnet SSH to homebase; the firstapp-crm stack running there.
set -euo pipefail
cd "$(dirname "$0")"                       # -> backend/
HOST="${HOMEBASE_SSH:-king@homebase}"
CONTAINER="${HOMEBASE_PG:-firstapp-postgres}"

psql_remote() {
  ssh -o BatchMode=yes "$HOST" docker exec -i "$CONTAINER" \
    psql -v ON_ERROR_STOP=1 -U postgres -d postgres "$@"
}

echo "ensuring _migrations ledger exists on homebase…"
psql_remote -q <<'SQL'
create table if not exists public._migrations (
  name       text primary key,
  applied_at timestamptz not null default now()
);
SQL

applied=0
for f in migrations/*.sql; do
  name="$(basename "$f")"
  # NB: query via STDIN, not `psql -c "…"`. Passing `-c` with a space-containing
  # query through ssh → docker exec → psql gets word-split by the remote shell
  # (the local quotes are already consumed), so the check silently returned empty
  # and every migration was re-applied. Piping over stdin survives all three hops.
  # The name is passed as a psql variable and referenced with :'name' so psql
  # does the SQL quoting — robust even if a filename ever contains a quote (the
  # -v value has no spaces, so it survives the ssh word-split that broke -c).
  exists="$(printf "select 1 from public._migrations where name=:'name';" \
            | psql_remote -tAq -v name="$name")"
  if [ "$exists" = "1" ]; then
    echo "  skip   ${name}"
    continue
  fi
  echo "  apply  ${name}"
  # The trailing `echo` guarantees a newline after the migration body, so a file
  # that ends in a `--` comment can't swallow the ledger insert onto its line.
  { echo "begin;"; cat "$f"; echo; \
    echo "insert into public._migrations(name) values ('${name}'); commit;"; } \
    | psql_remote -q
  applied=$((applied + 1))
done

# Ensure PostgREST's schema cache matches what we just applied.
#
# The PRIMARY reload mechanism is now the pgrst_ddl_watch / pgrst_drop_watch event triggers
# (migration 20260712120000_pgrst_ddl_watch.sql): they fire `NOTIFY pgrst, 'reload schema'` on
# every DDL against a *running* PostgREST — including ad-hoc `psql` DDL applied outside this
# script, which this one-shot reload never covered. Verified live on homebase (a freshly-created
# function was callable via /rpc/ with no manual NOTIFY, and 404'd once dropped).
#
# This single unconditional NOTIFY stays as a cold-start safety net the triggers CANNOT cover:
# on a from-scratch homebase, migrations 1..N build the schema *before* the trigger migration
# installs the triggers, and installing an event trigger does not itself fire ddl_command_end
# (nor does the ledger INSERT) — so a fresh deploy emits zero NOTIFY of its own. Without this
# line a brand-new PostgREST that started with an empty cache would 404 every endpoint until a
# `docker restart firstapp-postgrest`. Piped over STDIN, not `-c`, for the ssh→docker→psql
# word-split reason as the exists-check above. See Decision 25.
echo "reloading PostgREST schema cache (cold-start net; triggers cover the running case)…"
printf "notify pgrst, 'reload schema';" | psql_remote -q

echo "done — ${applied} migration(s) applied to homebase (seed NOT applied; prod starts empty)."
