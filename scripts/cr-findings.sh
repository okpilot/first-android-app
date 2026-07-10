#!/usr/bin/env bash
#
# cr-findings.sh — shared "fetch + normalize CodeRabbit findings" source of truth.
#
# Usage:
#   scripts/cr-findings.sh <PR>            # live: resolve repo via `gh repo view`, fetch from GitHub
#   scripts/cr-findings.sh --fixture FILE  # offline: read a pre-captured bundle ({reviews,comments})
#   scripts/cr-findings.sh --fixture -     # offline: read the bundle from stdin
#
# Prints a normalized JSON array to stdout — the UNION of findings across ALL review
# runs on the PR, deduped WITHIN each Run ID. Makes NO currency/staleness decisions.
#
# Output object schema (one per finding):
#   {run_id, review_id, commit_id, submitted_at, source, kind, id,
#    path, line_display, title}
#     source: "inline" | "body"
#     kind  : "actionable" | "nitpick" | "outside_diff"
#     id    : first 12 hex of sha1(path + "\n" + normalized_title)   [line-number-free → stable]
#
# Exit codes:
#   0  success (INCLUDING a clean PR → prints "[]")
#   non-zero  ONLY on real failure: gh/API error, jq parse error, or a per-run
#             actionable-reconciliation mismatch (CodeRabbit markdown format drift).

set -euo pipefail

# --------------------------------------------------------------------------- #
# arg parsing
# --------------------------------------------------------------------------- #
FIXTURE=""
PR=""
case "${1:-}" in
  --fixture)
    FIXTURE="${2:-}"
    [ -n "$FIXTURE" ] || { echo "cr-findings: --fixture needs a file (or - for stdin)" >&2; exit 2; }
    ;;
  "" )
    echo "usage: cr-findings.sh <PR> | --fixture <file|->" >&2; exit 2 ;;
  -* )
    echo "cr-findings: unknown flag '$1'" >&2; exit 2 ;;
  * )
    PR="$1" ;;
esac

for bin in jq sha1sum awk; do
  command -v "$bin" >/dev/null 2>&1 || { echo "cr-findings: missing dependency '$bin'" >&2; exit 2; }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --------------------------------------------------------------------------- #
# obtain the bundle: { "reviews": [...], "comments": [...] }
# The live path produces the SAME intermediate structure as a fixture bundle,
# so all downstream logic is identical and deterministically testable offline.
# --------------------------------------------------------------------------- #
if [ -n "$FIXTURE" ]; then
  if [ "$FIXTURE" = "-" ]; then
    cat > "$TMP/bundle.json"
  else
    [ -f "$FIXTURE" ] || { echo "cr-findings: fixture not found: $FIXTURE" >&2; exit 2; }
    cp "$FIXTURE" "$TMP/bundle.json"
  fi
else
  command -v gh >/dev/null 2>&1 || { echo "cr-findings: missing dependency 'gh'" >&2; exit 2; }
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  [ -n "$REPO" ] || { echo "cr-findings: could not resolve repo via gh" >&2; exit 1; }
  # --paginate concatenates one JSON array PER PAGE; stream every element with
  # --jq '.[]' and re-slurp so ALL pages are merged (a raw --slurpfile would keep
  # only the first page and silently drop reviews/comments past page 1).
  gh api "repos/$REPO/pulls/$PR/reviews"  --paginate --jq '.[]' | jq -s '.' > "$TMP/reviews.json"
  gh api "repos/$REPO/pulls/$PR/comments" --paginate --jq '.[]' | jq -s '.' > "$TMP/comments.json"
  jq -n --slurpfile r "$TMP/reviews.json" --slurpfile c "$TMP/comments.json" \
    '{reviews: ($r[0] // []), comments: ($c[0] // [])}' > "$TMP/bundle.json"
fi

# validate JSON early (jq parse error => non-zero, per contract). Both arrays must
# be present + array-typed — a missing/non-array `comments` must FAIL, not be silently
# treated as "no inline findings".
jq -e 'type=="object" and (.reviews|type=="array") and (.comments|type=="array")' "$TMP/bundle.json" >/dev/null \
  || { echo "cr-findings: bundle must be an object with array 'reviews' and 'comments'" >&2; exit 1; }

