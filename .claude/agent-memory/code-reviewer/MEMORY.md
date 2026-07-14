# code-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring Dart/Flutter
> quality patterns and false positives for THIS project so future reviews focus where code actually
> drifts. This agent ALWAYS keeps the tracker table below. Curated at `/wrapup`.

## Tracker table (recurring findings — rows transition, never delete)

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| Identical private detail-widget copied across screens (`_MetaLine` "Added X · Updated Y" muted date footer — same class in `contact_detail_screen.dart:282` AND `task_detail_screen.dart:447`, functionally byte-identical bar a `parts.isEmpty` guard). Unlike `_ErrorState` (per-screen variance = convention), this has zero variance → extractable atom. | 2026-07-14 (tasks view-first) | 2 | 2026-07-14 (tasks view-first) | RULE CANDIDATE — count 2, propose promoting to `lib/widgets/meta_line.dart` (learner). SUGGESTION only, non-blocking. |

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

## Positive signals
- **`event_form_screen.dart`** — reference-quality form screen. `build()` composes a flat
  `ListView`; every visual concern extracted to a small private `StatelessWidget`
  (`_AllDayRow`, `_ValueField`, `_AttendeesSection`, `_TypeField`, `_TypePickerSheet`). Repo
  calls + time math live outside `build()`; every `await` has a `mounted` guard;
  `ScaffoldMessenger`/`Navigator` captured before the await in `_save`. Reuses `InitialsAvatar`
  / `TypeLabel` / `TypeDot` (colour-as-data honoured). 581 lines = one cohesive concern, NOT a
  cap violation. Use as the pattern to compare other form screens against.
