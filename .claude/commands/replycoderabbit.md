Post the reply to CodeRabbit for the findings **`/coderabbit` already triaged** on the current PR —
**replying in each finding's own inline thread** (that's where CodeRabbit reads and resolves), each
citing its fix SHA (or skip/defer reason). Run **after** the fixes are pushed (via `/fullpush`). This
command does **no triage** — it only responds to decisions `/coderabbit` recorded. It's the cloud
counterpart to `/crlocal`; the cloud bot is the authoritative gate (Decision 7), and answering it
closes the loop.

**Inline-first.** CodeRabbit's actionable findings are **inline review comments** (`source:"inline"`
from `cr-findings.sh`). Reply IN-THREAD on each via `POST /pulls/$PR/comments/<comment_id>/replies`
so the answer lands under CodeRabbit's comment and the thread resolves — do NOT dump everything in one
detached PR comment. Only findings with **no inline thread** (`source:"body"` — summary/walkthrough
items) go in the single fallback `<!-- crreply -->` comment.

## What to do

1. Resolve owner/repo + PR (as in `/coderabbit` step 1). Then **require the triage record — and only
   trust one you authored** (a forged `<!-- crtriage -->` comment from anyone else could otherwise
   dictate the dispositions you post):
   ```bash
   me=$(gh api user --jq .login)
   # NOTE: `gh api --jq` takes exactly ONE arg (no `--arg`). Pass the login via the
   # environment and read it with jq's `env.ME`.
   # ANCHOR the marker with `^` — a finding whose *description* quotes the literal
   # `<!-- crtriage -->` string would otherwise match here. The real marker is always
   # the body's first line.
   crtriage=$(ME="$me" gh api "repos/$REPO/issues/$PR/comments" --paginate \
     --jq '[.[] | select(.user.login==env.ME and (.body|test("^<!-- crtriage -->")))] | sort_by(.created_at) | last')
   ```
   No trusted `<!-- crtriage -->` comment → STOP: "run `/coderabbit` first to triage." (Reply never decides.)

2. Enumerate findings with the shared script and join to the triage record by `id`:
   ```bash
   findings=$(scripts/cr-findings.sh "$PR"); rc=$?
   ```
   - `rc` non-zero → fetch/parse failed, stop.
   - `findings == []` → nothing to answer; **post nothing** (never an empty comment), stop.
   - Parse the hidden `<!-- crfinding:<id>:<VERDICT>:<ref> -->` lines from `crtriage`; map each script
     finding to its verdict + ref by `id`. **Split on the first two colons only** — `<id>` (hex) and
     `<VERDICT>` are colon-free, but the `ref` (a `fix: …` commit subject or a free-text reason) is the
     remainder of the line and may itself contain colons; splitting it further truncates the ref and
     breaks fix-SHA resolution. (Same session? the dispositions are also in context.)
   - **New finding guard:** if a finding's `id` is NOT in the triage record → a push-triggered
     re-review raised something new → **STOP: "run `/coderabbit`"**. A re-flag of an id that IS in the
     record is already disposed — match it, do NOT stop (this is what prevents an infinite bounce).

3. For each **FIX** finding, resolve the **current** fix SHA live by the commit *subject* the triage
   recorded — never a stored SHA (rebases rewrite them) and never `git log -1 -- <path>` (grabs a later
   unrelated edit). Match the **subject line exactly** (not a substring — `--grep` would match a later
   commit that merely mentions it) and require **exactly one** match:
   ```bash
   matches=$(git log --format='%h%x09%s' | awk -F'\t' -v s="$subject" '$2==s{print $1}')
   n=$(printf '%s' "$matches" | grep -c .)
   if [ "$n" = 1 ]; then sha=$matches; else sha=""; fi   # 0 or >1 → don't cite a SHA you can't verify
   ```
   If `sha` is empty (subject squashed/reworded, or ambiguous), say so in the reply instead of citing a
   SHA you can't stand behind — don't guess.

