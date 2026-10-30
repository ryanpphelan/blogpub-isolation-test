#!/usr/bin/env bash
# T7-T13: run AS THE MARKETING APP (restricted). Every attack must be BLOCKED.
# Usage: R=owner/repo APP_TOKEN=<installation token> ./attacks.sh
set -uo pipefail
: "${R:?set R=owner/repo}"; : "${APP_TOKEN:?set APP_TOKEN}"
export GH_TOKEN="$APP_TOKEN"
pass(){ echo "PASS  $1"; }; fail(){ echo "FAIL  $1  <-- NOT BLOCKED"; }
OWNER="${R%/*}"; REPO="${R#*/}"; TMP=$(mktemp -d)

echo "== T7: direct push to protected main =="
git clone -q "https://x-access-token:$APP_TOKEN@github.com/$R" "$TMP/r" && cd "$TMP/r"
echo "x" >> README.md 2>/dev/null || echo x > README.md
git -c user.email=a@b.c -c user.name=app commit -aqm "direct push attempt" >/dev/null 2>&1
if git push -q origin HEAD:main 2>"$TMP/t7"; then fail "T7 direct push to main"; else pass "T7 direct push to main (rejected)"; fi
cd - >/dev/null

echo "== T10: create a ruleset (needs Administration) =="
if gh api --method POST "/repos/$R/rulesets" -f name=x -f target=branch -f enforcement=active >/dev/null 2>&1; then fail "T10 create ruleset"; else pass "T10 create ruleset (403 no Administration)"; fi

echo "== T12: modify branch protection / add self to bypass (needs Administration) =="
if gh api "/repos/$R/rulesets" >/dev/null 2>&1 && gh api --method PUT "/repos/$R/rulesets/1" -f name=x >/dev/null 2>&1; then fail "T12 modify ruleset"; else pass "T12 modify ruleset (403 no Administration)"; fi

echo "== T10b: Actions/Workflows API (needs Workflows/Actions permission) =="
if gh api "/repos/$R/actions/permissions" >/dev/null 2>&1; then fail "T10b read actions settings"; else pass "T10b actions API (403 no Actions permission)"; fi

echo "== T9: open a PR that edits a forbidden path (styles.css) =="
cd "$TMP/r"; git checkout -q -b attack-path
mkdir -p content/blog; printf '%s\n' '---' '{"slug":"x","title":"x","author":"Ryan Phelan","meta_description":"x","excerpt":"x","publish_time":"2026-10-30T00:00:00Z"}' '---' 'body' > content/blog/x.md
echo "body{}" > styles.css
git -c user.email=a@b.c -c user.name=app add -A && git -c user.email=a@b.c -c user.name=app commit -qm "edit styles.css"
git push -q origin attack-path 2>/dev/null
PR=$(gh pr create --title "attack path" --body "x" --base main --head attack-path 2>/dev/null | grep -o '[0-9]*$' || echo "")
sleep 20
if [ -n "$PR" ] && gh pr merge "$PR" --merge --admin 2>/dev/null; then fail "T9 merged a forbidden-path PR"; else pass "T9 forbidden-path PR blocked (check fails / cannot merge)"; fi
cd - >/dev/null

echo "== T13: open a PR adding status outside content/blog (.publishing/) =="
cd "$TMP/r"; git checkout -q main 2>/dev/null; git checkout -q -b attack-status
mkdir -p .publishing/status; echo '{"state":"live"}' > .publishing/status/x.json
git -c user.email=a@b.c -c user.name=app add -A && git -c user.email=a@b.c -c user.name=app commit -qm "forge status"
git push -q origin attack-status 2>/dev/null
PR2=$(gh pr create --title "attack status" --body "x" --base main --head attack-status 2>/dev/null | grep -o '[0-9]*$' || echo "")
sleep 20
if [ -n "$PR2" ] && gh pr merge "$PR2" --merge 2>/dev/null; then fail "T13 forged status merged"; else pass "T13 status-forge PR blocked"; fi
cd - >/dev/null

echo "== T8: PR whose validation check FAILS, then try to merge =="
cd "$TMP/r"; git checkout -q main 2>/dev/null; git checkout -q -b attack-badcontent
mkdir -p content/blog; echo "no front matter, no approval" > content/blog/bad.md
git -c user.email=a@b.c -c user.name=app add -A && git -c user.email=a@b.c -c user.name=app commit -qm "bad content no approval"
git push -q origin attack-badcontent 2>/dev/null
PR3=$(gh pr create --title "bad content" --body "x" --base main --head attack-badcontent 2>/dev/null | grep -o '[0-9]*$' || echo "")
sleep 25
if [ -n "$PR3" ] && gh pr merge "$PR3" --merge 2>/dev/null; then fail "T8 merged with failing check"; else pass "T8 merge blocked by failing check"; fi

echo "== T11: approve own PR =="
if [ -n "${PR3:-}" ] && gh api --method POST "/repos/$R/pulls/$PR3/reviews" -f event=APPROVE 2>/dev/null; then fail "T11 self-approved own PR"; else pass "T11 cannot self-approve own PR (422)"; fi
cd - >/dev/null
echo "== attacks complete =="
