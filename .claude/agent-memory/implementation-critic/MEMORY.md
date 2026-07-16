# implementation-critic — memory

> Transition tracker, curated in place (never a dated session log). Records recurring
> implementation deviations vs the approved plan for THIS project so future pre-commit reviews
> focus where builds actually drift. Curated at `/wrapup`.

## Recurring deviations (none logged yet)
_First run pending. Seed watch-items carried from the project's conventions:_
- After an `await` in a `State`, is there `if (!mounted) return` before touching `context`/`setState`?
- `startMin`/`endMin` math — right unit (minutes from midnight, `0..1439`), both null iff `allDay`?
- Nullable model fields dereferenced without a guard (`Event.startMin`/`endMin`/`type`, `Contact.dob`)?
- Repository/model signature change → is the hand-written `_FakeXRepo` in `test/` updated too?
- Fallbacks match sibling code (`EventType` bad-hex → `#888888`; `toWrite()` empty → null)?
- `FutureBuilder` screens keep the `_lastData` stale-guard (failed refresh keeps stale data)?

Full write-ups for the WATCHING rows below: [deviations](topics/deviations.md).
- **toRpcParams shape-change → stale sibling comment** (RESOLVED-WATCH, count 1; Task notes, held
  clean at D38 importance 2026-07-15): adding a scalar to `toRpcParams()` staled the dartdoc that
  quotes the OLD `create_*/update_*` param literal in the SAME file. Grep model+repo comments.
