#!/usr/bin/env bash
# Writes backend/.env (gitignored) with GENERATED dev secrets + an anon JWT that
# matches JWT_SECRET, and mirrors the anon key into ../dev-defines.json for the
# Flutter client. Requires python3 + openssl.
#
# Secrets are never hard-coded here. First run generates them; re-running reuses the
# existing .env (so a running stack keeps working). To rotate: delete backend/.env,
# run `docker compose down -v`, then re-run this.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .env ]; then
  echo "backend/.env exists — reusing it."
  set -a; . ./.env; set +a
else
  new_env=1
  POSTGRES_PASSWORD="$(openssl rand -hex 24)"
  AUTHENTICATOR_PASSWORD="$(openssl rand -hex 24)"
  JWT_SECRET="$(openssl rand -hex 32)"
fi
: "${POSTGRES_DB:=postgres}"

ANON_KEY="$(python3 - "$JWT_SECRET" <<'PY'
import sys, hmac, hashlib, base64, json
secret = sys.argv[1].encode()
b64 = lambda b: base64.urlsafe_b64encode(b).rstrip(b'=')
header  = b64(json.dumps({"alg":"HS256","typ":"JWT"}, separators=(',',':')).encode())
payload = b64(json.dumps({"role":"anon","iss":"firstapp-dev","iat":1700000000,"exp":2000000000}, separators=(',',':')).encode())
signing = header + b'.' + payload
sig = b64(hmac.new(secret, signing, hashlib.sha256).digest())
print((signing + b'.' + sig).decode())
PY
)"

if [ -n "${new_env:-}" ]; then
  umask 077
  cat > .env <<EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
AUTHENTICATOR_PASSWORD=${AUTHENTICATOR_PASSWORD}
JWT_SECRET=${JWT_SECRET}
SUPABASE_ANON_KEY=${ANON_KEY}
EOF
fi

cat > ../dev-defines.json <<EOF
{
  "SUPABASE_URL": "http://127.0.0.1:8000",
  "SUPABASE_ANON_KEY": "${ANON_KEY}"
}
EOF

echo "backend/.env ready; wrote dev-defines.json"
echo "anon key: ${ANON_KEY}"
