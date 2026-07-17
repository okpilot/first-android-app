# implementation-critic — recurring deviation write-ups

> Full detail for the one-line WATCHING rows in MEMORY.md. Each is a distinct-mechanism drift seen
> at pre-commit. Grep-in-miniature rules included so a future review can re-derive the check.

## toRpcParams shape-change → stale sibling comment (RESOLVED-WATCH, count 1)
Task notes slice; held clean at Decision 38 importance, 2026-07-15. When a scalar field is added to
`toRpcParams()`, the model's dartdoc that quotes the OLD param literal (`create_task(p_title,
p_notes, p_contacts)`, the `{p_id, p_title, p_is_done, p_notes, p_contacts}` update shape) goes
stale in the SAME file. At Decision 38 the sweep was proactive (plan-critic folded it in): both the
`create_task(… p_importance)` signature quote and the update-shape quote in task.dart were updated
in the same diff, AND the repo's update() comment. Minor (SUGGESTION) when missed — grep the
model+repo for a comment quoting the pre-change param literal whenever the create/update shape grows.

## Docs-sync "same file, >1 stale surface" (RULE CANDIDATE, count 2 → propose promotion)
**Mechanism 1 — the backlog/owed-list twin.** Issue #40 review-bar rebalance, 2026-07-14. A
rules/docs slice that updates a status line (plan.md current-status: "`/updatephone` done"; Decision
35 codifying #40) but leaves the SAME file's "Owed first / to-do" list still citing the very item the
commit completed — plan.md:14 "phone done" vs plan.md:51 "phone owed", and #40 still listed as owed
at :54 while THIS commit does it. Numbers were correct; the staleness was STATUS framing.

**Mechanism 2 — the back-reference clause + the twin-file copy.** Issue #19 / Decision 45
soft-delete-proof curls, 2026-07-17 (both findings were the whole REVISE verdict; every curl, SQL
annotation and the decision text itself were clean). Two NEW shapes, neither a list entry:
- **(a) A pointer whose descriptive clause rots.** The slice correctly demoted the stale Slice-B lead
  in plan.md's `## Next slice`, but three back-references elsewhere in the same file still read "the
  authoritative next pick lives in `## Next slice` above, **now led by Slice B**" (plan.md:85, :99,
  :104). The pointer stays valid forever; the clause naming *what it points at* is what goes stale.
  A grep for the completed item's keyword ("Slice B") finds these; a grep for "owed/next/TODO" does not.
- **(b) The twin-file copy.** plan.md:19's D40 `/updatephone` marker was flipped to "done 2026-07-17"
  while HANDOVER.md:18's near-verbatim twin sentence kept "`/updatephone` OWED (S23+ not connected
  this session)" — directly contradicting HANDOVER's own header (:1) and RESUME (:14), both of which
  the same slice had updated. plan.md and HANDOVER.md carry sentence-level duplicates of every
  status claim, so a flip in one is a flip owed in the other.

**RULE (both mechanisms):** on any status flip, (1) grep the SAME file's "Owed"/"Next"/"backlog"/
"TODO" lists for the task keyword; (2) grep BOTH plan.md and HANDOVER.md for the OLD claim's keywords
(they carry near-verbatim twins); (3) grep for `see .* above` / `authoritative` / `led by` clauses
naming the thing that moved. This is rule-reversal-sync discipline applied to status prose, not just
repos. At count 2 the promotion threshold is met — the `learner` should propose folding "status flips
get the same whole-file + twin-file sweep as a rule reversal" into CLAUDE.md's rule-reversal-sync rule.

## Consolidating a duplicated fake orphans its doc-comment (WATCHING, count 1)
Issue #10 shared test/support/fakes.dart, 2026-07-16. When a per-file happy-path fake that carried a
`/// ...` doc comment is DELETED (moved to the shared file) and the very next declaration is a
RETAINED single-file special (`_FailingContactsRepo`/`_FailingCategoriesRepo`), the deleted class's
doc line is left behind — now stacked above and MIS-DESCRIBING the failing class (`/// A minimal
fake ... reads the roster via fetchAll; writes unused.` sitting atop a repo whose fetchAll THROWS).
Silent to `flutter analyze` (a doc comment is legal anywhere) and to a green suite. RULE: when a
diff DELETES a class that had a leading `///` block, grep the deletion site — if the line directly
BELOW the removed class is another `///` or a `class`, the old doc dangled; delete it too. Two hits
in one slice (category_picker + contact_picker); SUGGESTION (misleading, non-functional) but
directly undercuts a tidiness refactor.

## Verify-curl param names drift from the RPC signature (WATCHING, count 1)
Decision 36 pre-auth lockdown, 2026-07-15. A NEW `backend/README.md` verify-curl block transcribed
`create_contact`'s JSON body with non-existent params `p_birthday`/`p_notes` while the real
signature is `p_dob`/`p_remarks` (a correct twin curl sat right below it). PostgREST matches RPC
args by NAME → the "returns a uuid" curl would actually PGRST202. RULE: whenever a doc/README adds a
`POST /rpc/<fn>` example, grep the fn's `create_*/update_*` migration for the exact `p_*` param
names and match them 1:1 — the app's Dart `toRpcParams()` is NOT the source of truth for a
hand-written curl (Dart may use different field names). ISSUE severity: a copy-paste-fails verify
snippet contradicts its own success comment.

## State-lift-vs-`widget.x` trap (WATCHING, count 1)
Decision 29 view-first Tasks. A thin Scaffold host whose AppBar title/state claims (in a comment) to
track the LIVE entity but reads `widget.task`/`widget.contact` (frozen at push) while the mutation
lives in the child body via `onChanged`. If the host title has a state-dependent split
(`'Task'`/`'Archived task'`), the host must seed `late _task` and `setState` it in `onChanged` —
otherwise an in-place archive/restore flips the BODY (Restore-only) but leaves the AppBar stale,
contradicting the comment. Const-title hosts (ContactDetailScreen = `'Contact'`) are immune, which
is why the pattern was safe until a dynamic title was introduced.
