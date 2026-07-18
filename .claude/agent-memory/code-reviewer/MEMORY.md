# code-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring Dart/Flutter
> quality patterns and false positives for THIS project so future reviews focus where code actually
> drifts. This agent ALWAYS keeps the tracker table below. Curated at `/wrapup`.
> **This file is an INDEX** — one line per entry; evidence lives in `topics/*.md`.

## Tracker table (recurring findings — rows transition, never delete)
Evidence + full history for every row: [duplication-tracker](topics/duplication-tracker.md).

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| `_MetaLine` — "Added X · Updated Y" footer, zero-variance copy in both detail screens | 2026-07-14 | 2 | 2026-07-14 (acb0043) | PROMOTED → `lib/widgets/meta_line.dart`. RESOLVED. |
| `_Field` — labelled detail-field row, copied AND diverged (contact vs event detail) | 2026-07-16 | 2 | 2026-07-16 (780c930) | PROMOTED → `lib/widgets/detail_field.dart` (D43). RESOLVED. |
| **Chip-section / roster widget duplicated per linked-collection** — `_PeopleSection` ⟷ `_AttendeesSection`, `_PeopleList` ⟷ `_AttendeeList`, + Slice-B's `_Categories*` mirrors | 2026-07-14 | 2 | 2026-07-17 (72f33c1) | **RULE CANDIDATE.** 72f33c1 removed the LAST variance (copy pass unified both string literals; both gained `ring: true` + an 8-line verbatim-identical comment) → `diff` = 3 lines, all one identifier. Count held at 2 (same sections converging, not a new mechanism). `learner`: weigh a parameterised `ChipSection` + roster-row atom. |
| `_SwatchGrid` — palette-picker `Wrap` copied verbatim (zero bytes differ) across the 2 manager screens | 2026-07-15 | 1 | 2026-07-15 (9377a61) | WATCHING — SUGGESTION. 3rd copy → count 2 → extract `SwatchGrid`. |
| Whole picker screen cloned — `CategoryPickerScreen` = near-verbatim `ContactPickerScreen` | 2026-07-15 | 1 | 2026-07-15 (d95f85b) | WATCHING — SUGGESTION. 3rd picker → count 2 → extract `PickerScreen<T>`. |
| `TypeSwatch` is a public atom living in `event_types_screen.dart`, imported cross-screen (2 → 4 importers) | 2026-07-15 | 2 | 2026-07-15 (d95f85b) | WATCHING — SUGGESTION. Promote to `lib/widgets/`; no screen should import a widget from another screen. |
| Near-identical `CommentsRepository` impl per parent entity (~70 lines, 6 strings differ) | 2026-07-14 | 1 | 2026-07-14 (643bbeb) | WATCHING — SUGGESTION, not pushed (interface docstring commits to per-parent impls). 3rd → count 2. |
| `backend/README.md` `## Verify:` intro names an RPC the block never exercises (`update_event`) | 2026-07-17 | 1 | 2026-07-17 (46a2cdc) | WATCHING — reported ISSUE. 2nd → count 2 → rule: an intro may only name RPCs the block calls. |
| **`PaneHeader` header-strip wrapper duplicated per detail view** — the `Column([PaneHeader, Divider(height:1, outlineVariant), Expanded(child: body)])` compose (incl. a byte-identical Divider the atom's own docstring already claims as part of it) copied in `contact_detail_screen`:209 ⟷ `task_detail_screen`:332 | 2026-07-17 | 2 | 2026-07-17 (e5e1b29) | RULE CANDIDATE — both panes born with it (count 2 on landing). SUGGESTION: fold the Divider into `PaneHeader`; a 3rd pane → extract the whole `Column` wrapper (a `PaneScaffold`). |

## Durable knowledge (this project's conventions to check against)
- **No hard line caps.** Judge structure by responsibility/nesting, not length. A long
  single-concern file (theme, a many-field model) is fine — say so, don't flag it.
- **`build()` composes; it does not fetch or compute.** Supabase/repo calls live in
  `lib/data/*_repository.dart`; heavy transforms in `lib/models/` or `lib/util/`. Flag placement
  only — logic correctness is `semantic-reviewer`'s.
- **List-screen state pattern:** `StatefulWidget` + `FutureBuilder` + `_lastData` stale-guard +
  `if (!mounted) return` after awaits (`calendar_screen.dart`, `contacts_list_screen.dart`,
  `event_types_screen.dart`). A new list screen should match it.
- **Shared atoms to reuse, not re-implement:** `EmptyState`, `TypeLabel`/`TypeDot`,
  `InitialsAvatar`, `MetaLine`, `DetailField`. Colour-as-data (D19): colour never rides alone.
- **Naming:** files `snake_case`, classes/enums `PascalCase`.
- **`ymd()` (`util/format.dart`) is the WIRE serializer + a day-grouping map key — NEVER a display
  format** (D47, 72f33c1). User-facing dates come from `util/calendar.dart`: `displayDate`
  ("13 Apr 1974") · `displayDateNoYear` ("9 Jul") · `longDate` ("Fri, 17 Jul 2026"). **Flag any NEW
  `ymd()` at a UI site** (a `Text`, a label, a `DetailField.value`) — that leak is what D47 fixed.
  Legit non-UI callers: `models/contact.dart` (`p_dob`), `models/event.dart` (`p_event_date`),
  `calendar_screen.dart` map keys (:257/:263/:1243). Date-then-time order ("9 Jul · 14:32").
- **`backend/README.md` `## Verify:` convention** (11 sections, checked 46a2cdc): heading
  `## Verify: <topic> (Decision N[, Slice X])` → prose intro naming the RPCs → fenced ```bash block
  that **re-declares its own `ANON=`/`REST=` preamble and mints its own ids** (never borrows a
  variable across blocks). Superuser reads are
  `docker compose exec -T db psql -U postgres -d postgres -tAc "…"` (cwd = `backend/`, service `db`).
  Expected output rides in a trailing `# -> …` comment; uuid placeholders are **`<uuid>`**, not
  `<$VAR>`. Two fenced blocks per section is allowed.
- **New pure-Dart util/model → flag missing test only; `test-writer` writes it.**

## Known false-positive traps (do not flag — evidence in [false-positives](topics/false-positives.md))
- `EmptyState` is a full-screen panel; a small inline empty/error inside a populated screen
  correctly hand-rolls a compact `Text`.
- Light snapshot filtering/partition in `build()` (`where((c) => !c.isArchived)`) is view-state,
  not a heavy transform.
- Length alone is never a finding; generated/platform files are never a finding.
- A `StatefulWidget` owning a `Future`/`_lastData`/`setState` is correct.
- A per-list-screen private `_ErrorState` (and its passed-but-unused `error` field) is the
  CONVENTION — there is no shared error atom.
- `task_detail_screen`'s inline Notes block is NOT a `_Field`/`DetailField` re-implementation.
- `lib/util/`'s `package:flutter/painting.dart` → `dart:ui show Brightness` order is the convention.
- `backend/README.md`: the bare `psql -c` (different context) and leftover live rows (the stack is
  re-inited, not torn down per block) are both fine.
- **Out of scope** — DB/RLS/SQL/secrets (`db-security-reviewer`), deep logic correctness
  (`semantic-reviewer`), lints `flutter analyze` already reports.

## Topic pointers
- [duplication-tracker](topics/duplication-tracker.md) — evidence behind every tracker row; the
  "byte-identical private widget copied, not shared" meta-pattern and its 4 instances.
- [false-positives](topics/false-positives.md) — the full case for each do-not-flag entry above.
- [positive-signals](topics/positive-signals.md) — reference-quality slices to compare new code
  against: `event_form_screen` (form ref), the RPC-write repository pattern, `tasks_list_screen` /
  `contacts_list_screen` (list ref), `_Sidebar` (chrome extraction), `test/support/fakes.dart`
  (shared-fake consolidation), task importance `3bf48ea` (scalar-field-add), idempotent `create_*`
  (#9/D41), `CommentsSection` `2717da9` (shared stateful sub-section), UI consistency pass `72f33c1`
  (root-cause fix — fix the leak AND document the source).
