# semantic-reviewer — memory

> Transition tracker, curated in place (never a dated session log). Records recurring semantic /
> behavioral bug patterns for THIS project so future reviews focus where logic actually breaks.
> Curated at `/wrapup`. Verbose detail lives in `topics/*.md` — never inline it here.

## Recurring semantic bugs
Full evidence + the per-pattern "Check:" for each row → [topics/recurring-bugs.md](topics/recurring-bugs.md).

| Pattern | Count | Last seen | Status |
|---|---|---|---|
| A comment reasons about ONE layer while a same-commit sibling edit moves it (chip avatar: `ring:true` + `chipTheme` un-pinned the disc 20→11px under a fontSize calibrated for 22) | 1 | `72f33c1` | WATCHING |
| Stale status twin in a NON-shipping ledger subsection (grep the ENTRY for the old status word, never a list of headings) | 2 | `f30ab6e` | RULE CANDIDATE |
| One named category, two memberships, same commit (a parenthetical after "the X" reads as a definition) | 1 | `cc058fb` | WATCHING |
| A doc attributes a check to a guard that cannot fire (a `case when` in the RPC makes the DB constraint decorative) | 1 | `286f86f` | WATCHING |
| A live rule that enumerates a closed count (counts rot; state the test, enumerate openly) | 1 | `f30ab6e` | WATCHING |
| Line-number citation broken by the SAME commit that shifts it (cite headings, not lines) | 1 | `470721d` | WATCHING |
| `setState(() => <expr returning a Future>)` — the arrow discards it | 2 | `3a87cc8` | PROMOTED → `discarded_futures` lint (`0e4a7af`) |
| Form declares an entity read-only but leaves a write affordance live (incl. state-dependent inline editors) | 2 | `643bbeb` (fixed `adab034`) | RULE CANDIDATE → `docs/design-principles.md` once written |
| per-keystroke `setState((){})` rebuilding a whole `FutureBuilder` + `.where` filters — cheap + idiomatic here; flag only on a larger/perf-sensitive list | 2 | `194ff12` | WATCHING |
| Mutation entrypoint missing an `if (_busy) return` re-entrancy guard — idempotent so far; watch for a NON-idempotent one | 1 | `3a87cc8` | WATCHING |

## Durable seed watch-items (this project's conventions)
- **`mounted`-after-`await`** — a new `await` in a `State` method that then touches `context` /
  `setState` must be followed by `if (!mounted) return;`. Watch every new await path.
- **`_lastData` stale-load race** — a late/stale `FutureBuilder` load must not overwrite newer data;
  a failed refresh keeps stale data. Check the guard survives any load rework.
- **`Event.fromJson` embeds** — `event_attendees[].contacts` and the `event_types` embed; a
  soft-deleted type → embed null → `type` null (must not crash). Attendees are `List<Contact>`;
  there is **no `EventAttendee` model**.
- **Minutes-from-midnight** — `startMin`/`endMin` both null iff `allDay`. Watch changes that break it.
- **RPC-only writes** — event writes go through `create_event`/`update_event`, deletes through
  `soft_delete_*`; check `toRpcParams()` passes the params the RPC signature expects.
- **`ymd()` is wire + map-key, never display** — `p_dob`/`p_event_date` and `calendar_screen`
  day-grouping. User-facing dates are `util/calendar.dart`'s `displayDate`/`displayDateNoYear`/
  `longDate` (Decision 47). A new `ymd()` call in a widget is a leak.

## Positive signals (reviewed CLEAN — detail in topics)
- **Desktop-adaptive slices (Decision 28 A/B/C: 4679504, 16ed89e, 194ff12)** —
  [topics/desktop-adaptive-slices.md](topics/desktop-adaptive-slices.md). Detail `selected` always
  resolves by id against the FULL list; B/C `_lastData` lingers are consistent-by-design transients.
