# code-reviewer — false-positive traps (full detail)

Read on demand. `MEMORY.md` keeps the one-line "do not flag" list; this file keeps the evidence for
each, so a future review can re-check rather than re-litigate. Every entry below was raised once and
found to be a false positive — do NOT flag them again.

## `EmptyState` is a full-screen panel — inline empties correctly hand-roll
`EmptyState` is a 64px icon, vertically centered, scrollable panel meant for a whole empty *screen*.
A small inline "No comments yet." / inline-error inside a sub-section of a *populated* screen (e.g.
`CommentsSection`) correctly hand-rolls a compact `Text`. The atom would look wrong inline. Do NOT
flag it as "re-implementing `EmptyState`".

## Snapshot partition / filter in `build()` is fine
`list.where((c) => !c.isArchived)` splitting a small already-fetched list into live/archived (or a
search filter over a snapshot) is trivial derived view-state, NOT the "heavy transform" that
checklist item #2 targets. Don't flag light filtering of a snapshot.

## Not a hard line cap
This project has none. A long file that is one cohesive concern (a full theme definition, a
many-field model, a 581-line form screen) is correct — say so explicitly instead of flagging it.
Judge by responsibility and nesting.

## Generated / platform files
`*.g.dart`, `*.freezed.dart`, `build/`, `.dart_tool/`, `android/…`, `ios/…`, `linux/…`, `web/…` are
not hand-authored — never flag them. (This project currently has no codegen; guard anyway.)

## Legit `StatefulWidget`
A screen that owns a `Future` / `_lastData` / `setState` is correct. Only flag a `State` with no
mutable field, no `initState`/`dispose`, and no `setState`.

## Hand-rolled private `_ErrorState` per list screen is the CONVENTION
Every list screen (`contacts_list_screen`, `calendar_screen`, `event_types_screen`,
`tasks_list_screen`) declares its own private `_ErrorState` (64px `cloud_off_outlined`, "Couldn't
load X", Retry). There is NO shared error atom — `lib/widgets/` has only `EmptyState` / `TypeLabel` /
`InitialsAvatar` / `MetaLine` / `DetailField`. The `error` field is passed-but-unused in ALL of them
(contacts included) — a codebase-wide convention, not new dead code. Do NOT flag a new list screen's
`_ErrorState` as "re-implementing a shared atom", nor its unused `error` field as a slice finding.
(Contrast with `_SwatchGrid`: per-screen TEXT variance = convention; zero variance = extractable.)

## `task_detail_screen`'s inline Notes block is NOT a re-implemented `_Field` / `DetailField`
The Notes block (`if (_task.notes != null && isNotEmpty) [SizedBox(24), Text('Notes', labelMedium),
SizedBox(6), Text(value, bodyLarge)]`) carries a comment saying it "mirrors the ContactDetailView row
style" — but structurally it is DISTINCT: no icon, no `Row`, no "Not added" fallback (it hides when
empty), different spacing (24/6 vs 20/16/2). It is a simpler one-off, unlike the byte-identical
`MetaLine`. **Still applies after `DetailField` was extracted (780c930)**: the block does NOT adopt
`DetailField` because that atom always renders a leading icon + Row. Do NOT flag it as "should now
use `DetailField`".

## `lib/util/` import order is the project convention, not out-of-order
`package:flutter/painting.dart` then `dart:ui show Brightness` — both `event_type_palette.dart` and
`importance.dart` (Decision 38) lead with the flutter import then the `dart:ui` show.
`directives_ordering` is NOT enabled in `analysis_options.yaml`, and `importance.dart` is explicitly
modeled on `event_type_palette.dart`. Do NOT flag it as a dart-before-package idiom miss — it mirrors
its sibling.

## `backend/README.md`: the bare `psql -c "…"` is not drift
The pre-auth-lockdown section's bare `psql -c "…"` is NOT an inconsistency with the newer
`docker compose exec -T db psql …` form. It predates the diff and is annotated "(as `postgres`, on
homebase inside the db container)" — a different execution context (already inside the container on
homebase) vs the local `docker compose exec` form the Verify blocks use. Do not flag either as drift
from the other.

## `backend/README.md`: leftover live rows are the norm, not a cleanup miss
The pre-auth lockdown block leaves contact "Ada" live; the null-embed block leaves "Quarterly
review"; the events block leaves contact "Grace". The documented practice is a freshly re-inited
stack (`docker compose down -v`), not per-block teardown. Do NOT flag "the block doesn't clean up".

## Out of scope entirely
- DB / RLS / SQL / secrets → `db-security-reviewer` + the `.githooks` secret scan. Never open
  `backend/migrations/`.
- Deep logic correctness (off-by-one, wrong grouping, a broken stale-guard condition) →
  `semantic-reviewer`. Flag *placement and structure*, not whether the computation is right.
- Anything `flutter analyze` / `flutter_lints` already reports (incl. most `prefer_const_constructors`
  hits) → the linter + `.githooks/pre-commit` cover it deterministically.
