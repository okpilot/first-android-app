# Reference implementations (detail behind MEMORY.md's Positive signals one-liners)

Full detail for the reference-quality files code-reviewer compares new work against. MEMORY.md
keeps a one-line pointer per entry; the load-bearing specifics live here.

## `event_form_screen.dart` — reference form screen
`build()` composes a flat `ListView`; every visual concern extracted to a small private
`StatelessWidget` (`_AllDayRow`, `_ValueField`, `_AttendeesSection`, `_TypeField`,
`_TypePickerSheet`). Repo calls + time math live outside `build()`; every `await` has a `mounted`
guard; `ScaffoldMessenger`/`Navigator` captured before the await in `_save`. Reuses `InitialsAvatar`
/ `TypeLabel` / `TypeDot` (colour-as-data honoured). 581 lines = one cohesive concern, NOT a cap
violation.

## RPC-write repository pattern
`SupabaseEventsRepository`, `SupabaseContactsRepository` (Slice 1), `SupabaseEventTypesRepository`
(Slice 2), event-comments (Slice 3), `SupabaseTasksRepository` (Decision 27) — Decision 26 migration
COMPLETE, no remaining direct-write repos. Reference shape: `create`/`update` call
`_client.rpc('create_x', params: model.toRpcParams())`, cast returned id `as String`, then
re-`select` via a private `_fetchOne(id)` so callers get server-populated timestamps; `update`
spreads `{'p_id': id, ...toRpcParams()}`. Model exposes `toRpcParams()` with `p_`-prefixed keys
(name trimmed client-side belt-and-suspenders; optional text sent raw for the DB's `nullif(trim())`).
- Slice 2 (event_types) 20970ea — byte-faithful mirror, reviewed CLEAN.
- Slice 3 (event_comments) 3296258 — CLEAN with two flagged-and-correct per-entity divergences:
  (a) `edit()` builds `{p_id, p_body}` EXPLICITLY not `...toRpcParams()` (body-only `update_comment`
  must not carry `p_event_id`); (b) `archive`/`unarchive` refetch + return `Comment` (not `void`)
  because `using(true)` keeps the archived row selectable so `_fetchOne` succeeds post-delete.
- Slice "Tasks (v0)" 58b2b5d — NEW table adopting the shape by choice ("uniformity, not necessity").
  `create` spreads `toRpcParams()` ({p_title}); `update` builds explicit `{p_id,p_title,p_is_done}`
  (one write path serves form save AND list complete-toggle); `archive`/`restore` return `Task`.
- **Divergences from the template are EXPECTED on a per-entity port — verify correct, don't flag as drift.**
- **Comment repo (Slice 2a, 078d03c)** dropped `toRpcParams` from the model (now parent-agnostic):
  each repo builds its own `p_event_id`/`p_task_id` params inline — correct placement, NOT drift.

## `tasks_list_screen.dart` (58b2b5d) — reference list screen w/ collapsible sections
`build()` composes; `_buildBody` does light snapshot partition (`where` into active/completed/
archived — trivial derived view-state, NOT a heavy transform). `_lastData` stale-guard + `mounted`
guards after every await; `initState` marks `unawaited(_load())`; `_toggleDone` captures messenger
before await. `EmptyState` for whole-screen empty; hand-rolls `_ErrorState` (convention). Mono
`_CheckCircle` (accent = ink, no colour-as-data). `task_form_screen.dart` mirrors
`event_form_screen`: messenger+navigator captured before await, `_runMutation` helper, `_saving`
gate via `AbsorbPointer`. Later (Decision 29) the wide pane shows read-only detail for the selected
task; acb0043 reintroduced `_creatingNew` for the wide **New** in-pane form (narrow still pushes) —
clean three-state pane (detail / create-form / empty prompt).

## `_Sidebar` / `_SidebarItem` in `home_shell.dart` (4679504, Decision 28) — UI-chrome extraction
Two small `StatelessWidget`s (correctly stateless); parent `build()` composes a `Row`, no
logic/async. Const applied where eligible (subtree pulls `scheme.*` so brand `Container`/`Text`
can't be const — correct). Nit: inline nav record type
`({IconData icon, IconData selected, String label})` repeated in 3 spots — a `typedef` would DRY it
(SUGGESTION).

## `ContactDetailView` in `contact_detail_screen.dart` (16ed89e, Decision 28 Slice B) — master-detail body
`ContactDetailScreen` = thin `Scaffold`+`PopScope` host owning the changed/delete back-signal; shared
body `ContactDetailView` (no Scaffold, NEVER pops, reports via `onChanged`/`onDeleted`) renders
full-screen and in the desktop pane. `build()` composes (`Align`→`ConstrainedBox(720)`→`_body`);
`_body` is method-extraction (item #1 allows it). Both legit `StatefulWidget`. List screen's
`_loaded(contacts)` extracts the LayoutBuilder one/two-pane branch; selection resolved by id (light
snapshot filter); `ContactDetailView(key: ValueKey(selected.id))` remounts on swap. Selection
highlight uses theme tokens = chrome, not colour-as-data. `kTwoPaneBreakpoint=640` extracted +
documented. `_edit` GAINED `if(!mounted)return` before post-`await` setState. Nit: list-pane width
`320` is a bare literal coupled to `640` — a `kListPaneWidth` const would be refactor-safe.
- **Slice C (194ff12)** CLEAN — search is a light snapshot filter via a pure `_matches(c,q)`
  predicate; `_MasterHeader`/`_NoMatches` clean `StatelessWidget`s (`_NoMatches` reuses `EmptyState`).
  State owns+disposes the `_search` controller. Native/web title swapped to "CRM+" across all 4 strings.

## `task_detail_screen.dart` (cfbfe7f, Decision 29) — view-first detail
Mirrors `ContactDetailScreen`/`ContactDetailView`. Thin `TaskDetailScreen` host (legit stateful:
`_dirty` + lifted `late _task`); shared body `TaskDetailView` (legit stateful) has no Scaffold, NEVER
pops. `build()` composes (`AbsorbPointer`→`Align`→`ConstrainedBox(560)`→`ListView`); all mutations in
`_run`/`_edit`, none in build. `mounted` guards after every await; `_run` captures messenger before
await. Reuses shared `SubtleButton` atom. `_StatusPill` (Active/Completed/Archived) NEW local widget
— not colour-as-data (dot always paired with label; muted-vs-ink tokens). Muted date footer is the
shared `MetaLine` atom (`lib/widgets/meta_line.dart`, extracted acb0043). `SubtleButton`
(`lib/widgets/subtle_button.dart`) is a clean shared atom — exists because theme's `filledButtonTheme`
pins even `FilledButton.tonal` to `scheme.primary` (intentional). `task_form_screen.dart` correctly
shrank to title-only.

## `CommentsSection` in `lib/widgets/comments_section.dart` (extracted 078d03c, Slice 2a)
Was a private `_CommentsSection` in `event_detail_screen.dart` → extracted verbatim (bar renames) to
a public shared widget, now parent-agnostic (`CommentsRepository` + `parentId`, serves events AND
tasks). Model `comment.dart` renamed `eventId`→`parentId`, dropped `toRpcParams` (see RPC pattern
above). Repo split into `CommentsRepository` interface + `SupabaseEventCommentsRepository` impl (reads
alias the FK via `parent_id:event_id`). Grep confirmed zero stale
`SupabaseCommentsRepository`/`fetchForEvent`/`.eventId` refs. `build()` = `FutureBuilder` composing
`_header`/`_composerRow`/`_liveTile`/`_archivedSection` (method-extraction). Owns its `_lastData`
stale-guard load with `identical(future,_future)` stale-fetch checks + `mounted` guards after awaits
(`_load` assigns `_lastData` post-await unguarded — plain field write, safe); `_run` captures
messenger before await. Legit `StatefulWidget` (controllers + `_future` + `setState`). Comments mono —
no colour-as-data. Inline "No comments yet." / inline-error correctly hand-rolled (NOT `EmptyState` —
that atom is a full-screen panel). Tests shipped in-slice.