- **Decision 26 write-RPC ports (1988e26, 20970ea, 3296258)** —
  [topics/write-rpc-ports.md](topics/write-rpc-ports.md). Reusable 4-check port shape; `.single()`
  and the non-atomic RPC-then-`_fetchOne` re-fetch are correct by design — do NOT flag as races.
- **CLEAN slice traces** (one line each; full detail → [topics/clean-slices.md](topics/clean-slices.md)):
  - D47 UI consistency (`72f33c1`) — `ymd` display/wire/map-key split correct; `longDate` byte-identical
    to both inlines; chipTheme blast radius contained (3 InputChips, hand-rolled pills unaffected).
  - Shared test-fakes consolidation (`test/support/fakes.dart`) — behavior-preserving superset merge.
    Do NOT re-flag a fake-consolidation when the shared body is char-identical + superset.
  - Idempotent create RPCs on client-minted id (#9 / D41, `20260716120000`) — `p_id default null` +
    `coalesce` + `on conflict do nothing`; first-write-wins replay is ACCEPTED, not a race.
  - Task↔categories m2m link (D40 Slice B, `d95f85b`) — verbatim task_contacts mirror; null-skip = RLS-hidden.
  - Task categories entity + Settings manager (D39 Slice A, `9377a61`) — byte-faithful event_types port.
  - Pre-auth DB lockdown (D36, `d549d45`) — `create or replace` preserves the ACL so revoke survives.
  - Tasks view-first (D29, `cfbfe7f`) — state-lift trap RESOLVED; `id:isArchived:isDone` key.
  - Tasks in-pane create wide-only (D29 amend, `acb0043`) — draft survives background `_load()`.
  - Edit → top-right, AppBar(phone)/PaneHeader(desktop) via GlobalKey + public `edit()` (D49, `e5e1b29`) —
    `edit()` guards `_busy`/`_isArchived`/`_deleting` off the view's OWN live `_task`/`_contact`, so both
    surfaces no-op identically; GlobalKey `currentState` reliably non-null (body built same-build as the AppBar,
    never re-keyed); phone AppBar drops the archived Edit AND `edit()` re-guards it (belt+braces); PaneHeader
    inside `AbsorbPointer(_busy)` + `onEdit:null` + handler-guard = triple-guarded, consistent w/ the unabsorbed
    phone AppBar. `Column`+`Expanded(body)` gets bounded height from `Expanded(pane)` in a Row. Double-tap→two
    forms is PRE-EXISTING + narrow (route covers both surfaces; only one surface per screen) — do NOT flag as new.
  - `DetailField` superset-merge extraction (D43, `780c930`) — `copyWith(color:null)` is a no-op;
    relaxed assert allows both-null, forbids both-non-null.
  - CommentsSection extraction (Slice 2a, `2717da9`) — verbatim transplant; select-only alias deliberate.
  - Task `notes` scalar add (D31, `4d3d6b8`) — nullable-scalar-on-RPC-entity shape; `''`→NULL clear.
  - Task `importance` 0..3 (D38, `3bf48ea`) — fixed-semantic-scale, NOT colour-as-data.
  - Task↔contacts "People on a task" (`2b100b7`) — soft-deleted drop LIMITED to the RLS-hidden case.
  - Task comments repo/wiring (Slice 2b, `643bbeb`) — byte-faithful event-repo twin; wiring un-crossed.
  - Comments `_CommentsSection` (`3a87cc8`) — `identical` guard; controllers cleared AFTER await.

## Known false-positive traps (do not flag these)
- Missing `auth.uid()` / `with check (true)` is expected pre-auth — DB-security is
  `db-security-reviewer`'s lane, not yours.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a regression.
- Stock lint / style / null-safety already covered by `.coderabbit.yaml`'s generic Dart pass and
  `code-reviewer` — do not re-report.
- A synthetic noun in a widget test (`'guests'`) is asserting the widget's CONTRACT, not a stale
  caller vocabulary — that's deliberate.
