#!/bin/bash
# Runs ONCE, on a fresh Postgres data volume (docker-entrypoint-initdb.d).
# 1) create the PostgREST role structure, 2) apply forward-only migrations in
# order, 3) load dev seed data. Re-run from scratch with: docker compose down -v.
set -euo pipefail

echo "[init] creating PostgREST roles (authenticator -> anon / authenticated)"
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
	create role anon nologin noinherit;
	create role authenticated nologin noinherit;
	create role authenticator noinherit login password '${AUTHENTICATOR_PASSWORD}';
	grant anon to authenticator;
	grant authenticated to authenticator;
	grant usage on schema public to anon, authenticated;
EOSQL

echo "[init] applying migrations"
for f in /migrations/*.sql; do
	echo "[init]  -> ${f}"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f "$f"
done

if [ -f /seed/seed.sql ]; then
	echo "[init] loading dev seed"
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /seed/seed.sql
fi

echo "[init] done"
