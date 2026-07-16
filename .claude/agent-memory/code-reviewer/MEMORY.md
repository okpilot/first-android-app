# code-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring Dart/Flutter
> quality patterns and false positives for THIS project so future reviews focus where code actually
> drifts. This agent ALWAYS keeps the tracker table below. Curated at `/wrapup`.

## Tracker table (recurring findings — rows transition, never delete)

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Identical private detail-widget copied across screens (`_MetaLine` "Added X · Updated Y" muted date footer — same class in both detail screens, functionally byte-identical bar a `parts.isEmpty` guard). Unlike `_ErrorState` (per-screen variance = convention), this had zero variance → extractable atom. | 2026-07-14 (tasks view-first) | 2 | 2026-07-14 (acb0043) | PROMOTED → `lib/widgets/meta_line.dart` (`MetaLine`, extracted acb0043; the merged atom keeps task's `parts.isEmpty` guard, strictly safer for contacts whose call site already guarded). RESOLVED. |
| Near-identical **chip-section / roster widget** duplicated per linked-collection (Slices: link contacts to tasks; link categories to tasks). `_PeopleSection` (task_form) vs `_AttendeesSection` (event_form) differ by only 2 string literals — byte-identical Wrap-of-InputChips. `_PeopleList` (task_detail) vs `_AttendeeList` (event_detail): per-item roster Row byte-identical. Slice B (d95f85b) added `_CategoriesSection` (task_form, "Mirrors `_PeopleSection`", differs only: label CATEGORIES/PEOPLE, avatar `TypeSwatch`/`InitialsAvatar`, button copy/icon) + `_CategoriesList` (task_detail, "Mirrors `_PeopleList`", differs: header noun, `TypeDot+Text` vs avatar). All landed as DOCUMENTED mirrors. Same shape as the `MetaLine` extraction (PROMOTED). | 2026-07-14 (link contacts to tasks) | 2 | 2026-07-15 (d95f85b) | RULE CANDIDATE (count→2, distinct mechanism: categories add a 2nd linked-collection reusing the same chip/roster shape). Reported SUGGESTION (non-blocking; deliberate documented mirrors). `learner` to weigh a parameterised `ChipSection`(label, avatarBuilder, chips) + roster-row atom, à la MetaLine — vs the author's stated per-collection-mirror preference. |
| Byte-identical **private UI atom** copied across sibling manager screens instead of shared (`_SwatchGrid` — the palette-picker `Wrap` — copied verbatim task_categories_screen ⟷ event_types_screen; `diff` = zero bytes, zero entity-specific variance). Same MECHANISM as the PROMOTED `MetaLine`: unlike `_EmptyState`/`_ErrorState` (per-screen TEXT variance = convention), this has NO variance → extractable. Author already reuses public `TypeSwatch` (imported cross-screen), so atom-sharing is understood here — `_SwatchGrid` is the one they copied. Won't be touched by the documented Slice-B divergence (delete semantics), so the "will diverge" rationale doesn't cover it. | 2026-07-15 (slice-a task categories) | 1 | 2026-07-15 (9377a61) | WATCHING — reported SUGGESTION (non-blocking). Meta-pattern "byte-identical zero-variance private widget copied not shared" now has 2 instances repo-wide (MetaLine PROMOTED + this). If a 3rd screen copies `_SwatchGrid`/`TypeSwatch` rather than sharing, count→2 → RULE CANDIDATE (extract a `SwatchGrid`/`TypeSwatch` picker into `lib/widgets/`, à la MetaLine). |
| Whole **searchable multi-select picker screen** cloned (`CategoryPickerScreen`, Slice B d95f85b, "A near-verbatim mirror of `ContactPickerScreen`"). Shares the entire scaffold: `late Future _future` + `_selected` id-map + `_query` + `_toggle`/`_done`/`_filter` + FutureBuilder(waiting/error EmptyState/empty EmptyState/no-match EmptyState) + CheckboxListTile list. Differs only: model type, secondary widget (`InitialsAvatar` vs `TypeSwatch`), search fields (name+company vs name-only), subtitle, AppBar noun. Genericisable into `PickerScreen<T>`(fetch, avatarBuilder, searchOn, labels). | 2026-07-15 (link categories to tasks) | 1 | 2026-07-15 (d95f85b) | WATCHING — reported SUGGESTION (non-blocking); documented mirror at N=2 pickers (contact + category). If a 3rd picker lands, count→2 → RULE CANDIDATE (extract `PickerScreen<T>`). NOT flagged for missing `_lastData`: pickers load once in `initState` over an immutable list (like `ContactPickerScreen`), so the list-screen stale-guard doesn't apply. |
| `TypeSwatch` (public UI atom) lives in `event_types_screen.dart` but is imported cross-screen via `show TypeSwatch`; Slice B added 2 MORE importers (`category_picker_screen.dart`, `task_form_screen.dart`) → now 4 files import a widget out of a *screen* file. Reuse (good, not a copy) but the home is wrong: a shared atom belongs in `lib/widgets/` beside `TypeDot`/`TypeLabel`. | 2026-07-15 (slice-a task categories) | 2 | 2026-07-15 (d95f85b) | WATCHING — reported SUGGESTION (non-blocking). Growing cross-screen coupling (2 importers → 4). `learner`/refactor candidate: promote `TypeSwatch` to `lib/widgets/type_label.dart` (or its own file) so no screen imports a widget from another screen. |
| Near-identical `CommentsRepository` impl duplicated per parent entity (`SupabaseTaskCommentsRepository` is ~70 lines byte-identical to `SupabaseEventCommentsRepository` bar 6 strings: table, FK alias column, `.eq` column, 4 RPC names). Fully parameterizable into one class w/ table+fkColumn+rpcPrefix — BUT the interface docstring deliberately commits to "N parent-specific implementations" as the pattern. Defensible/documented skip at N=2; extraction pays off at N=3. | 2026-07-14 (Slice 2b) | 1 | 2026-07-14 (643bbeb) | WATCHING — reported as SUGGESTION only, not pushed (deliberate documented choice). If a 3rd parent-comments repo lands, count→2, RULE CANDIDATE. |

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
- **`lib/util/` import order `package:flutter/painting.dart` then `dart:ui show Brightness` is the
  project convention, NOT out-of-order.** Both `event_type_palette.dart` and `importance.dart`
  (Decision 38) lead with the flutter import then `dart:ui show Brightness`. `directives_ordering`
  is NOT enabled in `analysis_options.yaml`, and importance.dart is explicitly modeled on
  event_type_palette. Do NOT flag it as a dart-before-package idiom miss — it mirrors the sibling.
- **Out of scope** — DB/RLS/SQL/secrets (`db-security-reviewer`), deep logic correctness
  (`semantic-reviewer`), lints `flutter analyze` already reports.

## Positive signals — reference-quality slices to compare against
Full detail in [positive-signals](topics/positive-signals.md). One-line index:
- **`event_form_screen.dart`** — the form-screen reference (flat `ListView`, every concern a small
  private `StatelessWidget`, repo/time-math out of `build()`, messenger/nav captured before await).
- **RPC-write repository pattern** — `create`/`update` → `_client.rpc(...)` + `_fetchOne(id)`;
  `toRpcParams()` `p_`-prefixed; per-entity divergences (comments' body-only `edit`, tasks' explicit
  `update`, comment model dropping `toRpcParams` when parent-agnostic — Slice 2a) are EXPECTED,
  verify-don't-flag. Task notes slice (`4d3d6b8`) = clean scalar-field-add.
- **`tasks_list_screen.dart`** / **`contacts_list_screen` (Slices B/C)** — list-screen reference:
  `_lastData` stale-guard, `mounted`-after-await, light snapshot `where` partition/search (NOT a
  heavy transform), `EmptyState` + hand-rolled `_ErrorState`, master-detail `ValueKey` remount.
- **`_Sidebar`/`_SidebarItem` (`home_shell.dart`)** — clean UI-chrome `StatelessWidget` extraction.
- **Task importance slice (`3bf48ea`, Decision 38)** — reference scalar-field-add + fixed-scale
  colour: `int importance` threaded through `Task` (draft/fromJson/toRpcParams/copyWith, defaults
  0, `copyWith` preserves it so complete-toggle can't reset), repo `p_importance` + `.order` sort
  (compute in the query, NOT build()), new pure-Dart `lib/util/importance.dart` (with test) +
  `ImportanceMarks` widget + `_ImportanceSection`/`_ImportanceSegment` well-extracted
  StatelessWidgets. Colour paired with `!` glyph + `Semantics` label = a FIXED semantic scale, not
  Decision-19 user colour-as-data (correctly documented). CLEAN 0/0/0.
- **`task_detail_screen.dart` / `ContactDetailView`** — view-first detail reference: thin
  Scaffold host + shared body that NEVER pops, reuses `SubtleButton`/`MetaLine`, `_StatusPill` is
  label-paired (not colour-as-data).
- **Idempotent create_* slice (issue #9 / Decision 41)** — reference id-minting + `.draft` factory
  conversion: new `lib/util/ids.dart` (single shared `const _uuid = Uuid()` + `newEntityId()`, private
  instance, tested with a v4-regex + 1000-distinct check); 6 models' `.draft` const-ctor → id-minting
  `factory` (`id: id ?? newEntityId()`, delegates to the main ctor); `toRpcParams()` gains `p_id` so the
  5 update repos drop `{p_id: …, ...spread}` and pass `toRpcParams()` whole; forms hold
  `late final String _pendingId = newEntityId()` (fresh State per open), while the long-lived
  `CommentsSection` composer holds a MUTABLE `_pendingId` reset after each success (correct, documented).
  Mint lives in util not build(); directive order + comments clean. CLEAN 0/0/0.
- **`CommentsSection` (`lib/widgets/comments_section.dart`, Slice 2a `2717da9`)** — reference shared
  stateful sub-section, extracted verbatim from `event_detail_screen.dart`, now parent-agnostic
  (`CommentsRepository`+`parentId`); own `_lastData` + `identical(future,_future)` stale-guard;
  inline empty/error hand-rolled (not `EmptyState`); grep-confirmed zero stale old-name refs.
