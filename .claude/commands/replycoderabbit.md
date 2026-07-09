Reply to every cloud CodeRabbit review comment on the current PR — inline on the exact
thread — so no finding is left unanswered. Run AFTER disposing findings (fix / defer /
skip), before merge. Scaled from LMS Plus; the cloud bot on the PR is the authoritative
gate (Decision 7), and answering it closes the loop.

## What to do

1. Resolve owner/repo + the open PR for the current branch:
   ```bash
   REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
   PR=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number')
   echo "$REPO #$PR"
   ```
   If there's no open PR, say so and stop.

2. Fetch CodeRabbit **inline** comments (the actionable findings):
   ```bash
   gh api "repos/$REPO/pulls/$PR/comments" --paginate \
     --jq '.[] | select(.user.login=="coderabbitai[bot]" and .in_reply_to_id==null) | {id, path, line, body: (.body|split("\n")[0:3]|join(" "))}'
   ```

3. Fetch the CodeRabbit **review body** for any "outside diff range" / summary-only findings:
   ```bash
   gh api "repos/$REPO/pulls/$PR/reviews" --paginate \
     --jq '.[] | select(.user.login=="coderabbitai[bot]") | {id, state, body: (.body|split("\n")[0:8]|join(" "))}'
   ```

4. For each **inline** finding, reply directly on its thread, citing the fix commit (or the
   skip/defer reason):
   ```bash
   gh api "repos/$REPO/pulls/$PR/comments/COMMENT_ID/replies" \
     -f body="Fixed in <sha> — <one sentence>. Verified: analyze + tests."
   ```
   - **Fixed** → reference the exact commit SHA that contains the fix.
   - **Skipped** → explain why (e.g. "False positive — the guard already exists at lib/x.dart:NN").
   - **Deferred** → link the issue (e.g. "Deferred to #NN — belongs with the events slice").

5. For **outside-diff / summary** findings (not addressable inline), post ONE general PR
   comment covering them all:
   ```bash
   gh api "repos/$REPO/issues/$PR/comments" -f body="## Addressing outside-diff findings
   **1. lib/foo.dart** — <fix / reason>
   **2. …**"
   ```

6. Verify replies landed:
   ```bash
   gh api "repos/$REPO/pulls/$PR/comments" --paginate \
     --jq '.[] | select(.user.login!="coderabbitai[bot]") | {path, line, body: (.body[:70])}'
   ```

## Rules
- **Never leave a CodeRabbit finding without a reply** — every one gets a response.
- **Every reply cites the fix commit SHA** (or a concrete skip/defer reason) so a reviewer can verify.
- Triage first (READ the source per `/crlocal`), fix/skip/defer, THEN reply — don't reply "fixed" before it is.
- Match the disposition you actually took: don't claim a fix you didn't make.
- This is the cloud counterpart to `/crlocal` (local, pre-push). Run it once the cloud bot has reviewed the PR.
