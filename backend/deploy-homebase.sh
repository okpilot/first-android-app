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
  exists="$(psql_remote -tAq -c "select 1 from public._migrations where name='${name}'")"
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

echo "done — ${applied} migration(s) applied to homebase (seed NOT applied; prod starts empty)."
