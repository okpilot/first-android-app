#!/usr/bin/env bash
#
# Tests for scripts/cr-findings.sh — deterministic, offline (--fixture mode).
# Fixtures under scripts/test/fixtures/ are real captured `gh api ... --paginate`
# payloads from PRs #14 and #15 (repo okpilot/first-android-app).

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../cr-findings.sh"
FIX="$HERE/fixtures"

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }
eq()   { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 — expected [$3] got [$2]"; fi; }

# --------------------------------------------------------------------------- #
echo "PR #14 (twin dedup — reviews share Run ID 3265d7d8; keep the findings-bearing twin)"
out="$("$SCRIPT" --fixture "$FIX/pr-14.json")"; rc=$?
eq   "exit 0"                 "$rc" "0"
eq   "total findings"         "$(echo "$out" | jq 'length')" "6"
eq   "actionable count"       "$(echo "$out" | jq '[.[]|select(.kind=="actionable")]|length')" "5"
eq   "nitpick count"          "$(echo "$out" | jq '[.[]|select(.kind=="nitpick")]|length')" "1"
eq   "all from body source"   "$(echo "$out" | jq '[.[]|select(.source=="body")]|length')" "6"
eq   "all from surviving run" "$(echo "$out" | jq '[.[]|select(.run_id=="3265d7d8-bf11-4fea-98df-ea0e7ee1ce80")]|length')" "6"
# exact set of (path @ line) for the 5 actionable failed-to-post findings
eq   "actionable: create_event_types.sql @38-45" \
     "$(echo "$out" | jq '[.[]|select(.kind=="actionable" and .path=="backend/migrations/20260710120000_create_event_types.sql" and .line_display=="38-45")]|length')" "1"
eq   "actionable: add_type_to_events.sql @13-14" \
     "$(echo "$out" | jq '[.[]|select(.kind=="actionable" and .path=="backend/migrations/20260710120100_add_type_to_events.sql" and .line_display=="13-14")]|length')" "1"
eq   "actionable: soft_delete_event_type_rpc.sql @16-26" \
     "$(echo "$out" | jq '[.[]|select(.kind=="actionable" and .path=="backend/migrations/20260710120200_soft_delete_event_type_rpc.sql" and .line_display=="16-26")]|length')" "1"
eq   "actionable: event_types_screen.dart @29-39" \
     "$(echo "$out" | jq '[.[]|select(.kind=="actionable" and .path=="lib/screens/event_types_screen.dart" and .line_display=="29-39")]|length')" "1"
eq   "actionable: event_types_screen.dart @34-38" \
     "$(echo "$out" | jq '[.[]|select(.kind=="actionable" and .path=="lib/screens/event_types_screen.dart" and .line_display=="34-38")]|length')" "1"
eq   "nitpick: add_type_to_events.sql @13-14" \
     "$(echo "$out" | jq '[.[]|select(.kind=="nitpick" and .path=="backend/migrations/20260710120100_add_type_to_events.sql" and .line_display=="13-14")]|length')" "1"
# nitpick and actionable on the SAME path@line have DISTINCT ids (title differs)
eq   "same path@line, distinct ids (title-based)" \
     "$(echo "$out" | jq '[.[]|select(.path=="backend/migrations/20260710120100_add_type_to_events.sql" and .line_display=="13-14")|.id]|unique|length')" "2"
# aggregated "Prompt for all review comments" block is NOT parsed (would double to 12)
eq   "aggregate block excluded (no double-count)" \
     "$(echo "$out" | jq '[.[]|.id]|unique|length')" "6"

# --------------------------------------------------------------------------- #
echo "PR #14 FULL (all 3 reviews / 2 runs — true union across runs)"
outf="$("$SCRIPT" --fixture "$FIX/pr-14-full.json")"; rc=$?
eq   "exit 0"                 "$rc" "0"
eq   "union total (6 + 1)"    "$(echo "$outf" | jq 'length')" "7"
eq   "run 3265d7d8 findings"  "$(echo "$outf" | jq '[.[]|select(.run_id=="3265d7d8-bf11-4fea-98df-ea0e7ee1ce80")]|length')" "6"
eq   "run a8af7bd5 findings"  "$(echo "$outf" | jq '[.[]|select(.run_id=="a8af7bd5-47c4-4542-b86f-76017dd08edb")]|length')" "1"
eq   "later run: test-file nitpick @39-58" \
     "$(echo "$outf" | jq '[.[]|select(.path=="test/event_types_screen_test.dart" and .line_display=="39-58" and .kind=="nitpick")]|length')" "1"

# --------------------------------------------------------------------------- #
echo "PR #15 (nitpick-only; no 'Actionable comments posted' header => N=0)"
out15="$("$SCRIPT" --fixture "$FIX/pr-15.json")"; rc=$?
eq   "exit 0"                 "$rc" "0"
eq   "total findings"         "$(echo "$out15" | jq 'length')" "1"
eq   "the one nitpick"        "$(echo "$out15" | jq -r '.[0]|"\(.kind)|\(.path)|\(.line_display)"')" \
     "nitpick|lib/screens/calendar_screen.dart|952-1030"
eq   "reconciliation passes (N absent => 0)" "$rc" "0"

# --------------------------------------------------------------------------- #
echo "Clean PR (zero findings) — the SIGPIPE/grep-no-match trap"
outc="$("$SCRIPT" --fixture "$FIX/pr-empty.json")"; rc=$?
eq   "prints []"             "$outc" "[]"
eq   "exit 0"                "$rc" "0"

# --------------------------------------------------------------------------- #
echo "id stability — line-number-free hash"
# same finding computed twice is identical (idempotent join key)
id1="$(echo "$out"  | jq -r '.[]|select(.line_display=="29-39").id')"
id2="$("$SCRIPT" --fixture "$FIX/pr-14.json" | jq -r '.[]|select(.line_display=="29-39").id')"
eq   "recompute yields same id" "$id1" "$id2"
# id equals sha1(path + "\n" + normalized_title)[:12], independent of the line
want="$(printf '%s\n%s' "lib/screens/event_types_screen.dart" "guard \`_lastdata\` updates and show refresh failures." | sha1sum | cut -c1-12)"
eq   "id = sha1(path\\nnorm_title)[:12]" "$id1" "$want"

# --------------------------------------------------------------------------- #
echo "reconciliation hard-fail on format drift (N present but actionable subset disagrees)"
# feed only the nitpick-only twin: it advertises 'Actionable comments posted: 5'
# yet carries 0 failed-to-post findings => must exit non-zero.
drift="$HERE/fixtures/.drift.tmp.json"
if ! jq -n --slurpfile r "$FIX/pr-14-reviews.json" '{pr:14, reviews:[$r[0][0]], comments:[]}' > "$drift" \
   || [ ! -s "$drift" ]; then
  rm -f "$drift"; bad "could not generate the drift fixture"
else
  "$SCRIPT" --fixture "$drift" >/dev/null 2>&1; rc=$?
  rm -f "$drift"
  # exit 3 is specifically the reconciliation-mismatch code — a validation (1) or
  # usage (2) failure would mean the test misfired, not that reconciliation caught drift.
  if [ "$rc" -eq 3 ]; then ok "exit 3 on reconciliation mismatch"; else bad "expected exit 3, got $rc"; fi
fi

# --------------------------------------------------------------------------- #
echo
echo "same-title collision — two findings, one path, identical title, different lines"
# Both must survive (not collapsed by dedup); reconciliation (N=2) must pass.
outc="$("$SCRIPT" --fixture "$FIX/pr-collision.json")"; rcc=$?
eq   "exit 0 (reconciliation passes, N=2)" "$rcc" "0"
eq   "both findings survive"        "$(echo "$outc" | jq 'length')" "2"
eq   "distinct ids"                 "$(echo "$outc" | jq '[.[].id]|unique|length')" "2"
# first occurrence keeps the bare stable id; the later one is disambiguated by line
eq   "first keeps bare stable id"   "$(echo "$outc" | jq -r '.[]|select(.line_display=="10-12").id')" \
                                    "$(printf 'lib/foo.dart\nduplicate title collision test.' | sha1sum | cut -c1-12)"
eq   "second disambiguated by line" "$(echo "$outc" | jq -r '.[]|select(.line_display=="30-32").id|endswith("@30-32")')" "true"

# collision tie-break is NUMERIC, not lexical: line "9-9" must beat "10-12" for the
# bare id (a string sort would wrongly put "10-12" first).
outn="$("$SCRIPT" --fixture "$FIX/pr-collision-num.json")"; rcn=$?
eq   "numeric collision exit 0"     "$rcn" "0"
eq   "lower numeric line keeps bare id" \
     "$(echo "$outn" | jq -r '.[]|select(.line_display=="9-9").id')" \
     "$(printf 'lib/foo.dart\nduplicate title collision test.' | sha1sum | cut -c1-12)"
eq   "higher line disambiguated"    "$(echo "$outn" | jq -r '.[]|select(.line_display=="10-12").id|endswith("@10-12")')" "true"

# --------------------------------------------------------------------------- #
echo
echo "----------------------------------------"
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ] || exit 1
