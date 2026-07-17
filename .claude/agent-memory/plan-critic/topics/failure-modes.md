# plan-critic — recurring plan failure modes (detail)

> Full detail behind the tracker rows in `MEMORY.md`. Read on demand when a plan touches the
> matching surface. Curated in place at `/wrapup` — never a dated journal.

## F1 — `hhmm` misused on a timestamp
Plan reuses `format.dart` `hhmm(int minutes)` to render a `DateTime`/timestamp. `hhmm` takes
**minutes-from-midnight**, not a DateTime; PostgREST `timestamptz` returns UTC/offset and needs
`.toLocal()` first. Correct shape lives at `comments_section.dart _timestamp()`.
First/last seen 2026-07-11 (event-comments), count 1. WATCHING — flag if a UI slice reuses `hhmm`
on a `created_at`/`updated_at`.

## F2 — `SET search_path` divergence
Plan proposes an RPC `set search_path` value diverging from the 5 existing RPCs **and** from
`docs/database.md` rule #6 (`always SET search_path = public`) while claiming to "mirror
create_event". Also mis-attributes search_path to issue #3 — #3 tracked `auth.uid()`, **not**
search_path (already compliant everywhere). Note: #3 is now CLOSED (Decision 37, no auth planned).
First/last seen 2026-07-12 (writes→RPC), count 1. WATCHING — diff any proposed `SET search_path`
against rule #6 + the existing RPCs.

## F3 — Rule-reversal / status-flip doc sweep under-scoped (PROMOTED)
**Status: PROMOTED → `CLAUDE.md` "How we work" (rule-reversal-sync paragraph). Count 3.**
First seen 2026-07-12 (writes→RPC), last 2026-07-15 (Decision 36 pre-auth lockdown, d549d45).

Plan says "document the new convention in database.md" but the change actually **reverses** an
emphatically-worded existing rule, leaving contradictory prose across sibling surfaces.

Occurrences and what was missed each time:
- **writes→RPC (2026-07-12):** reversed database.md rule #2 ("the *corrected* rule — NOT everything
  is RPC"), rule #4's event_comments exception, and Decision 23 — plus live repo doc-comments and
  migration headers.
- **d549d45 (2026-07-15):** missed 2nd/3rd stale LEDGER surfaces — decisions.md D33 (L390-391) +
  plan.md L41/L67-68 — and proposed SKIPPING stale migration headers that Slices 2/3 had already
  corrected in-slice.
- **Slice 3:** listed database.md #2/#4 + comment.dart + comments_repo + create_event_comments.sql
  header + .coderabbit.yaml + README *Verify* block, but MISSED (a) README.md's **2nd** surface, the
  "Conventions in play" summary block (~146-149), still "plain direct UPDATEs — no soft_delete_*
  RPC"; (b) **decisions.md Decision 23** (~L203 "No soft-delete RPC needed") needing a dated
  **in-place amendment** (append-only ledger — never a rewrite).

Variants of the same family:
- **ADD variant (Slice 2b):** plan had NO docs step at all. Adding a third `using(true)` table
  (`task_comments`) leaves database.md #4's exception list ("`event_comments` and `tasks`", line 18)
  stale, and skips the backend/README per-entity Verify block + decisions.md append. RULE EXTENSION:
  a new soft-delete-viewable table is a #4-exception-list edit **even when nothing is reversed**.
