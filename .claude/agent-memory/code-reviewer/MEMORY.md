# code-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring Dart/Flutter
> quality patterns and false positives for THIS project so future reviews focus where code actually
> drifts. This agent ALWAYS keeps the tracker table below. Curated at `/wrapup`.

## Tracker table (recurring findings — rows transition, never delete)

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Identical private detail-widget copied across screens (`_MetaLine` "Added X · Updated Y" muted date footer — same class in both detail screens, functionally byte-identical bar a `parts.isEmpty` guard). Unlike `_ErrorState` (per-screen variance = convention), this had zero variance → extractable atom. | 2026-07-14 (tasks view-first) | 2 | 2026-07-14 (acb0043) | PROMOTED → `lib/widgets/meta_line.dart` (`MetaLine`, extracted acb0043; the merged atom keeps task's `parts.isEmpty` guard, strictly safer for contacts whose call site already guarded). RESOLVED. |

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
  `InitialsAvatar`. Colour-as-data (Decision 19): colour never rides alone.
- **Naming:** files `snake_case`, classes/enums `PascalCase`.
- **New pure-Dart util/model → flag missing test only; `test-writer` writes it.**

## Known false-positive traps (do not flag these)
- **`EmptyState` is a full-screen panel** (64px icon, vertically centered, scrollable) meant for a
  whole empty *screen*. A small inline "No comments yet." / inline-error inside a sub-section of a
  populated screen (e.g. `_CommentsSection`) correctly hand-rolls a compact `Text` — do NOT flag it
  as "re-implementing `EmptyState`". The atom would look wrong inline.
- **Snapshot partition in `build()` is fine** — `list.where((c)=>!c.isArchived)` splitting a small
  already-fetched list into live/archived is trivial derived view-state, NOT the "heavy transform"
  item #2 targets. Don't flag light filtering of a snapshot.
- **Not a hard line cap** — a long file that is one cohesive concern is correct; do not flag length.
- **Generated / platform files** (`*.g.dart`, `*.freezed.dart`, `build/`, `android/…`, `web/…`) are
  not hand-authored — never flag them.
- **Legit `StatefulWidget`** — a screen that owns a `Future`/`_lastData`/`setState` is correct; only
  flag a `State` with no mutable field and no lifecycle.
- **Hand-rolled private `_ErrorState` per list screen is the CONVENTION, not a re-implemented atom.**
  Every list screen (`contacts_list_screen`, `calendar_screen`, `event_types_screen`,
  `tasks_list_screen`) declares its own private `_ErrorState` (64px `cloud_off_outlined`, "Couldn't
  load X", Retry). There is NO shared error atom (only `EmptyState`/`TypeLabel`/`InitialsAvatar` in
  `lib/widgets/`). The `error` field is passed-but-unused in ALL of them (contacts included) — a
  codebase-wide convention, not new dead code. Do NOT flag a new list screen's `_ErrorState` as
  "re-implementing a shared atom" or the unused `error` field as a task-slice finding.
- **Out of scope** — DB/RLS/SQL/secrets (`db-security-reviewer`), deep logic correctness
  (`semantic-reviewer`), lints `flutter analyze` already reports.

## Positive signals (reference-quality files — full detail in the topic file)
One-line pointers; specifics in [reference-implementations](topics/reference-implementations.md).
- **`event_form_screen.dart`** — reference form screen (flat `ListView`, every concern a small
  `StatelessWidget`, repo/time-math outside `build()`, mounted+captured-messenger in `_save`).
- **RPC-write repository pattern** — Decision 26 shape (`.rpc('create_x', model.toRpcParams())` →
  `id as String` → private `_fetchOne`; `update` spreads `{p_id, ...toRpcParams()}`). Per-entity
  divergences (comments' body-only `edit`; tasks' one-path `update`; comment model dropping
  `toRpcParams` when parent-agnostic) are EXPECTED — verify correct, don't flag as drift.
- **`tasks_list_screen.dart`** (58b2b5d) — reference list screen w/ collapsible sections; light
  snapshot partition in `_buildBody`, `_lastData` guard, three-state wide pane (acb0043).
- **`_Sidebar`/`_SidebarItem` in `home_shell.dart`** (4679504) — clean UI-chrome StatelessWidget
  extraction. Nit: nav record type repeated ×3 → a `typedef` would DRY it (SUGGESTION).
- **`ContactDetailView` in `contact_detail_screen.dart`** (16ed89e; Slice C 194ff12) — master-detail
  body split (thin host + shared no-Scaffold body); pure `_matches` search filter. Nit: list-pane
  width `320` a bare literal coupled to `640` → a `kListPaneWidth` const would be refactor-safe.
- **`task_detail_screen.dart`** (cfbfe7f) — view-first detail; shared `SubtleButton`/`MetaLine`
  atoms; `_StatusPill` NEW local widget (label-paired dot, not colour-as-data).
- **`CommentsSection` in `lib/widgets/comments_section.dart`** (078d03c, Slice 2a) — reference shared
  stateful sub-section, extracted verbatim from `event_detail_screen.dart`, now parent-agnostic
  (`CommentsRepository`+`parentId`); own `_lastData` stale-guard; inline empty/error correctly
  hand-rolled (not `EmptyState`); grep-confirmed zero stale old-name refs.