- **RPC-write repository pattern** (`SupabaseEventsRepository`, `SupabaseContactsRepository`
  after Slice 1, `SupabaseEventTypesRepository` after Slice 2, `SupabaseCommentsRepository` after
  Slice 3 — Decision 26 migration now COMPLETE, no remaining direct-write repos) — reference shape for routing writes through SECURITY DEFINER
  RPCs: `create`/`update` call `_client.rpc('create_x', params: model.toRpcParams())`, cast the
  returned id `as String`, then re-`select` via a private `_fetchOne(id)` so callers get
  server-populated timestamps; `update` spreads `{'p_id': id, ...toRpcParams()}`. Model exposes
  `toRpcParams()` with `p_`-prefixed keys (name trimmed client-side belt-and-suspenders, optional
  text sent raw for the DB's `nullif(trim())` to normalize in one place). Slice 2 (event_types)
  landed 20970ea as a byte-faithful mirror (create → `.rpc('create_event_type')` + `id as String`
  + `_fetchOne`; update spreads `{'p_id': id, ...toRpcParams()}`; model `toRpcParams()` with
  `p_name`/`p_color`, name trimmed client-side) — reviewed CLEAN. Slice 3 (event_comments) landed
  3296258, reviewed CLEAN — a faithful mirror WITH two flagged-and-correct per-entity divergences:
  (a) `edit()` builds `{p_id, p_body}` EXPLICITLY rather than spreading `toRpcParams()` (which
  carries `p_event_id` → a body-only `update_comment` lacks it); (b) `archive`/`unarchive` refetch
  and return `Comment` (not `void` like contacts' `softDelete`) because the interface returns
  `Comment` and `using(true)` keeps the archived row selectable so `_fetchOne` succeeds post-delete.
  `_setDeletedAt` cleanly retired → `_fetchOne`; no orphaned helper/dartdoc; model `[toWrite]`→
  `[toRpcParams]` dartdoc + test group renamed in-slice. Divergences from the template are EXPECTED
  on a per-entity RPC port — verify they're correct, don't flag them as drift. Slice "Tasks (v0)"
  (58b2b5d, Decision 27) — NEW table adopting the same RPC-write shape by choice ("for uniformity,
  not necessity" — `using(true)` means a direct write would've worked). `SupabaseTasksRepository`
  reviewed CLEAN: `create` spreads `toRpcParams()` ({p_title} only, matches `create_task`);
  `update` builds explicit `{p_id,p_title,p_is_done}` (one write path serves both the form save AND
  the list complete-toggle — a correct, flagged divergence like comments' body-only `edit`);
  `archive`/`restore` return `Task` via `_fetchOne`. Model `task.dart` = pure-Dart mirror of
  `comment.dart` (isArchived, copyWith, toRpcParams, Task.draft).
- **`tasks_list_screen.dart`** (58b2b5d) — reference-quality list screen with collapsible sections.
  `build()` composes; `_buildBody` does light snapshot partition (`where` on the fetched list into
  active/completed/archived — trivial derived view-state, NOT a heavy transform). `_lastData`
  stale-guard + `mounted` guards after every await (`_openForm`, `_toggleDone`); `initState` marks
  `unawaited(_load())`; `_toggleDone` captures messenger before the await. `EmptyState` for the
  whole-screen empty; hand-rolls `_ErrorState` (the convention). Mono `_CheckCircle` (accent = ink,
  no colour-as-data). `task_form_screen.dart` mirrors `event_form_screen`/`ContactFormScreen`:
  messenger+navigator captured before await, `_runMutation` helper for archive/restore, `_saving`
  gate via `AbsorbPointer`. All four new files tested in-slice.
- **`_Sidebar` / `_SidebarItem` in `home_shell.dart`** (4679504, Decision 28) — reference-quality
  UI-chrome extraction. Two small `StatelessWidget`s (correctly stateless — no state/lifecycle);
  parent `build()` composes a `Row`, no logic/async. Const applied where eligible (subtree pulls
  `scheme.*` so the brand `Container`/`Text` can't be const — correct). C⁺ mark is a single
  occurrence, not duplicated → no shared-widget extraction warranted yet. Widget test shipped
  in-slice. Only nit: the inline nav record type `({IconData icon, IconData selected, String label})`
  is repeated in 3 spots — a `typedef` would DRY it (SUGGESTION, idiom).
- **`ContactDetailView` extraction in `contact_detail_screen.dart`** (16ed89e, Decision 28 Slice B)
  — reference-quality body-widget extraction for master-detail. `ContactDetailScreen` becomes a thin
  `Scaffold`+`PopScope` host owning the changed/delete back-signal; the shared body `ContactDetailView`
  (no Scaffold, NEVER pops, reports via `onChanged`/`onDeleted`) renders identically full-screen and in
  the desktop pane. `build()` composes (`Align`→`ConstrainedBox(maxWidth:720)`→`_body`); `_body` is a
  method-extraction (allowed by item #1). Both widgets legit `StatefulWidget` (`_contact`/`_deleting`/
  `_dirty` + lifecycle). List screen's `_loaded(contacts)` extracts the LayoutBuilder one-pane/two-pane
  branch; selection resolved by id via `where(...).isEmpty ? first : first` (dependency-free, light
  snapshot filter — NOT a heavy transform); `ContactDetailView(key: ValueKey(selected.id))` remounts on
  swap. Selection highlight uses theme tokens (`primaryContainer`/`onSurface`) = chrome, not
  colour-as-data. `kTwoPaneBreakpoint=640` const extracted + documented; hand-rolled `_ErrorState` = the
  convention; `EmptyState`/`InitialsAvatar` reused; new `_MetaLine` (muted date footer, no atom exists).
  `_edit` GAINED `if(!mounted)return` before its post-`await` setState (improvement). Widget test shipped
  in-slice. Only nit (low-value SUGGESTION): the list-pane width `320` is a bare literal semantically
  coupled to `640` (breakpoint comment says "640 = 320 + ≥320") — a `kListPaneWidth` const would make a
  future width change refactor-safe; `720` reading-cap is fine as a single commented use.
  **Slice C (194ff12)** — reviewed CLEAN. `build()` composes LayoutBuilder→Scaffold→FutureBuilder
  (`appBar`/`FAB` null on wide) → delegates to `_loaded(wide, contacts)`; search is a light snapshot
  filter (`contacts.where(_matches)` on the already-fetched small list) via a pure `_matches(c,q)`
  predicate method — well-placed, NOT the item-#2 heavy transform. New `_MasterHeader`/`_NoMatches`
  are clean `StatelessWidget` extractions (no state/lifecycle → correct); `_NoMatches` reuses the
  `EmptyState` atom. State owns+disposes the `_search` `TextEditingController` (a controller not a
  mirror String, so a programmatic clear updates the field). Const applied where eligible (theme
  reads block const on the header subtree — correct). `_MasterHeader`'s inline styling literals
  (padding 16/16/16/12, gaps 8/12, icon 18/20) are one-off local values, NOT cross-widget semantic
  constants like `kListPaneWidth`/`kTwoPaneBreakpoint` — no extraction warranted. Native/web title
  swaps to "CRM+" consistent across all four strings (.cc ×2, index.html ×2, manifest ×2).
- **`task_detail_screen.dart` (cfbfe7f, Decision 29)** — reference-quality view-first detail, mirrors
  `ContactDetailScreen`/`ContactDetailView`. Thin `TaskDetailScreen` host (legit stateful: `_dirty` +
  lifted `late _task` seeding the AppBar title + setState in `onChanged`); shared body `TaskDetailView`
  (legit stateful: `_task`/`_busy` + initState) has no Scaffold and NEVER pops. `build()` composes
  (`AbsorbPointer`→`Align`→`ConstrainedBox(560)`→`ListView`); all repo mutations in `_run`/`_edit` —
  none in build. `mounted` guards after every await; `_run` captures messenger before the await;
  `_edit` guards `updated==null || !mounted`. Reuses new shared `SubtleButton` atom for Edit/Complete/
  Reopen/Archive/Restore. `_StatusPill` (Active/Completed/Archived) is a NEW local widget — not
  colour-as-data (dot always paired with a text label; muted-vs-ink tokens, not per-type colour) and
  no existing status-pill atom to reuse (event_detail's circular(999) is a comment-count badge, not a
  status pill). Only nit: `_MetaLine` duplicates contact_detail's identical private copy (tracker row).
  `SubtleButton` (`lib/widgets/subtle_button.dart`) is a clean shared atom — exists because theme's
  `filledButtonTheme` pins even `FilledButton.tonal` to `scheme.primary` (intentional, not a finding).
  `task_form_screen.dart` correctly shrank to title-only (dropped Switch/archive/restore/showHeader);
  `tasks_list_screen.dart` reversed the in-pane editor to a read-only detail cleanly (dropped
  `_creatingNew`/`_onEditorChanged` optimistic patch — the detail's own setState makes it unnecessary).
- **`_CommentsSection` in `event_detail_screen.dart`** — reference-quality inline stateful
  sub-section. `build()` is a `FutureBuilder` composing `_header`/`_composerRow`/`_liveTile`/
  `_archivedSection` helpers (method-extraction, which item #1 allows alongside StatelessWidgets).
  Owns its own `_lastData` stale-guard load with `identical(future,_future)` stale-fetch checks and
  `mounted` guards before any `context`/`setState` access after an await (`_load` assigns `_lastData`
  post-await unguarded — a plain field write, safe); `_run` captures the messenger before the await. Legit
  `StatefulWidget` (controllers + `_future` + `setState`). Comments are mono — no colour-as-data.
  Model (`comment.dart`) + repo (`comments_repository.dart`) follow the pure-Dart-model /
  abstract-interface-repository split; tests shipped in the same commit.
