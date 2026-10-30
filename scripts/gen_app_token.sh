#!/usr/bin/env bash
# Mint a short-lived GitHub App installation token (acts AS the Marketing App).
# Usage: APP_ID=... INSTALL_ID=... PEM=path/to/app-private-key.pem ./gen_app_token.sh
set -euo pipefail
: "${APP_ID:?set APP_ID}"; : "${INSTALL_ID:?set INSTALL_ID}"; : "${PEM:?set PEM}"
now=$(date +%s); iat=$((now-60)); exp=$((now+540))
b64() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$iat" "$exp" "$APP_ID" | b64)
sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$PEM" -binary | b64)
jwt="$header.$payload.$sig"
curl -s -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/$INSTALL_ID/access_tokens" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])'
