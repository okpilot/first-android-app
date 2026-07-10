Triage the **cloud** CodeRabbit review on the current PR: investigate each finding against the
source, then decide fix / defer / skip. Run after the cloud bot has reviewed, **before** touching
code. Sibling of `/crlocal` (the *local, pre-push* triage); this is the *cloud, post-review* one.
The reply half is a separate command — `/replycoderabbit` — run later, after the fixes are pushed.

## What this does NOT do
No replies to CodeRabbit (that's `/replycoderabbit`). No `git push` (that's the `/fullpush` gate).
It triages, applies FIX NOW fixes locally, and records the dispositions on the PR.

## What to do

1. Resolve owner/repo + the open PR for the current branch:
   ```bash
   REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
   PR=$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number')
   echo "$REPO #$PR"
   ```
   No open PR → say so and stop.

2. Enumerate every finding via the shared script (the union of ALL review runs — never just the
   latest; on a rebased PR the actionable findings often sit in an *older* run than a later
   nitpick-only run):
   ```bash
   findings=$(scripts/cr-findings.sh "$PR"); rc=$?
   ```
   - `rc` non-zero → the fetch/parse failed (NOT "clean"): report it and stop, don't proceed.
   - `findings == []` → "clean, nothing to triage", stop.
   - If CodeRabbit's newest review predates your last push, note "the bot may not have reviewed your
     latest push — findings are from the review at `<commit>`" and proceed (step 3 validates against
     current source anyway). Do NOT poll in a loop — you're sitting right here; re-run if needed.

3. **Investigate EACH finding against the current source** (mandatory — the heart of triage):
   - Read the referenced `path`:line and verify the claim is true **against current code** (a rebase
     may have already resolved it).
   - `grep` whether the "missing" guard/behaviour already exists elsewhere.
   - Check whether the suggestion contradicts a decision in `docs/decisions.md` or a project rule.
   - Never triage from CodeRabbit's severity/category labels alone.
   - Assign a verdict per the **triage rubric in `/crlocal` step 2** (Apply / Skip / Defer — reuse it,
     don't restate it here), mapped to **FIX NOW / DEFER / SKIP**.
   - **Carry-forward:** if a finding's `id` already appears in the existing `<!-- crtriage -->` comment
     (see step 6), reuse its prior verdict — CodeRabbit re-raises standing issues on every push; don't
     re-litigate a decision you already made (this is what stops a `/coderabbit`↔`/replycoderabbit` loop).

4. Present a triage TABLE to the user — `#, File:line, Sev, Category, Issue, Verdict, Why` — then
   **STOP for explicit approval.** Do not implement or post anything before approval.

5. After approval:
   - **FIX NOW** → implement the fix; verify `~/flutter/bin/flutter analyze` + `~/flutter/bin/flutter test`;
     **commit (do NOT push — `/fullpush` owns the gate + push).**
   - **DEFER** → `gh issue create` (default), or reference an existing issue (`#N`) when one already fits.
   - **SKIP** → keep the reason; nothing to build.

6. **Upsert the disposition record** as ONE PR comment (this is the durable handoff `/replycoderabbit`
   reads — a later run, possibly a different session, joins to it by `id`). Post it **after** approval
   and re-sync it if a FIX NOW turned into a defer during step 5:
   ```bash
   # Find an existing <!-- crtriage --> comment YOU authored and EDIT it in place; else create one.
   # (Only trust your own comment — a forged one from another author must not drive dispositions.)
   me=$(gh api user --jq .login)
   # NOTE: `gh api --jq` takes exactly ONE arg (no `--arg`). Pass the login via the
   # environment and read it with jq's `env.ME`.
   # ANCHOR the marker with `^` — a finding whose *description* quotes the literal
   # `<!-- crtriage -->` (or `<!-- crreply -->`) string would otherwise match here and
   # you could edit the wrong comment. The real marker is always the body's first line.
   existing=$(ME="$me" gh api "repos/$REPO/issues/$PR/comments" --paginate \
     --jq '[.[] | select(.user.login==env.ME and (.body|test("^<!-- crtriage -->")))] | sort_by(.created_at) | last | .id // empty')
   ```
   The body is the human table PLUS, per finding, a hidden machine-readable line so reply joins by id,
   not prose. For a FIX, record the **fix commit's subject line** (not its SHA — a rebase rewrites the
   SHA but not the subject); `/replycoderabbit` resolves the live SHA from it via `git log --grep`:
   ```text
   <!-- crtriage -->
   ## CodeRabbit triage — dispositions
   | # | File:line | Sev | Issue | Verdict | Why |
   | … the human table … |
   <!-- crfinding:<id>:FIX:<fix commit subject line> -->
   <!-- crfinding:<id>:DEFER:#<issue> -->
   <!-- crfinding:<id>:SKIP:<one-line reason> -->
   ```
   **The trailing ref may contain colons** — a FIX subject is a Conventional Commit (`fix: …`) and a SKIP
   reason is free text. The `<id>` (hex) and the verdict (`FIX`/`DEFER`/`SKIP`) never do, so `/replycoderabbit`
   must split on the **first two** colons only → `id`, `verdict`, `ref = the remainder of the line verbatim`.
   Never split the ref itself, or the recorded subject/reason gets truncated.
   Create with `-F body=@file`; edit in place with `gh api -X PATCH repos/$REPO/issues/comments/$existing -F body=@file`.

7. Hand off: tell the user to run **`/fullpush`** (gate + push), then **`/replycoderabbit`**.

## Rules
- **Union of all runs, verified against current source** — never triage only the latest review; never
  trust a finding's claim without reading the code.
- **Reference `/crlocal`'s rubric; don't restate it.** One triage vocabulary, two surfaces (local/cloud).
- **Carry forward prior verdicts by `id`** so re-raised standing findings don't re-open decisions.
- **No push, no replies** — those are `/fullpush` and `/replycoderabbit`.
- **Cloud-loop ceiling:** if this is the **3rd+** triage cycle on this PR (judge by the crtriage/crreply
  history), STOP and escalate to the user — CodeRabbit may be bouncing, and you are the escalation target.