- **Docs-sync "same file, >1 stale surface"** (WATCHING, count 1; #40, 2026-07-14): a status/shipped
  line updated but the SAME file's "Owed/Next/backlog/TODO" list still cites the completed item.
- **Consolidating a duplicated fake orphans its doc-comment** (WATCHING, count 1; #10 shared
  fakes.dart, 2026-07-16): deleting a `///`-documented fake left its doc above the retained
  `_Failing*` sibling, mis-describing it. Grep the deletion site for a dangling `///`. 2 hits/slice.
- **Verify-curl param names drift from the RPC signature** (WATCHING, count 1; D36, 2026-07-15): a
  README `POST /rpc/<fn>` curl used non-existent `p_*` names → PGRST202. Match 1:1 to the migration.
- **State-lift-vs-`widget.x` trap** (WATCHING, count 1; D29 Tasks): a dynamic-title Scaffold host
  reading `widget.task` (frozen) instead of seeding `late _task` + `setState` in `onChanged`.

## Positive signals (all clean pre-commit, 0 blocking) — one line each; full lessons in topic file
See [positive-signals](topics/positive-signals.md) for the per-slice-type win conditions. Index:
- **Scalar-field-add** (Task notes, Dec 27; **Task importance Decision 38, Jul 15**): drop+CR both
  RPCs on arity change + re-issue the Decision-36 `revoke … from public` + `grant … to anon,
  authenticated` on the NEW signatures (a recreate hands back default PUBLIC execute — the lockdown
  invariant); `nullif(trim,'')` clear-path; `copyWith` preserves via `?? this.` (both toggle paths
  omit the arg); toRpcParams carries the new `p_*` (4-arg create), repo update() sends it explicitly
  (6-arg update, REQUIRED no-default = fail-loud on stale caller); `.order('importance', desc)` sits
  BETWEEN is_done and created_at; new fixed-scale colour = chrome NOT Decision 19 (framed correctly);
  ImportanceMarks a11y = Semantics label so colour/'!' never rides alone; test fakes thread the field
  through create + archive + restore, not just update. Full dartdoc sweep held clean.
- **Cross-cutting RPC-arity retrofit** (idempotent create_*, Decision 41 / issue #9, Jul 16; clean
  0 blocking): all 7 create_* gain a trailing `p_id uuid default null` in ONE drop+recreate migration.
  Win conditions verified: every DROP matched the CURRENT (latest-in-chain) old signature, every
  revoke+grant listed the NEW signature (D36 lockdown re-issued on the recreate, D38 invariant); the
  two-trailing-defaulted-uuid create_event `(…,uuid,uuid)` = p_type_id then p_id both correct;
  create_task_comment's replay-vs-archived-parent split is sound (insert `where exists(live parent)
  … on conflict do nothing` + post-`if not exists(id=v_id) raise no_data_found` — covers replay,
  archived-first, and created-live-then-parent-archived-then-retried). Client: single mint point
  `lib/util/ids.dart`, `.draft` const-ctor→id-minting factory (drops `id=''`), `p_id` rides in
  toRpcParams so the 4 SPREAD-update repos correctly drop their now-redundant explicit p_id (task
  update is an explicit map, untouched — correct); 5 pop-on-success forms `late final _pendingId`,
  CommentsSection mutable `_pendingId` reset AFTER success inside the op (throw-before-reset = retry
  reuses id = dedupe — the actual payoff). Zero empty-id sentinels left in lib/; full doc-comment +
  database.md rule#2 + Decision 41 sweep held clean (no stale "server owns id"/"DB assigns").
- **Rules/config CR-scoping slice** (`.coderabbit.yaml` path_filters + doc-updater lifecycle rule,
  Decision 44, Jul 16; clean 0 blocking): no app code. Win conditions: `path_filters` under `reviews:`
  at 2-space indent alongside siblings, negation-ONLY globs (`!**/*.md` + `!.claude/**`) = exclude those
  + keep everything else (CR idiom — does NOT collapse to exclude-all), `path_instructions` untouched;
  doc-updater DO-NOT renumbered #9→#10 with a #5-vs-#10 cross-link (whether-to-doc vs which-word), the
  lifecycle verify-command table accurate for a squash-merge repo (`git ls-remote --heads`,
  `gh pr view --json state`=MERGED, `git log origin/main --grep '(#N)'`); Decision 44 gap-over-43
  carries an HTML comment naming the concurrent branch (PR #51) — sane, transient, out of the diff's
  control. Stale-surface sweep: "authoritative gate"/"reviews the PR" lines are about WHICH-PR not
  WHICH-FILES, so not contradicted (only CLAUDE.md:53 needed the clause, edited).
- **Template-port** (contacts/event_types/event-comments write-RPCs, Dec 26 S1–2): diff vs green
  template; security posture must be byte-for-byte; new fn = no CR-chain.
- **Full-stack new-entity mirror of EventType** (task_categories Slice A, Decision 39, Jul 15; clean
  0 blocking): NEW table created POST-lockdown ships RPC-only from day one — SELECT-only policy
  `using(deleted_at is null)` + `grant select`, NO insert/update policy or grant, 3 SECURITY DEFINER
  RPCs `set search_path=public` each with `revoke execute … from public` + `grant … to anon,
  authenticated` on the exact typed signatures. RPC arity matched toRpcParams 1:1 (create 2
  p_name/p_color, update 3 adds p_id via repo spread, soft_delete 1). Model mirrors EventType:
  `_validHex` → `#888888` fallback, draft ctor empty id, pure-Dart no dart:ui. Screen imports
  `TypeSwatch` via `show` (not redefined), reuses kEventTypePalette/colorFromHex/hexFromColor; new
  colour = user-data swatches (Decision 19 OK) + Semantics label so colour never rides alone;
  `_lastData` stale-guard + `identical(future,_future)` both present; mounted-after-await on every
  path; messenger/navigator captured pre-await. All 4 hand-fakes (calendar/home_shell/widget×2)
  threaded, both ContactsApp sites updated. NO Slice-B leak (no Task/create_task/tasks-repo/join).
- **Shared-widget second-consumer** (task_comments, Dec 33 / Slice 2b): faithful twin of
  event_comments (table+4 RPCs in one file) + `readOnly` gating (default false → events untouched);
  alias `parent_id:task_id` select-only; second repo threaded end-to-end, NO cross-wiring.
- **Divergent (rule-reversing)** (comment write-RPCs, Dec 26 S3): `update` builds params EXPLICITLY
  (no spread → PGRST202); restore guards `is NOT null`; full rule-reversal doc-sweep.
- **New-entity-from-scratch** (Tasks v0, Dec 27): same per-project trap list; `_lastData` needs the
  `identical(future,_future)` guard (cloud-CR #30 caught its absence).
- **Widget-extraction / master-detail** (Contacts Dec 28 S-B; Tasks S-D): shared Scaffold-less body +
  thin wrapper; `ValueKey(id:isArchived:isDone)` remount; snackbar once; discarded_futures context-
  sensitive; binding key doc-comment lives on the *EditView*, syncs in same slice.
- **Pure-refactor extraction** (CommentsSection, Dec 2a): byte-equivalent behaviour; only the rename
  axis differs; every async invariant survives verbatim; grep no dangling old names.
- **Superset-merge widget extraction** (DetailField from two `_Field`s, #10 item 2, Jul 16; clean 0
  blocking): merging two variant private widgets into one shared superset — the trap is a
  PIXEL/behaviour diff between the two originals surviving the merge. Verified: both `_Field` trees
  were byte-identical (pad-bottom 20, icon 20 onSurfaceVariant, SizedBox 16/2, labelMedium label,
  bodyLarge value); contact's non-empty `copyWith(color:null)` == event's plain bodyLarge (no
  flatten diff). The RELAXED assert `child==null||value==null` (both-null ALLOWED, both-non-null
  forbidden) is required+safe: contact's dob passes value=null/no-child (both-null — old event
  assert would've tripped it), no call site passes both. Behavioural-drift check (item 7): merged
  adds an empty→"Not added" branch the event original lacked, but every event caller guards
  non-empty (`if location!.isNotEmpty` / `if notes!.isNotEmpty`) and `_whenLabel` always returns
  non-empty + Type uses child → empty branch unreachable for events, so no blank→"Not added" drift.
  New `super.key` idiomatic, no identity-dependent call site. 5 contact + 4 event sites all keyword
  args → mechanical rename; grep confirmed 0 leftover `_Field`; new file imports only material.dart
  (child/TypeLabel passed by caller); no orphaned imports either screen.
- **Pure-UI / adaptive-layout** (desktop sidebar, Dec 28 S-A): theme-token fidelity; colours from
  `colorScheme` = chrome; `Flexible`+ellipsis vs fixed-height textScaler overflow (SUGGESTION).
- **Infra / bash / SQL-only**: trace quoting per shell hop; verify NOTIFY contract; check cold-start
  path when a "redundant" reload is removed.
- **Config / asset** (app-icon): pixel-sample corner-vs-center alpha, don't trust headers.
- **Join-table + picker-generalization** (People on a task, Jul 14): m2m mirror of event_attendees
  (drop+CR both RPCs on arity change, join-delete AFTER not-found raise, `using(true)` off #4 list) +
  rename Attendee→ContactPicker w/ `title` noun (event strings byte-identical); load-bearing toggle
  invariant verified on all 3 update paths via `copyWith` default + embed on both reads; title-vs-
  widget.x trap handled (host seeds+setState `_task`).
- **Join-table 2nd occurrence — m2m link + copy-not-generalize picker** (task↔task_categories,
  Slice B / Decision 40, Jul 15; clean 0 blocking): near-verbatim mirror of task_contacts. Migration:
  join table composite-PK (no id/timestamps/deleted_at), both FKs `on delete cascade`, reverse index,
  RLS `using(true)` SELECT + `grant select` only (NO write policy/grant — RPC-only). Both task-write
  RPCs drop+CR on arity change; drop targets matched the CURRENT signatures via the migration chain
  (`create_task(text,text,uuid[],smallint)` / `update_task(uuid,text,boolean,text,uuid[],smallint)`
  from add_importance); `p_categories` DEFAULTED on create / REQUIRED (no default) on update =
  fail-loud on stale caller; security definer + set search_path=public verbatim; Decision-36 lockdown
  re-issued (`revoke … from public` + `grant … to anon,authenticated`) on the NEW 5-/7-arg sigs.
  Model: `copyWith` categories default `this.categories` (toggle-preservation), fromJson null-embed
  skip (soft-deleted category → null → skip), toRpcParams `p_categories` id-list, doc-comment swept.
  Screen: NEW picker CLONED not generalized (consistent w/ Slice A copy-not-refactor), mounted-guard
  after await, colour never rides alone (row chip + detail row + picker tile + InputChip all carry
  Text(name)). Threaded through all 4 tasks_list sites + detail (screen+view+forward-to-form) +
  home_shell. Tests: exact toRpcParams map got `p_categories:[]`; reconstructing fakes threaded
  categories through create/archive/restore in BOTH stateful-fake files (4th field recurrence,
  notes→contacts→importance→categories); new picker test covers load/search/select/return/empty/error.

## Durable, verified facts (load-bearing)
- **`CREATE EVENT TRIGGER` does NOT fire `ddl_command_end`** (proven locally on postgres:15/16:
  creating a second event trigger while `pgrst_ddl_watch` was active emitted no NOTICE; only
  `CREATE TABLE` did). Consequence: the `20260712120000_pgrst_ddl_watch.sql` migration emits ZERO
  `NOTIFY pgrst` during its OWN application. On a FRESH homebase where PostgREST is already up with
  an empty cache, applying all migrations does not reload it — every endpoint 404s until a
  `docker restart firstapp-postgrest` (or the next DDL). This is why `deploy-homebase.sh` keeps a
  single UNCONDITIONAL `notify pgrst` at the end as a cold-start net (the triggers own the
  running/steady-state + ad-hoc-psql case; the script one-liner owns fresh-DB cold start). General
  lesson: when a slice removes a "redundant" reload/refresh, check the cold-start/first-load path,
  not just the steady state.

## Known false-positive traps (do not flag these)
- An internal event-trigger / NOTIFY-only function pinning `set search_path = ''` (not `= public`)
  is CORRECT — rule #6's `= public` is for SECURITY DEFINER client-facing RPCs. Don't demand `=
  public` on a non-definer function that references no schema objects.
- Missing `auth.uid()` / login checks are expected pre-auth (issue #3) — not a defect.
- `with check (true)` policies and RPCs granted to `anon` are intentional pre-auth.
- `drop function if exists …; create or replace …` to change an RPC signature is the **correct**
  pattern here (avoids PGRST203), not a dropped-function regression.
- Hard `DELETE` on the annotated `event_attendees` join is allowed; soft-delete is only required
  on mutable entity tables.
