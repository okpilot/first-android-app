#!/usr/bin/env bash
# Writes backend/.env (gitignored) with dev secrets + an anon JWT that matches
# JWT_SECRET, and mirrors the anon key into ../dev-defines.json for the Flutter client.
# Safe to re-run. Requires python3.
set -euo pipefail
cd "$(dirname "$0")"

POSTGRES_DB="postgres"
POSTGRES_PASSWORD="postgres-dev-password"
AUTHENTICATOR_PASSWORD="authenticator-dev-pass"
JWT_SECRET="super-secret-jwt-token-with-at-least-32-characters-long"

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

cat > .env <<EOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
AUTHENTICATOR_PASSWORD=${AUTHENTICATOR_PASSWORD}
JWT_SECRET=${JWT_SECRET}
SUPABASE_ANON_KEY=${ANON_KEY}
EOF

cat > ../dev-defines.json <<EOF
{
  "SUPABASE_URL": "http://127.0.0.1:8000",
  "SUPABASE_ANON_KEY": "${ANON_KEY}"
}
EOF

echo "wrote backend/.env and dev-defines.json"
echo "anon key: ${ANON_KEY}"
