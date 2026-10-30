#!/usr/bin/env bash
set -uo pipefail
: "${BASE:?set BASE to the Pages deploy page_url}"
bodyhash() { python3 - "$1" <<'P'
import sys,hashlib
s=open(sys.argv[1],encoding='utf-8').read()
a=s.index('<div class="art-body">')+len('<div class="art-body">'); b=s.index('</div></article>')
print('sha256:'+hashlib.sha256(s[a:b].strip().encode()).hexdigest())
P
}
fail=0
for f in writing/*.html; do
  slug=$(basename "$f" .html); want=$(bodyhash "$f"); url="${BASE%/}/writing/$slug.html"; ok=0
  for try in 1 2 3 4 5; do
    code=$(curl -s -o served.html -w '%{http_code}' "$url?cb=$RANDOM") || true
    if [ "$code" = "200" ]; then
      got=$(bodyhash served.html)
      if [ "$got" = "$want" ]; then echo "LIVE-VERIFIED $slug: served==approved ($got)"; ok=1; break
      else echo "VerifyFailed $slug: 200 but body mismatch"; fail=1; break; fi
    fi
    echo "  $slug try $try: http $code (lag, retry)"; sleep 15
  done
  [ "$ok" = 0 ] && { echo "HOLD $slug: never verified"; fail=1; }
done
[ "$fail" = 0 ] && echo "ALL LIVE-VERIFIED -> social may release" || { echo "HOLD social"; exit 1; }