# --------------------------------------------------------------------------- #
# survivors: one review per Run ID.
#   run_id  = value on the `**Run ID**: `<uuid>`` line (decoy checkboxId uuids
#             never match because we anchor on that exact label).
#   survivor within a run = MAX cr-comment marker count, tie-break latest submitted_at.
# --------------------------------------------------------------------------- #
RUNS_JQ='
  [ .reviews[]
    | select((.user.login // "") == "coderabbitai[bot]")
    | { review_id: .id,
        commit_id: (.commit_id // null),
        submitted_at: (.submitted_at // ""),
        body: (.body // ""),
        marker_count: ([ (.body // "") | scan("cr-comment:v1:") ] | length),
        n: (((.body // "") | capture("Actionable comments posted: (?<n>[0-9]+)") | .n | tonumber)? // null),
        run_id: (((.body // "") | capture("\\*\\*Run ID\\*\\*: `(?<r>[0-9a-fA-F-]+)`") | .r)? // null)
      }
    | .run_id = (.run_id // (if .marker_count > 0 then "review-\(.review_id)" else null end))
    | select(.run_id != null)
  ]
  | group_by(.run_id)
  | map( sort_by(.marker_count, .submitted_at) | last )
'
jq -c "$RUNS_JQ" "$TMP/bundle.json" > "$TMP/survivors.json"

# review_id -> run_id map across ALL cr reviews (for attributing inline comments,
# whose referenced review may be a dedup loser but shares the run).
jq -c '
  reduce ( .reviews[]
           | select((.user.login // "") == "coderabbitai[bot]")
           | { review_id: .id,
               marker_count: ([ (.body // "") | scan("cr-comment:v1:") ] | length),
               rid: (((.body // "") | capture("\\*\\*Run ID\\*\\*: `(?<r>[0-9a-fA-F-]+)`") | .r)? // null) }
           # SAME fallback as RUNS_JQ: a marker-bearing review with no **Run ID** label
           # still gets review-<id>, so its inline comments are attributed, not discarded.
           | { key: (.review_id|tostring),
               value: (.rid // (if .marker_count > 0 then "review-\(.review_id)" else null end)) }
           | select(.value != null)
         ) as $e ({}; . + {($e.key): $e.value})
' "$TMP/bundle.json" > "$TMP/reviewmap.json"

# --------------------------------------------------------------------------- #
# body parser (awk): reads a review body on stdin, emits one TSV line per finding:
#   kind <TAB> line_display <TAB> path <TAB> title
# Only the 🛑 / ⚠️ / 🧹 sections are parsed. The "Prompt for all review comments"
# aggregate block is explicitly ignored (it re-lists everything → would double-count).
# --------------------------------------------------------------------------- #
read -r -d '' BODY_AWK <<'AWK_EOF' || true
function flush() {
  if (in_finding && cur_title != "") {
    printf "%s\t%s\t%s\t%s\n", fkind, cur_line, path, cur_title
  }
  in_finding = 0; cur_title = ""; cur_line = ""
}
BEGIN { sect=""; path=""; in_finding=0; cur_title=""; cur_line=""; fkind="" }
{
  line = $0

  # --- section headers (anchored on ASCII text, not the emoji) --------------
  if (line ~ /<summary>[^<]*Comments failed to post/)      { sect="actionable";   path=""; next }
  if (line ~ /<summary>[^<]*Outside diff range comments/)  { sect="outside_diff"; path=""; next }
  if (line ~ /<summary>[^<]*Nitpick comments/)             { sect="nitpick";      path=""; next }
  if (line ~ /<summary>[^<]*Prompt for all review comments/) { sect="ignore";     path=""; next }

  # only parse inside a real finding section
  if (sect=="actionable" || sect=="outside_diff" || sect=="nitpick") {

    # --- per-file path summary (contains a '/' or a .ext, and a (N) count) ---
    if (line ~ /<summary>[^<]*<\/summary>/) {
      s = line
      sub(/.*<summary>/, "", s)
      sub(/<\/summary>.*/, "", s)
      if (s ~ / \([0-9]+\)$/ && (s ~ /\// || s ~ /\.[A-Za-z0-9]+ \([0-9]+\)$/)) {
        flush()
        path = s
        sub(/ \([0-9]+\)$/, "", path)
        next
      }
    }

    # --- finding line/range prefix: `38-45`:  or  38-45: --------------------
    if (path != "" && line ~ /^[`]?[0-9]+(-[0-9]+)?[`]?:/) {
      flush()
      fkind = sect
      pl = line
      if (match(pl, /[0-9]+(-[0-9]+)?/)) cur_line = substr(pl, RSTART, RLENGTH)
      in_finding = 1; cur_title = ""
      next
    }

    # --- first **bold** line after the prefix is the title -----------------
    if (in_finding && cur_title=="" && line ~ /^\*\*/) {
      t = line
      sub(/^\*\*/, "", t)
      sub(/\*\*[[:space:]]*$/, "", t)
      cur_title = t
      next
    }

    # --- the finding's cr-comment marker ends it ---------------------------
    if (in_finding && line ~ /cr-comment:v1:/) { flush(); next }
  }
}
END { flush() }
AWK_EOF

# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
# normalized title: lowercase, trim, collapse internal whitespace
norm_title() { printf '%s' "$1" | awk '{ $1=$1; print tolower($0) }'; }
# stable id: first 12 hex of sha1(path + "\n" + normalized_title)  (NO line number)
finding_id() { printf '%s\n%s' "$1" "$2" | sha1sum | cut -c1-12; }

: > "$TMP/findings.ndjson"

# --------------------------------------------------------------------------- #
# body findings, per surviving run
# --------------------------------------------------------------------------- #
SURV_COUNT="$(jq 'length' "$TMP/survivors.json")"
i=0
while [ "$i" -lt "$SURV_COUNT" ]; do
  run_id="$(jq -r ".[$i].run_id"        "$TMP/survivors.json")"
  review_id="$(jq -r ".[$i].review_id"  "$TMP/survivors.json")"
  commit_id="$(jq -r ".[$i].commit_id // \"\"" "$TMP/survivors.json")"
  submitted_at="$(jq -r ".[$i].submitted_at // \"\"" "$TMP/survivors.json")"

  # Extract the body first (a jq failure here MUST be loud — set -e aborts on a failed
  # substitution), then parse it. awk exits 0 on an empty result, so no `|| true` mask
  # is needed and a genuine awk error surfaces instead of a silent zero-finding run.
  body="$(jq -r ".[$i].body" "$TMP/survivors.json")"
  printf '%s\n' "$body" | awk "$BODY_AWK" > "$TMP/findings.tsv"

  while IFS=$'\t' read -r kind line_display path title; do
    [ -n "${kind:-}" ] || continue
    nt="$(norm_title "$title")"
    fid="$(finding_id "$path" "$nt")"
    jq -nc \
      --arg run_id "$run_id" --arg review_id "$review_id" --arg commit_id "$commit_id" \
      --arg submitted_at "$submitted_at" --arg source "body" --arg kind "$kind" \
      --arg id "$fid" --arg path "$path" --arg line_display "$line_display" --arg title "$title" \
      '{run_id:$run_id, review_id:($review_id|tonumber? // $review_id), commit_id:$commit_id,
        submitted_at:$submitted_at, source:$source, kind:$kind, id:$id,
        path:$path, line_display:$line_display, title:$title}' >> "$TMP/findings.ndjson"
  done < "$TMP/findings.tsv"

  i=$((i + 1))
done

# --------------------------------------------------------------------------- #
# inline findings (real /pulls/N/comments threads). Often empty (inline posting
# fails), but handled for completeness. Attributed to the run of the review the
# comment belongs to, tagged with that run's survivor metadata.
# --------------------------------------------------------------------------- #
INLINE_COUNT="$(jq '[ .comments[]? | select((.user.login // "")=="coderabbitai[bot]") ] | length' "$TMP/bundle.json")"
j=0
while [ "$j" -lt "$INLINE_COUNT" ]; do
  c="$(jq -c "[ .comments[] | select((.user.login // \"\")==\"coderabbitai[bot]\") ][$j]" "$TMP/bundle.json")"
  prr="$(printf '%s' "$c" | jq -r '.pull_request_review_id | tostring')"
  run_id="$(jq -r --arg k "$prr" '.[$k] // ""' "$TMP/reviewmap.json")"
  if [ -z "$run_id" ]; then j=$((j + 1)); continue; fi

  # survivor metadata for this run
  meta="$(jq -c --arg r "$run_id" '[ .[] | select(.run_id==$r) ][0]' "$TMP/survivors.json")"
  review_id="$(printf '%s' "$meta" | jq -r '.review_id')"
  commit_id="$(printf '%s' "$meta" | jq -r '.commit_id // ""')"
  submitted_at="$(printf '%s' "$meta" | jq -r '.submitted_at // ""')"

  path="$(printf '%s' "$c" | jq -r '.path // ""')"
  line_display="$(printf '%s' "$c" | jq -r '
    (.start_line // .original_start_line) as $s
    | (.line // .original_line) as $e
    | if ($s != null) and ($e != null) and ($s != $e) then "\($s)-\($e)"
      elif $e != null then "\($e)"
      else "" end')"
  title="$(printf '%s' "$c" | jq -r '.body // ""' | awk '/^\*\*/{ sub(/^\*\*/,""); sub(/\*\*[[:space:]]*$/,""); print; exit }')"
  [ -n "$title" ] || title="$(printf '%s' "$c" | jq -r '(.body // "") | split("\n")[0]')"
  # inline comments are actionable unless the body self-identifies as a nitpick
  kind="actionable"
  if printf '%s' "$c" | jq -e '(.body // "") | test("Nitpick|🧹")' >/dev/null; then kind="nitpick"; fi

  nt="$(norm_title "$title")"
  fid="$(finding_id "$path" "$nt")"
  jq -nc \
    --arg run_id "$run_id" --arg review_id "$review_id" --arg commit_id "$commit_id" \
    --arg submitted_at "$submitted_at" --arg source "inline" --arg kind "$kind" \
    --arg id "$fid" --arg path "$path" --arg line_display "$line_display" --arg title "$title" \
    '{run_id:$run_id, review_id:($review_id|tonumber? // $review_id), commit_id:$commit_id,
      submitted_at:$submitted_at, source:$source, kind:$kind, id:$id,
      path:$path, line_display:$line_display, title:$title}' >> "$TMP/findings.ndjson"
  j=$((j + 1))
done

# --------------------------------------------------------------------------- #
# Collapse EXACT repeats, then disambiguate genuine same-title collisions.
#   - unique_by([run_id,id,line_display]) drops only true duplicates (the same
#     finding emitted twice — e.g. a repeated section, or body+inline at one line).
#   - a (run_id,id) group with >1 member left = distinct findings that share a
#     path+normalized_title at DIFFERENT lines (id is line-free by design). Keep
#     the first (lowest line) on its bare stable id; give the 2nd+ a durable
#     "<id>@<line>" so none is dropped, the reconciliation count stays correct,
#     and /replycoderabbit can disposition each separately.
# Runs before reconciliation + emission.
# --------------------------------------------------------------------------- #
jq -s -c '
    unique_by([.run_id, .id, .line_display])
  | group_by([.run_id, .id])
  | map( if length > 1
         then ( sort_by(.line_display) | to_entries
                | map(.value + (if .key == 0 then {}
                                else {id: (.value.id + "@" + .value.line_display)} end)) )
         else . end )
  | flatten | .[]
' "$TMP/findings.ndjson" > "$TMP/findings.dedup" \
  && mv "$TMP/findings.dedup" "$TMP/findings.ndjson"

# --------------------------------------------------------------------------- #
# per-run, per-category reconciliation self-check.
#   assert (inline_actionable + failed_to_post) == "Actionable comments posted: N"
#   nitpick & outside_diff are counted SEPARATELY (they are NOT in N).
#   Hard-fail ONLY when N is present AND the actionable subset disagrees.
# --------------------------------------------------------------------------- #
i=0
while [ "$i" -lt "$SURV_COUNT" ]; do
  run_id="$(jq -r ".[$i].run_id" "$TMP/survivors.json")"
  n="$(jq -r ".[$i].n // \"\"" "$TMP/survivors.json")"
  if [ -n "$n" ]; then
    failed="$(jq -s --arg r "$run_id" '[ .[] | select(.run_id==$r and .source=="body"   and .kind=="actionable") ] | length' "$TMP/findings.ndjson")"
    inline="$(jq -s --arg r "$run_id" '[ .[] | select(.run_id==$r and .source=="inline" and .kind=="actionable") ] | length' "$TMP/findings.ndjson")"
    got=$((failed + inline))
    if [ "$got" -ne "$n" ]; then
      echo "cr-findings: reconciliation FAILED for run $run_id — actionable (inline $inline + failed-to-post $failed = $got) != 'Actionable comments posted: $n'. CodeRabbit markdown format may have drifted." >&2
      exit 3
    fi
  fi
  i=$((i + 1))
done

# --------------------------------------------------------------------------- #
# emit the union as a JSON array (empty file => [])
# --------------------------------------------------------------------------- #
jq -s '.' "$TMP/findings.ndjson"
