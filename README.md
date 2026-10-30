# Blog Publishing, Phase 2 isolated test bundle

Throwaway test of the restricted blog publishing gate. Nothing here touches the production
site (ryanpphelan.github.io) or production credentials. Public repo = free Actions and Pages.

## Part 1. Owner actions (Ryan, in the GitHub UI)

1. Create a NEW repository:
   - Name: `blogpub-isolation-test`
   - Visibility: PUBLIC (free Actions + Pages; no secrets live in the repo)
   - Initialize with a README (so `main` exists)
2. Create a test GitHub App (Settings > Developer settings > GitHub Apps > New):
   - Name: `blogpub-marketing-test` (add a suffix if the name is taken)
   - Homepage URL: the repo URL. Webhook: UNCHECK "Active".
   - Repository permissions (set ONLY these; leave everything else "No access"):
       Contents: Read and write
       Pull requests: Read and write
       Metadata: Read-only (automatic)
     Confirm these are "No access": Administration, Workflows, Actions, Deployments,
     Environments, Secrets, Pages, Checks.
   - "Where can this GitHub App be installed?": Only on this account.
   - Create, then "Generate a private key" and download the .pem.
   - Install App: choose "Only select repositories" > the test repo only.
   - Note the App ID (App settings page) and the Installation ID (the number in the
     install URL: .../installations/<INSTALL_ID>).

## Part 2. Push this bundle into the repo

From this unzipped folder:
    git init -b main
    git remote add origin https://github.com/<you>/blogpub-isolation-test.git
    git add . && git commit -m "phase 2 test harness"
    git push -u origin main --force   # repo is throwaway

## Part 3. Configure the gate (ruleset + Pages)

    R=<you>/blogpub-isolation-test bash scripts/setup.sh
Creates the `main` ruleset (PR required, required check "blog-validate", restricted file
paths, block force push, github-actions as the only bypass actor) and enables Pages.

## Part 4. Run the attack tests T7-T13 (as the Marketing App)

    export APP_ID=<app id> INSTALL_ID=<install id> PEM=/path/to/app-private-key.pem
    APP_TOKEN=$(scripts/gen_app_token.sh)
    R=<you>/blogpub-isolation-test APP_TOKEN=$APP_TOKEN bash scripts/attacks.sh | tee attacks-output.txt

Every line should read PASS (the attack was blocked). Send `attacks-output.txt` back.

## Part 5. Deploy + content verification (Dean 5/6), automatic

The valid sample `content/blog/hello-isolation-test.md` plus its approval are already here.
When a content PR merges to main, `.github/workflows/publish.yml` renders the page, commits it,
waits for the Pages build, fetches the live URL, and verifies the SERVED body hash equals the
RENDERED body hash before reporting success. The Actions run log is the evidence for Dean 5/6.

## What to send back for Dean
- attacks-output.txt (Part 4)
- the blog-publish Actions run log (Part 5)
- the ruleset as created: `gh api /repos/<you>/blogpub-isolation-test/rulesets --jq '.[].name'`

## Notes
- keys/TEST-approval-*.pem is a TEST Approval Authority key for this harness only. The real
  signer is the Option C service built separately; its public key replaces keys/approval-public.pem.
- Delete the repo and uninstall the App when testing is done.
