#!/usr/bin/env bash
# Configure the isolated test repo: ruleset + Pages. Run by an ADMIN (Ryan) once the repo exists
# and the bundle has been pushed to it. Requires: gh auth as the repo owner; R=owner/repo.
set -euo pipefail
: "${R:?set R=owner/repo}"
echo "Resolving github-actions app id (for the CI bypass actor)..."
ACTIONS_ID=$(gh api /apps/github-actions --jq .id)
echo "  actions app id: $ACTIONS_ID"
sed "s/__ACTIONS_APP_ID__/$ACTIONS_ID/" ruleset.json > /tmp/ruleset.filled.json
echo "Creating branch ruleset on main..."
gh api --method POST "/repos/$R/rulesets" --input /tmp/ruleset.filled.json --jq '.id,.name,.enforcement' || \
  echo "  (if a ruleset already exists, delete it or PATCH instead)"
echo "Enabling GitHub Pages (deploy from main /)..."
gh api --method POST "/repos/$R/pages" -f 'source[branch]=main' -f 'source[path]=/' 2>/dev/null \
  || gh api --method PUT "/repos/$R/pages" -f 'source[branch]=main' -f 'source[path]=/' 2>/dev/null \
  || echo "  (Pages may already be enabled; check Settings > Pages)"
echo "Done. Ruleset + Pages configured. Marketing App is NOT in the bypass list."
