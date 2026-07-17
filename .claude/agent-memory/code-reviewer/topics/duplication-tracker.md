# code-reviewer — duplication tracker detail

Read on demand. Full evidence behind the tracker rows in `MEMORY.md` (which keeps the one-line
row + status; this file keeps the "why"). Rows are never deleted — they transition.

## Meta-pattern: byte-identical / near-identical private widget copied, not shared
The recurring shape in this repo. Distinguish it from the CONVENTION of a per-screen private
`_ErrorState` / `_EmptyState`, which carries per-screen TEXT variance. Zero variance → extractable.
Instances repo-wide: `MetaLine` (PROMOTED), `DetailField` (PROMOTED), `_SwatchGrid` (WATCHING),
`_PeopleSection`/`_AttendeesSection` (RULE CANDIDATE).

## `_MetaLine` — PROMOTED → `lib/widgets/meta_line.dart` (RESOLVED)
The "Added X · Updated Y" muted date footer, same class in both detail screens, functionally
byte-identical bar a `parts.isEmpty` guard. Extracted acb0043; the merged atom keeps the task
copy's `parts.isEmpty` guard — strictly safer for contacts, whose call site already guarded.

## `_Field` → PROMOTED → `lib/widgets/detail_field.dart` (`DetailField`, 780c930, D43) (RESOLVED)
The labelled detail-field row (icon + label + value), duplicated AND **diverged** across
`contact_detail_screen` (nullable value + "Not added" placeholder) and `event_detail_screen`
(value XOR `child` + `selectable`, no placeholder). Same mechanism as `MetaLine`, but the copies
had drifted apart — the extraction merged them into a superset atom whose extra branches
(empty → "Not added") are unreachable for the stricter event caller. Superset merge verified
pixel-identical; relaxed assert `child == null || value == null` (both-null allowed) safe for both
callers; grep confirmed 0 leftover `_Field`.

## Chip-section / roster widget duplicated per linked-collection — RULE CANDIDATE (count 2)
First seen 2026-07-14 (link contacts to tasks); last seen 2026-07-17 (72f33c1).

- `_PeopleSection` (task_form) vs `_AttendeesSection` (event_form) — byte-identical
  Wrap-of-InputChips, originally differing by only 2 string literals.
- `_PeopleList` (task_detail) vs `_AttendeeList` (event_detail) — per-item roster Row
  byte-identical.
- Slice B (d95f85b) added `_CategoriesSection` (task_form, comment says "Mirrors `_PeopleSection`";
  differs only: label CATEGORIES/PEOPLE, avatar `TypeSwatch`/`InitialsAvatar`, button copy/icon) +
  `_CategoriesList` (task_detail, "Mirrors `_PeopleList`"; differs: header noun, `TypeDot + Text`
  vs avatar). That was the distinct mechanism taking the count to 2 — a 2nd linked-collection
  reusing the same chip/roster shape. All landed as DOCUMENTED mirrors.
- **72f33c1 (D47) removed the LAST variance between `_PeopleSection` and `_AttendeesSection`**: the
  2 differing string literals were unified by the "attendees→People" copy pass (`'ATTENDEES'` →
  `'PEOPLE'`, `'Add contacts'` → `'Add people'`), and both gained the SAME `ring: true` plus an
  8-line **verbatim-identical** ring/radius rationale comment. `diff` of the two sections is now
  **3 lines, all the same identifier** (`contacts` vs `attendees`). Count held at 2 — this is not a
  distinct mechanism (no new collection), it is the same two sections converging, so Last Seen
  moves and count does not.
- Why it matters now: the "they'll diverge" rationale is empirically dead — a slice converged them.
  Extraction is nearly free (rename one field → byte-identical), and the duplicated comment means a
  future ring/radius fix must land twice. `learner` to weigh a parameterised
  `ChipSection`(label, avatarBuilder, chips) + a roster-row atom, à la MetaLine — against the
  author's stated per-collection-mirror preference. Reported SUGGESTION each time (non-blocking;
  deliberate documented mirrors).

