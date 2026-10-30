#!/usr/bin/env bash
# Dean 5/6: one run renders, then DIRECTLY waits for the Pages deploy and verifies CONTENT.
set -euo pipefail
R="${GITHUB_REPOSITORY:?}"
base=$(gh api "/repos/$R/pages" --jq .html_url 2>/dev/null || echo "")
[ -z "$base" ] && { echo "Pages not enabled yet"; exit 1; }
# poll the latest Pages build until success or timeout
for i in $(seq 1 10); do
  st=$(gh api "/repos/$R/pages/builds/latest" --jq .status 2>/dev/null || echo "unknown")
  echo "  pages build poll $i: $st"
  [ "$st" = "built" ] && break
  [ "$st" = "errored" ] && { echo "DeployFailed: Pages build errored (prior deploy stays live, no partial)"; exit 1; }
  sleep 15
done
# content-level verification for each rendered article
fail=0
for f in writing/*.html; do
  slug=$(basename "$f" .html)
  want="sha256:$(python3 - "$f" <<'P'
import sys,re,hashlib
s=open(sys.argv[1],encoding='utf-8').read()
b=s[s.index('<div class="art-body">')+len('<div class="art-body">'):s.index('</div></article>')]
print(hashlib.sha256(b.strip().encode()).hexdigest())
P
)"
  url="${base%/}/writing/$slug.html"
  ok=0
  for try in 1 2 3; do
    code=$(curl -s -o body.html -w '%{http_code}' "$url?cb=$RANDOM") || true
    if [ "$code" = "200" ]; then
      got="sha256:$(python3 - body.html <<'P'
import sys,hashlib
s=open(sys.argv[1],encoding='utf-8').read()
b=s[s.index('<div class="art-body">')+len('<div class="art-body">'):s.index('</div></article>')]
print(hashlib.sha256(b.strip().encode()).hexdigest())
P
)"
      [ "$got" = "$want" ] && { echo "LIVE VERIFIED $slug: served body == approved body"; ok=1; break; }
      echo "VerifyFailed $slug: 200 but body mismatch"; fail=1; break
    fi
    echo "  verify $slug try $try: http $code (propagation lag, retry)"; sleep 15
  done
  [ "$ok" = 0 ] && fail=1
done
[ "$fail" = 0 ] && echo "ALL ARTICLES LIVE-VERIFIED -> dependent social may release" || { echo "HOLD social; not independently verified"; exit 1; }
