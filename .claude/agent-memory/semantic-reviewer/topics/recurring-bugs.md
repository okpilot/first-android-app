# Recurring semantic bugs — full detail

> The evidence behind each tracker row in `MEMORY.md`. One `##` section per row; the row in
> `MEMORY.md` carries the pattern name, status, count and last-seen commit.

## A comment reasons about ONE layer while a same-commit sibling edit moves it
**WATCHING, count 1, `72f33c1` (D47).** Kin to "a doc attributes a check to a guard that cannot
fire", but for layout: the comment's physics are right in isolation and wrong once the commit's
OTHER change lands.

D47 kept `radius: 11` on the two chip `InitialsAvatar`s with a LOAD-BEARING comment — "A Chip pins
the avatar's BOX (`tightFor(contentSize)`), so radius can't change the disc size here". True at
HEAD~1. But the SAME commit:
- (a) added `ring: true`, which inserts a `Container(padding: 2 + border 0.5)` that now receives the
  pinned box and passes `contentSize − 5` down to the `CircleAvatar` — so the parent no longer pins
  the DISC, only the ring;
- (b) added a `chipTheme` whose `labelStyle: labelMedium` dropped `contentSize` 20 → 16.
  `contentSize` is LABEL-height-driven — `max(_kChipHeight − padding.vertical, rawLabelHeight)` —
  not padding-driven as the theme comment claims.

Net: the disc went 20px → 11px in one commit while `fontSize` stayed `radius * 0.7` = 7.7
(calibrated for an unconstrained 22px disc) ⇒ two-glyph initials spill outside the circle.

**Measured, don't reason.** Pump the widget under the real `AppTheme` and `tester.getSize` the
`CircleAvatar` + its `Text` at HEAD and HEAD~1. The Ahem test font makes the clamp obvious:

| | contentSize | circle | initials Text |
|---|---|---|---|
| HEAD~1, ring=false | 20 | 20×20 | 15.8×11 (fits) |
| HEAD, ring=false | 16 | 16×16 | 15.8×11 (tight) |
| HEAD, ring=true | 16 | **11×11** | **11.0×11.0 — clamped from 15.8 natural** |

**Check:** when a comment justifies keeping a value because "the parent pins X", verify no sibling
hunk in the SAME diff inserts a widget between the parent and the pinned child.

## Stale status twin in a NON-shipping ledger subsection
**RULE CANDIDATE, count 2:** D33's bare `**Deploy:**` (`f30ab6e`); D43's `**Principle:**` (still
open at `f30ab6e`).

A slice flips a status (`push/PR pending → merged`, `owed → done`) and amends the entry it was
thinking about, while a twin of the same claim survives in a subsection that is NOT a shipping
heading. D43:519 still reads "committed on `slice/shared-detail-field`, push/PR pending" + "Closes
issue #10 **on merge**" though `2d450ac` is on `main` and #10 closed 2026-07-16 — and it CONTRADICTS
D43's own title ("closes #10, 2026-07-16") and its sibling D42:509, which DID get the
`Amended — **MERGED:**` note. Flipped by `2c7a495`, missed by `f30ab6e`'s own sweep.

This is D46's thesis proving itself: the twin hid in `**Principle:**`, so a sweep of shipping
headings (`Deploy` / `Deploy note`) cannot find it — **grep the ENTRY for the old status word, never
a list of headings**.

**Check:** on any status flip, `grep -n "push/PR pending\|owed\|deferred\|on branch"
docs/decisions.md` across the WHOLE ledger, and cross-check each entry's title vs its body (a
title/body disagreement inside one decision is a free tell).

## One named category, two memberships, same commit
**WATCHING, count 1, `cc058fb`.** The closed-list-proxy defect one level up from D46's: not a stale
list, but the SAME term defined with two different sets in two live rules added by ONE commit.

