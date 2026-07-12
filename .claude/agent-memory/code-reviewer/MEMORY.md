# code-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring Dart/Flutter
> quality patterns and false positives for THIS project so future reviews focus where code actually
> drifts. This agent ALWAYS keeps the tracker table below. Curated at `/wrapup`.

## Tracker table (recurring findings — rows transition, never delete)

| Pattern | First Seen | Count | Last Seen | Status (→ rule loc) |
|---|---|---|---|---|
| _(none yet — first run pending)_ | | | | |

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
  after Slice 1, now `SupabaseEventTypesRepository` after Slice 2 of Decision 26 — event_comments
  is the only remaining direct-write repo) — reference shape for routing writes through SECURITY DEFINER
  RPCs: `create`/`update` call `_client.rpc('create_x', params: model.toRpcParams())`, cast the
  returned id `as String`, then re-`select` via a private `_fetchOne(id)` so callers get
  server-populated timestamps; `update` spreads `{'p_id': id, ...toRpcParams()}`. Model exposes
  `toRpcParams()` with `p_`-prefixed keys (name trimmed client-side belt-and-suspenders, optional
  text sent raw for the DB's `nullif(trim())` to normalize in one place). Slice 2 (event_types)
  landed 20970ea as a byte-faithful mirror (create → `.rpc('create_event_type')` + `id as String`
  + `_fetchOne`; update spreads `{'p_id': id, ...toRpcParams()}`; model `toRpcParams()` with
  `p_name`/`p_color`, name trimmed client-side) — reviewed CLEAN. When reviewing the final
  Decision-26 slice (event_comments), compare against this shape; a faithful mirror is CLEAN.
- **`_CommentsSection` in `event_detail_screen.dart`** — reference-quality inline stateful
  sub-section. `build()` is a `FutureBuilder` composing `_header`/`_composerRow`/`_liveTile`/
  `_archivedSection` helpers (method-extraction, which item #1 allows alongside StatelessWidgets).
  Owns its own `_lastData` stale-guard load with `identical(future,_future)` stale-fetch checks and
  `mounted` guards before any `context`/`setState` access after an await (`_load` assigns `_lastData`
  post-await unguarded — a plain field write, safe); `_run` captures the messenger before the await. Legit
  `StatefulWidget` (controllers + `_future` + `setState`). Comments are mono — no colour-as-data.
  Model (`comment.dart`) + repo (`comments_repository.dart`) follow the pure-Dart-model /
  abstract-interface-repository split; tests shipped in the same commit.