- **OPERATIVE-NUMBER variant (2026-07-14, issue #40 review-bar rebalance):** plan changed the fleet
  round floor/ceiling (2/3→3/4, ceiling 4→6) + CR-local M across agent-workflow.md + 3 agent defs +
  Decision 7 — but missed `.claude/commands/wrapup.md:47`, which **restates** the number. RULE
  EXTENSION: a change to an operative RULE-NUMBER is a cross-reference sweep —
  `grep -rn 'ceiling\|floor\|N=\|M='` across `.claude/commands/` + `.claude/agents/` for files that
  restate it. (wrapup.md and coderabbit.md both restate ceilings.)

Binding rule now lives in CLAUDE.md: grep the WHOLE of each touched file + **every** subsection of
each decisions-ledger entry, not just the first citation.

## F4 — Removing a model method: orphaned helpers + test fallout
Plan removes a model write-method (`toWrite`) but its Tests section lists only the NEW tests —
missing that `test/*_test.dart` tests the removed method directly, that its only private helper
(`_emptyToNull`) becomes orphaned (→ analyze `unused_element`), and that a dartdoc `[toWrite]` ref
dangles. First/last 2026-07-12 (contacts→RPC Slice 1), count 1. WATCHING — on "remove method X if
unreferenced", grep `test/` AND check for now-dead private helpers + dartdoc `[X]` links.

## F5 — Rename: under-enumerated fakes
Plan renamed a repo method + model factory-param (`fetchForEvent`→`fetchFor`,
`Comment.draft(eventId:)`→`(parentId:)`) but named a **non-existent** file
(`event_detail_screen_test.dart`) and only 1 of 3 `_FakeCommentsRepo`s — missing `widget_test.dart`
+ `calendar_screen_test.dart` (both implement the renamed method and call the renamed factory → won't
compile). Also: `fromJson` unit tests feed raw `'event_id'` JSON keys that must become `'parent_id'`
(separate from the Dart-identifier rename), and the renamed prod class
(`SupabaseCommentsRepository`→`...Event...`) has a caller in `main.dart` the plan omitted.
First/last 2026-07-14 (CommentsSection extract), count 1. WATCHING — on ANY repo-method/factory-param
rename, `grep -rn <method>\|<factory>( test/` for EVERY fake; verify the named test files EXIST; check
`main.dart` for the prod instantiation.

## F6 — Field-add sweep (PROMOTED)
**Status: PROMOTED → `CLAUDE.md` "How we work" (field-add sweep clause, written 3bf48ea follow-up).
Count 3+** (notes → contacts → importance → categories). First 2026-07-14, last 2026-07-15 (3bf48ea,
Decision 38).

Plan adds a model field but its Tests step is generic and misses:
- **(a) Reconstructing fakes.** Fake repos that rebuild the entity from scratch —
  `_StatefulTasksRepo.create/archive/restore` rebuilding `Task(id,title,isDone[,notes,deletedAt])` —
  silently DROP the new field. Invisible to `flutter analyze`, the hooks, and CodeRabbit; surfaces
  only as a widget-test failure, or not at all. Shared reconstructing fakes now live in
  `test/support/fakes.dart` (Decision 42) — thread the field there first, then grep `test/` for
  single-file specials that still reconstruct locally.
- **(b) Exact-map assertions** on `toRpcParams()` (`expect(p, {'p_title': ...})`) break the moment a
  param is added.
- **(c) RPC body preservation.** A `CREATE OR REPLACE` that recreates an RPC to add a param must
  re-carry the WHOLE prior body (SECURITY DEFINER, `SET search_path = public`, guards,
  `if not found raise`, `trim`).
- **(d) Inline param-shape comments** in the repo file itself (`create`/`update` doc-comments in
  `*_repository.dart`, the model's `toRpcParams` comment) list the OLD param set — prose the compiler
  can't catch (recurred: `p_contacts` 2b100b7, `p_categories` d95f85b).

## F7 — "Reuse the shared fake" when fakes are private
Plan says "reuse the shared fake ContactsRepository from event tests" — but fakes are **private
per-file** (`_FakeContactsRepo` in calendar_screen_test / event_form_screen_test; `_FakeRepo` in
widget_test / home_shell_test) and not importable. A screen gaining a new required repo param needs a
NEW fake in EACH test file that builds it (here task_detail/form/list had none) + the param threaded
into every screen-instantiation helper. First/last 2026-07-14 (task↔contacts), count 1. WATCHING —
verify a "shared" fake is genuinely public/importable. (Partly mitigated by `test/support/fakes.dart`,
Decision 42 — but single-file specials remain.)

## F8 — Removing a UI affordance: test fallout under-enumerated (RULE CANDIDATE)
**Count 2 — promotion threshold reached.** First 2026-07-14 (tasks view-first), last 2026-07-17
(slice A1).

- **1st (tasks view-first):** plan swapped the wide pane `TaskEditView`→`TaskDetailView` and dropped
  the "Mark complete" Switch, enumerating only SOME of the tests asserting the old affordance. Missed
  SIBLING tests using that affordance (`find.text('Mark complete')`, `find.byType(Switch)`) as an
  *incidental proxy* for "the editable pane is here".
- **2nd (slice A1, "one Save per form"):** removing the AppBar `TextButton('Save')` from 4 forms. The
  plan's verification said "update assertions (… `'Save'` …)", but the 8
  `find.widgetWithText(TextButton, 'Save')` sites are **not assertions** — they are the **driver tap**
  that triggers the save. And the surviving body button is **mode-dependent**
  (`_isEditing ? 'Save changes' : 'Add type'/'Add category'/'Add event'`), so a mechanical
  `'Save'`→`'Save changes'` swap fails in every create-mode test. Two helpers (`_addTypeViaEditor`,
  `_addCategoryViaEditor`) cascade the break into ~6 more tests.

RULE: when a plan removes an affordance, grep the WHOLE test file for that text/type, classify each
hit as **ASSERTION vs DRIVER** (a driver tap needs a retarget, not a literal swap), and read the
replacement widget's label in **both** `_isEditing` branches.

## F9 — `toRpcParams()` gains a key: the `?? ''` sentinel goes live
Plan that starts sending a previously-omitted field via `toRpcParams()` (here `'p_id': id` for
idempotent creates) assumed ALL create forms build via `Model.draft(...)` — but
`contact_form_screen`/`event_form_screen` build via the MAIN constructor with the
`id: widget.existing?.id ?? ''` **empty-string sentinel** (they never call `.draft`). The plan's "pass
id into the `.draft(...)` call" instruction misses those 2 sites → create sends `p_id: ''` →
invalid-uuid → **create breaks**. The sentinel was inert only while `toRpcParams` omitted id.

Also in the same slice: converting `Model.draft` const-ctor → `factory` breaks `const Model.draft(...)`
call sites in `event_type_test`/`task_category_test` (~line 32); and `late final _pendingId` can't be
"reset after success" (final can't reassign) — the CommentsSection composer needs a mutable field.

**2nd-pass residual gap:** making `.draft` mint an id breaks model UNIT tests asserting the OLD
invariant by literal (`test/comment_test.dart:78`, `task_test.dart:251`: `expect(.draft().id, '')`,
with test TITLES saying "…empty id…"). Distinct from the reconstructing-fake sweep: it's an
invariant-assertion unit test whose title **and** expectation must be rewritten (assert `isNotEmpty`),
not deleted. A catch-all grep framed as "draft-echo FAKES" scopes past model unit tests.

First/last 2026-07-16 (idempotent creates #9), count 1. WATCHING — grep EVERY create call site for the
MAIN-constructor build with `?? ''`; verify `.draft`→factory doesn't break a `const .draft(...)`;
`grep -rn "\.id, ''" test/` over ALL of test/, not just fakes.

## F10 — Fake-name → shared-class map is not 1:1
A test-fake-consolidation plan asserted "only the class NAME changes at call sites — drop the leading
`_`". But the SAME private fake name denotes DIFFERENT behaviors across files: `_FakeCommentsRepo` is
the **seeded** tier-2 fake in `task_detail_screen_test` (filters by parentId, rebuilds
`Comment(id:'c$seq')`) yet the **inert** tier-1 fake (`fetchFor`→`const []`) in
calendar/widget_test/home_shell. A mechanical drop-underscore maps task_detail's to the inert
`FakeCommentsRepo` → its 3 seeded-comment tests break (`find.text('Left a voicemail.')` fails).
First/last 2026-07-16 (fakes consolidation #10), count 1. WATCHING — build an explicit per-file
name→class map; never assume a private fake name means one behavior across files.

## F11 — Dedupe/extract orphans an import → analyze fails → pre-commit hook blocks
A dedupe/extract plan that moves the LAST use of a symbol out of a file leaves an **orphaned import**
→ `unused_import` → `flutter analyze` fails → the **pre-commit hook blocks the commit**.

Slice A1: replacing the local `'${weekdayShort[..]}, ${d.day} ${monthShort[..]} ${d.year}'` with
`longDate(d)` in `event_detail_screen.dart:203`, and swapping `monthShort` for a format.dart helper in
`comments_section.dart:483`, orphans `import '../util/calendar.dart'` in BOTH — each uses exactly one
calendar symbol, on that one line. `event_form_screen.dart` has 3 uses, so it survives. Plans list the
line to change but not the import to drop.

First/last 2026-07-17 (slice A1 #1), count 1. WATCHING — on any dedupe/extract, `grep -c` the
moved-from file for EVERY public symbol of the import (not just the one being swapped) to decide
whether the import is now orphaned.

## Seed watch-items (project conventions, no recurrence yet)
- Changing a model field or repo method → does the plan list the **test fake** in `test/`?
  (Injectable-repo hermetic tests mean a signature change usually needs a fake updated.) Plans get the
  fake-repo *widget* tests right but have missed **model-method unit tests** (`test/contact_test.dart`
  tests `toWrite` directly) — see F4.
- Touching `backend/migrations/` / an RPC / RLS → does the plan reference `docs/database.md`?
- Adding colour/labels → is it colour-**as-data** (Decision 19), not chrome?
- New table's FK: siblings (`event_attendees`) use `on delete cascade` — watch FK on-delete parity
  (moot while parents are soft-delete-only, but a consistency smell).