4. **Fetch the inline review comments once** (you need CodeRabbit's GitHub comment id to reply in-thread —
   `cr-findings.sh`'s `id` is a content hash, NOT the GitHub id, so you must map to it here):
   ```bash
   gh api "repos/$REPO/pulls/$PR/comments" --paginate --jq '.[]' | jq -s '.' > /tmp/cr-inline.json
   ```

5. **For each `source:"inline"` finding — reply IN ITS THREAD.** Map the finding to CodeRabbit's
   **top-level** review comment (`.in_reply_to_id==null`) by `path` + the **end** line of `line_display`
   (`"29-30"` → `30`; CodeRabbit anchors on the last line), then POST a reply to that comment. Use a
   standalone `jq` for the mapping — `gh api --jq` takes no `--arg`:
   ```bash
   endline=${line_display##*-}
   cid=$(jq -r --arg P "$path" --arg L "$endline" \
     '[.[] | select(.user.login=="coderabbitai[bot]" and .in_reply_to_id==null
        and .path==$P and ((.line // .original_line)|tostring)==$L)][0].id // empty' /tmp/cr-inline.json)
   ```
   - `cid` empty (no matching thread — line moved, or it's really a body finding) → fall back to the
     `<!-- crreply -->` comment in step 6 for that finding; don't skip it silently.
   - **Idempotency — never double-post.** Before replying, check whether YOU already answered in that
     thread (a reply of yours carrying the finding's hidden marker):
     ```bash
     done=$(jq -r --argjson CID "$cid" --arg ME "$me" --arg ID "$id" \
       '[.[] | select(.user.login==$ME and .in_reply_to_id==$CID
          and (.body|contains("<!-- crreply:"+$ID+" -->")))][0].id // empty' /tmp/cr-inline.json)
     ```
     `done` non-empty → already answered, leave it (or `PATCH /repos/$REPO/pulls/comments/$done` only if
     the disposition changed). Else POST the reply — **first line is the hidden marker** so a re-run is idempotent:
     ```bash
     printf '<!-- crreply:%s -->\nFixed in `%s`: %s\n' "$id" "$sha" "$sentence" > /tmp/reply.md   # or: Skipped: … / Deferred → #N
     gh api -X POST "repos/$REPO/pulls/$PR/comments/$cid/replies" -F body=@/tmp/reply.md --jq .html_url
     ```

6. **Fallback for `source:"body"` findings only** (summary/walkthrough items with no thread to reply on):
   upsert ONE general `<!-- crreply -->` PR comment, a marker-tagged line per such finding (idempotent —
   add/update only changed lines). Skip this step entirely if every finding got an inline reply:
   ```text
   <!-- crreply -->
   ## CodeRabbit findings — dispositions (no inline thread)
   <!-- crreply:<id> --> **path:line — title** — Fixed in `<sha>`: <one sentence>.
   <!-- crreply:<id> --> **path:line — title** — Skipped: <reason>. / Deferred → #<issue>.
   ```
   Find an existing `<!-- crreply -->` comment **you authored** and `PATCH` it in place; else create it —
   author-scoped + `^`-anchored (never `PATCH` a forged one; never let a finding that merely *quotes* the marker match):
   ```bash
   existing=$(ME="$me" gh api "repos/$REPO/issues/$PR/comments" --paginate \
     --jq '[.[] | select(.user.login==env.ME and (.body|test("^<!-- crreply -->")))] | sort_by(.created_at) | last | .id // empty')
   ```

7. **Verify every finding was answered:** re-fetch `/tmp/cr-inline.json` (and the `<!-- crreply -->`
   comment if step 6 ran) and confirm each triaged `id`'s marker now appears — as an inline reply, or a
   fallback-comment line. Any missing → post it before you stop.

## Rules
- **Never triage here.** No fix/skip/defer decisions — read them from the `<!-- crtriage -->` record.
- **Inline findings get an in-thread reply**, matched by path + end-line; the detached `<!-- crreply -->`
  comment is a **fallback for body/summary findings only**, never the default for inline ones.
- **Never cite a stored SHA** — resolve it live from `git log` at reply time (rebase-safe).
- **Idempotent per finding by `id`** — each reply (inline or fallback) carries a `<!-- crreply:<id> -->`
  marker; a re-run edits/skips, never duplicates.
- **Every triaged finding gets answered** — fixed (with SHA), skipped (with reason), or deferred (with #).
- **A genuinely new, un-triaged finding → STOP and send the user to `/coderabbit`.** Don't answer what
  wasn't triaged.