## `_SwatchGrid` copied verbatim across sibling manager screens — WATCHING (count 1)
The palette-picker `Wrap`, copied task_categories_screen ⟷ event_types_screen; `diff` = zero bytes,
zero entity-specific variance. The author already reuses public `TypeSwatch` cross-screen, so
atom-sharing is understood here — `_SwatchGrid` is the one they copied. Won't be touched by the
documented Slice-B divergence (delete semantics), so the "will diverge" rationale doesn't cover it.
If a 3rd screen copies it rather than sharing → count 2 → RULE CANDIDATE (extract a `SwatchGrid`
into `lib/widgets/`, à la MetaLine). First/last seen 2026-07-15 (9377a61).

## Whole picker screen cloned — WATCHING (count 1)
`CategoryPickerScreen` (Slice B, d95f85b) self-describes as "A near-verbatim mirror of
`ContactPickerScreen`". Shares the entire scaffold: `late Future _future` + `_selected` id-map +
`_query` + `_toggle`/`_done`/`_filter` + FutureBuilder(waiting / error EmptyState / empty EmptyState
/ no-match EmptyState) + CheckboxListTile list. Differs only: model type, secondary widget
(`InitialsAvatar` vs `TypeSwatch`), search fields (name+company vs name-only), subtitle, AppBar
noun. Genericisable into `PickerScreen<T>`(fetch, avatarBuilder, searchOn, labels). Documented
mirror at N=2 pickers; a 3rd → count 2 → RULE CANDIDATE. **NOT** flagged for missing `_lastData`:
pickers load once in `initState` over an immutable list, so the list-screen stale-guard doesn't
apply.

## `TypeSwatch` lives in a screen file but is imported cross-screen — WATCHING (count 2)
`TypeSwatch` (a public UI atom) lives in `event_types_screen.dart` and is imported elsewhere via
`show TypeSwatch`. Slice B added 2 MORE importers (`category_picker_screen.dart`,
`task_form_screen.dart`) → 4 files now import a widget out of a *screen* file. This is reuse (good,
not a copy) but the home is wrong: a shared atom belongs in `lib/widgets/` beside `TypeDot`/
`TypeLabel`. Refactor candidate: promote it to `lib/widgets/type_label.dart` (or its own file) so no
screen imports a widget from another screen. First seen 2026-07-15 (slice-a task categories), last
2026-07-15 (d95f85b).

## Near-identical `CommentsRepository` impl per parent entity — WATCHING (count 1)
`SupabaseTaskCommentsRepository` is ~70 lines byte-identical to `SupabaseEventCommentsRepository`
bar 6 strings (table, FK alias column, `.eq` column, 4 RPC names). Fully parameterizable into one
class with table + fkColumn + rpcPrefix — BUT the interface docstring deliberately commits to
"N parent-specific implementations" as the pattern. Defensible/documented skip at N=2; extraction
pays off at N=3. Reported SUGGESTION only, not pushed. First/last seen 2026-07-14 (643bbeb).

## `backend/README.md` `## Verify:` intro names an RPC the block never exercises — WATCHING (count 1)
`## Verify: event write RPCs + the attendee parent-gate (D18)` (46a2cdc:247) opens "`create_event` /
`update_event` / `soft_delete_event` are the RPC write path" but calls only create + soft_delete.
Grep-verified: `rpc/update_event` appears **nowhere** in the README — the ONLY intro-named RPC in
all 11 Verify sections with zero curl coverage (update_task ×10, restore_task ×3,
update_task_comment ×2, restore_task_comment ×2, update_contact, update_event_type,
update_task_category all exercised). It also skips the "soft-delete then update_X → no_data_found"
guard-check every sibling section proves, though `update_event` HAS that guard
(20260710120300:101) and `$EID` is already soft-deleted 15 lines above → zero setup cost. Reported
ISSUE (the section's stated scope ≠ its contents). A 2nd such section → count 2 → RULE CANDIDATE
("a `## Verify:` intro may only name RPCs the block actually calls"). First/last seen 2026-07-17
(46a2cdc, issue #19 / D45).
