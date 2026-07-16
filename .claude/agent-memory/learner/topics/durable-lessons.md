# learner — durable cross-agent lessons (full detail)

> Pointed at from `MEMORY.md`. Edit in place; don't stack dated entries (history in git).

- **`setState(() => Future)` invisible to analyze** — twice a runtime bug caught only by tests; now
  double-gated by `discarded_futures` (`0e4a7af`). Noise caveat: also flags intentional
  fire-and-forget → needs `unawaited(...)`/`// ignore`.
- **red-team's "record the curl" is structural, not per-slice** — DB-doc convention (`4911243`)
  stops the re-raise; held across Decision 26 (`1988e26`).
- **Rule-reversal-sync (PROMOTED, count 3) + its refinement (PROMOTED, count 2) — both in `CLAUDE.md`.**
  The binding rule catches sibling FILES; the recurring miss was SECONDARY surfaces WITHIN a touched
  file + ledger subsections. As of `d549d45` that refinement is folded into the same CLAUDE.md
  paragraph (whole-file + every ledger subsection), so the plan author reads it at plan time.
  Deliberately NOT a mechanical `/fullpush` grep (semantic, per-slice phrasing; plan-critic+doc-updater
  already gate it). Every recurrence was caught in-cycle — the clause reduces re-derivation, does not
  plug a leak.
- **Meta-cluster: "under-scoped sibling-surface sweep on a change" (do NOT promote — mixed
  mechanisms, only rule-reversal at count ≥2).** plan-critic rhyming rows: (a) rule-reversal→grep
  docs (PROMOTED, `CLAUDE.md`); (b) remove model write-method→grep `test/`+dead helpers (count 1);
  (c) remove widget→grep whole test file (count 1); (d) ADD scalar field→reconstructing fakes
  DROP it + exact-map `toRpcParams()` assertion breaks — **SPLIT OUT to its own tracker row, count 3,
  learner-PROPOSED → CLAUDE.md** (no longer part of this cluster's count); (e) ADD `p_*` param→repo INLINE
  COMMENT enumerates old `p_*` shape (**count 2**, `2b100b7`+`d95f85b`) — learner-PROPOSED to fold into
  the CLAUDE.md FIELD-ADD rule (both instances are field-adds, tighter home), NOT to broaden this
  rule-reversal sweep; (f) change operative RULE-NUMBER→`.claude/commands`|`agents`
  file restating it goes stale (count 1, `b5486f0`); (g) same-file OWED-LIST twin — status line
  updated, "Owed"/"Next" list still cites shipped item (count 1, `b5486f0`). All count 1, all caught
  in-cycle, NO leak → NO rule. Trip: if any recurs → BROADEN the CLAUDE.md sweep line ("grep docs,
  sibling COMMENTS, `test/` fakes+exact-map assertions, AND `.claude/commands`|`agents`
  number-restatements + same-file owed/status lists on any field/method/affordance/`p_*`/rule-number
  change, add OR remove"), NOT a second convention. NOT gated (surfaces at test/review).
- **CREATE OR REPLACE recreating an RPC to add ONE param must re-carry the WHOLE prior body**
  (SECURITY DEFINER, `SET search_path`, `deleted_at is null` guard, `if not found raise`, trims).
  Once (`5cfc2b3`, folded). Promote if a future param-add drops a guard.
- **`state-lift-vs-widget.x` (impl-critic, `cfbfe7f`) RESOLVED in-slice** — thin host's dynamic
  AppBar title read `widget.task` (frozen at push) while mutation lived in child → stale title. Fix:
  `late _task`+`setState` in `onChanged`. Const-title hosts immune. Promote if it recurs.
- **RPC-write shape is proven-low-risk (Decision 26 COMPLETE, 4/4 clean)** — boilerplate
  (drop+recreate, `SET search_path`, revoke-from-public, `toRpcParams`, `.rpc()`+re-select) stays
  clean even when one entity diverges, provided the divergence is documented in the migration header.
  Spend attention on per-entity deltas. **Decision 36 (`d549d45`) hardened it to the SOLE write
  path** (revoked anon direct grants + PUBLIC execute).
- **The `toRpcParams()`↔RPC-arity seam is the recurring failure of the RPC-write shape** (count 2:
  `1e7574d`, `258cb6c`). Per-entity: does the spread send EXACTLY the declared params? Body-only /
  arity mismatch → PGRST202; build the map explicitly when it diverges from create-shape. Inverse
  near-miss (count 1, `3b0468a`): a DEFAULT write-param → omission silently WIPES. One `database.md`
  #2 line covers both faces. Caught at PLAN time; NOT gated (runtime).
- **Read-only entity must gate EVERY write affordance — incl. STATE-DEPENDENT** (RULE CANDIDATE,
  count 2: `TaskFormScreen` `58b2b5d`→`258cb6c`; `CommentsSection` inline-edit `643bbeb`→`adab034`).
  Also gate affordances keyed off their OWN local state, and clear edit-state on the read-only flip
  (`didUpdateWidget`). NOT gated — semantic review + regression test only. **learner-PROPOSED →
  `design-principles.md`**; mark PROMOTED once written.
- **Shared test fakes live in `test/support/fakes.dart` (Decision 42, `a08c199`).** A fake is shared
  ONLY once its body is duplicated across ≥2 files (same "extract at count 2, not first sight" threshold
  learner uses for rules); single-file behavioral specials (failing / ordering / full-CRUD / gated) stay
  local. Paydown of the recurring "every reconstructing fake" flag — future field-adds thread through the
  shared file once, not N copies. Trap when consolidating/renaming fakes: a PRIVATE fake NAME can denote
  different behavior tiers across files (see the `_FakeCommentsRepo` WATCHING row) — map call sites by
  BEHAVIOR, never by a mechanical drop-underscore rename.
