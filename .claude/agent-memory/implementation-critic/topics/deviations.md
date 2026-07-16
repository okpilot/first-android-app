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

## Docs-sync "same file, >1 stale surface" — the backlog/owed-list twin (WATCHING, count 1)
Issue #40 review-bar rebalance, 2026-07-14. A rules/docs slice that updates a status line (plan.md
current-status: "`/updatephone` done"; Decision 35 codifying #40) but leaves the SAME file's "Owed
first / to-do" list still citing the very item the commit completed — plan.md:14 "phone done" vs
plan.md:51 "phone owed", and #40 still listed as owed at :54 while THIS commit does it. Numbers were
correct; the staleness was STATUS framing. RULE: on any doc-sync slice, after editing a
status/shipped line, grep the SAME file's "Owed"/"Next"/"backlog"/"TODO" lists for the same task
keyword — a file has >1 surface (rule-reversal-sync discipline applied to plan.md, not just repos).

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
