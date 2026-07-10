Post the reply to CodeRabbit for the findings **`/coderabbit` already triaged** on the current PR —
one comment, each finding citing its fix SHA (or skip/defer reason). Run **after** the fixes are
pushed (via `/fullpush`). This command does **no triage** — it only responds to decisions
`/coderabbit` recorded. It's the cloud counterpart to `/crlocal`; the cloud bot is the authoritative
gate (Decision 7), and answering it closes the loop.

## What to do

1. Resolve owner/repo + PR (as in `/coderabbit` step 1). Then **require the triage record**:
   ```bash
   crtriage=$(gh api "repos/$REPO/issues/$PR/comments" --paginate \
     --jq '[.[] | select(.body|test("<!-- crtriage -->"))] | sort_by(.created_at) | last')
   ```
   No `<!-- crtriage -->` comment → STOP: "run `/coderabbit` first to triage." (Reply never decides.)

2. Enumerate findings with the shared script and join to the triage record by `id`:
   ```bash
   findings=$(scripts/cr-findings.sh "$PR"); rc=$?
   ```
   - `rc` non-zero → fetch/parse failed, stop.
   - `findings == []` → nothing to answer; **post nothing** (never an empty comment), stop.
   - Parse the hidden `<!-- crfinding:<id>:<VERDICT>:<ref> -->` lines from `crtriage`; map each script
     finding to its verdict + ref by `id`. (Same session? the dispositions are also in context.)
   - **New finding guard:** if a finding's `id` is NOT in the triage record → a push-triggered
     re-review raised something new → **STOP: "run `/coderabbit`"**. A re-flag of an id that IS in the
     record is already disposed — match it, do NOT stop (this is what prevents an infinite bounce).

3. For each **FIX** finding, resolve the **current** fix SHA live by the commit *subject* the triage
   recorded (never a stored SHA — rebases rewrite them; and never `git log -1 -- <path>`, which can grab
   a later unrelated edit to the same file):
   ```bash
   sha=$(git log -1 --format=%h --grep="$(printf '%s' "$subject" | sed 's/[][\.*^$/]/\\&/g')")
   ```
   If the subject can't be found (e.g. it was squashed/reworded), fall back to the newest commit touching
   the path and say so, rather than citing a SHA you can't verify.

4. **Upsert ONE general PR comment** (`<!-- crreply -->`) with a line per finding, each tagged so a
   re-run is idempotent (add/update only changed lines; don't duplicate):
   ```text
   <!-- crreply -->
   ## CodeRabbit findings — dispositions
   <!-- crreply:<id> --> **path:line — title** — Fixed in `<sha>`: <one sentence>.
   <!-- crreply:<id> --> **path:line — title** — Deferred → #<issue>.
   <!-- crreply:<id> --> **path:line — title** — Skipped: <reason>.
   ```
   Find an existing `<!-- crreply -->` comment and `PATCH` it in place; else create it. (These PRs have
   no inline threads — everything goes in this one comment. If a real inline thread ever exists, reply
   on it via `/pulls/$PR/comments/<id>/replies` instead.)

5. **Verify it landed:** re-read the `<!-- crreply -->` comment and confirm every `id` from the triage
   record appears. Any missing → add it before you stop.

## Rules
- **Never triage here.** No fix/skip/defer decisions — read them from the `<!-- crtriage -->` record.
- **Never cite a stored SHA** — resolve it live from `git log` at reply time (rebase-safe).
- **One idempotent `<!-- crreply -->` comment**, keyed per finding by `id`; safe to re-run.
- **Every triaged finding gets a line** — fixed (with SHA), skipped (with reason), or deferred (with #).
- **A genuinely new, un-triaged finding → STOP and send the user to `/coderabbit`.** Don't answer what
  wasn't triaged.
