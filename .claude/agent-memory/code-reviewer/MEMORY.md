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
- **`task_detail_screen`'s inline Notes block is NOT a re-implemented `_Field` atom.** The detail
  Notes block (`if (_task.notes!=null && isNotEmpty) [SizedBox(24), Text('Notes',labelMedium),
  SizedBox(6), Text(value,bodyLarge)]`) says in a comment it "mirrors the ContactDetailView row
  style" — but structurally it is DISTINCT from contact_detail's private `_Field` (which is an
  icon + `Row` + "Not added" fallback + onSurfaceVariant colour, spacing 20/2). Notes has no icon,
  no Row, no fallback (hides when empty), different spacing. Do NOT flag it as duplicating `_Field`
  or as an extractable shared atom — it is a simpler one-off, unlike the byte-identical `MetaLine`.
- **Out of scope** — DB/RLS/SQL/secrets (`db-security-reviewer`), deep logic correctness
  (`semantic-reviewer`), lints `flutter analyze` already reports.

## Positive signals — reference-quality slices to compare against
Full detail in [positive-signals](topics/positive-signals.md). One-line index:
- **`event_form_screen.dart`** — the form-screen reference (flat `ListView`, every concern a small
  private `StatelessWidget`, repo/time-math out of `build()`, messenger/nav captured before await).
- **RPC-write repository pattern** — `create`/`update` → `_client.rpc(...)` + `_fetchOne(id)`;
  `toRpcParams()` `p_`-prefixed; per-entity divergences (comments' body-only `edit`, tasks' explicit
  `update`) are EXPECTED, verify-don't-flag. Task notes slice (5cfc2b3) = clean scalar-field-add.
- **`tasks_list_screen.dart`** / **`contacts_list_screen` (Slices B/C)** — list-screen reference:
  `_lastData` stale-guard, `mounted`-after-await, light snapshot `where` partition/search (NOT a
  heavy transform), `EmptyState` + hand-rolled `_ErrorState`, master-detail `ValueKey` remount.
- **`_Sidebar`/`_SidebarItem` (`home_shell.dart`)** — clean UI-chrome `StatelessWidget` extraction.
- **`task_detail_screen.dart` / `ContactDetailView`** — view-first detail reference: thin
  Scaffold host + shared body that NEVER pops, reuses `SubtleButton`/`MetaLine`, `_StatusPill` is
  label-paired (not colour-as-data).
- **`_CommentsSection` (`event_detail_screen.dart`)** — inline stateful sub-section with its own
  `_lastData` load + `identical(future,_future)` stale checks; method-extraction in `build()`.