`database.md` #8 says "the derived-membership join tables (`event_attendees`, `task_contacts`,
`task_category_links`)"; #11 says "the derived-membership join tables (`task_contacts`,
`task_category_links`)" — and #11's bucket is *needs-no-privileged-read*, i.e. exactly where
`event_attendees` must NOT land (D45's whole point). Round 3's fix ("which are a different set from
#4's exceptions") disambiguated one collision and minted another against the rule added 3 lines above.

**Check:** when a slice adds a named category to a doc, grep the term across the WHOLE file and diff
the memberships — a parenthetical after "the X" reads as a definition, not an example.

## A doc attributes a check to a guard that cannot fire
**WATCHING, count 1, `286f86f`.** The D45 defect inverted: not "a check that cannot fail", but "a
guard the doc says protects you, which the code has already made unreachable".

`backend/README.md:233` + `:278-279` tell the reader `events_time_valid` forces all-day events to
carry no times and that "a mismatched pair 400s" — but BOTH `create_event`
(`20260716120000:118-119`) and `update_event` (`20260710120300:93-94`) do `start_time = case when
coalesce(p_all_day,false) then null else p_start_time end`, so the RPC silently normalizes and the
constraint can never fire on that direction. The TRUE reason for the explicit nulls is stated in the
same sentence (the 8 leading params have no defaults ⇒ omitting one is PGRST202) — the constraint is
a false add-on.

**Check:** when a doc names a constraint/guard as the reason for a payload shape, verify the RPC body
doesn't sanitize that input first — a `case when` in the RPC makes the DB constraint decorative.

## A live rule that enumerates a closed count
**WATCHING, count 1, `f30ab6e`.** Distinct from the D46 proxy defect — the rule fires on its stated
INTENT, but pins a count that rots. `database.md` #11 says "the **4** `using (deleted_at is null)`
tables (…)"; correct at HEAD (verified: contacts, events, event_types, task_categories) but table 11
makes it wrong. Ledger entries may carry counts (append-only snapshots); a LIVE binding rule in
`database.md` should state the test and enumerate openly ("e.g. …, …") per D46's own Principle.
Round 2 stripped exactly these counts out of D46 — the same fix is owed in the rule D46 shipped
alongside.

## Line-number citation broken by the SAME commit that shifts it
**WATCHING, count 1, `470721d`.** A doc/plan entry cites `file:NNN-MMM` read from the PRE-commit
file, while the same commit inserts lines above that point — the citation is stale the instant it
lands. `470721d`: plan.md:14 cited `README.md:233-238` + `:270-274` (correct at HEAD~1) after
inserting ~120 lines above both (real: ~355 / ~390). Invisible to analyze/hooks/CR.

**Check:** any `file:NNN` added in a commit that also edits that file — verify against the POST-commit
file, or cite the `## heading` instead of the line. Prefer heading/anchor citations in docs; line refs
only for immutable files (a landed migration).

## `setState(() => <expr that returns a Future>)`
**PROMOTED, count 2:** Contacts `fa4fc45`, comments `3a87cc8`. The arrow discards the Future — async
work fires but `setState` returns synchronously. `flutter analyze` did NOT flag it (legal void-context
arrow) until the `discarded_futures` lint was enabled (`0e4a7af`), which now mechanizes the catch.
Fix = block body `setState(() { … })` and `await`/`unawaited` outside. Still worth a semantic flag on
any new `setState(() => …)` whose callee returns a Future (belt-and-braces with the lint).

## Form/section declares an entity read-only but leaves a write affordance live
**RULE CANDIDATE, count 2:** Tasks `58b2b5d` (fixed `258cb6c`); CommentsSection `643bbeb` (fixed
`adab034`). learner promoted this at `adab034` → proposed a written convention in
`docs/design-principles.md` (gate EVERY write affordance, incl. state-dependent inline editors, on the
read-only flag). **Once the main session writes it, mark PROMOTED → docs/design-principles.md.**

**Root lesson:** gate ALL write affordances — including STATE-dependent ones (an open inline editor) —
on the read-only flag, not just the always-rendered buttons.

*Tasks (`58b2b5d`):* archived `TaskFormScreen` hid the complete toggle but kept the title editable +
BOTH Save affordances live → Save → `update_task` guarded `deleted_at is null` → `no_data_found` →
misleading "Couldn't save" (retry always fails). Fix = gate Save button + input field +
`onFieldSubmitted` on the same flag.

*CommentsSection (`643bbeb`):* `readOnly` gated the composer + per-comment Edit/Archive/Unarchive, but
NOT the inline-edit branch `editing ? _editBody(c) : _viewBody(c)` — `_editBody`'s TextField + live
Save (`_saveEdit`→`repository.edit`) rendered on `_editingId` ALONE. Reachable: open a LIVE task, tap
a comment's Edit (sets `_editingId`), then tap the TASK's Archive → in-place `setState(_task=result)`
rebuilds CommentsSection with `readOnly=true` but NO remount (no key) ⇒ `_editingId` survives ⇒ Save
stays live; DB `update_task_comment` guards `deleted_at is null` on the COMMENT (still live), so the
write SUCCEEDS on a supposedly-frozen archived-task log.

**FIXED & re-verified CLEAN (`adab034`)** with BOTH belt-and-braces layers: (a) `_liveTile` renders
`(editing && !widget.readOnly) ? _editBody : _viewBody` so the editor can't render read-only, and
(b) `didUpdateWidget` sets `_editingId = null` on the false→true readOnly flip (no setState — a
rebuild is already in flight, correct). The two cooperate on the phone in-place path (TaskDetailView
persists, CommentsSection keyless ⇒ didUpdateWidget fires). Desktop remounts via the host key so state
is fresh anyway. Stale `_editController.text` is harmless — `_startEdit` resets it. Leak CLOSED.

Decision 29 (view-first Tasks, `cfbfe7f`) removes the whole risk STRUCTURALLY: the archived-readonly
branch is gone from `TaskEditView` (title-only form, live-only) and an archived task can no longer
reach the form at all — the read-only detail drops Edit/Complete and offers Restore only. Preferred
shape.
