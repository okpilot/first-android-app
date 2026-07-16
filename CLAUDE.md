# First Android App — a learning CRM (Flutter + trimmed self-hosted Supabase)

A hands-on project to learn app development by building a light CRM. The CRM is a
disposable vehicle — **learning is the goal**. Built the *emergent* way: thin
vertical slices, never big features up front.

## Stack
- **Client:** Flutter (Dart) — one codebase → Android + Web + Linux desktop. iOS later (needs a Mac).
- **Backend:** Postgres, served the Supabase way — **trimmed, self-hosted on `homebase`**:
  Postgres + PostgREST (REST/RPC) + GoTrue (auth), fronted by the existing Caddy.
  No Kong / Realtime / Storage / Studio. (~80–130 MB idle.)
- **Client SDK:** `supabase_flutter`.

## How we work (the workflow)
Emergent, slice by slice. For each change:
1. **Explore** — understand what exists before touching it.
2. **Propose the next thin slice** — the smallest end-to-end step; confirm before building anything big.
3. **Plan** — for non-trivial work, state the plan and validate it before coding.
4. **Implement** the slice (UI + logic + data for ONE thing).
5. **Review** the diff against the plan, in-session (visible).
6. **Record** — append a line to `docs/decisions.md` for any decision made.

Skips are allowed but **must be stated, never silent**.

**A rule reversal isn't done until its contradictions are gone.** When a slice rewrites or reverses
a convention mid-migration (e.g. Decision 26's "all writes via RPC"), grep every sibling repo
doc-comment, migration header, and doc that still cites the OLD rule (`per docs/database.md`,
`like contacts`, `single-table … goes direct`) and fix them in the **same** slice — and grep the
WHOLE of each touched file + every subsection of each decisions-ledger entry (Context / Implementation
/ Principle), not just the first citation (a file usually has >1 stale surface) — this recurred
twice before it was made a rule (learner, count 2; the whole-file/every-subsection refinement, count 2).

**Adding a field to a model isn't done until every hand-fake reflects it.** When a slice adds a
field to a model (e.g. `Task.notes`, `Task.contacts`, `Task.importance`), thread it through **every**
hand-fake repo path that RECONSTRUCTS the entity from scratch — `create` / `archive` / `restore`, not
just the `update`/pass-through path — and update every exact-map `expect(…toRpcParams(), {…})`
assertion. The reusable reconstructing fakes now live in **`test/support/fakes.dart`** (Decision 42) —
thread the field through that one shared file first, then grep `test/` for the single-file specials
that still reconstruct locally and for `toRpcParams()` maps. The
field silently vanishing in a reconstructing fake is invisible to `flutter analyze`, the hooks, and
CodeRabbit (test-fake completeness is opaque to all three) — it only surfaces as a widget-test
assertion failure, or not at all. Recurred 4× (notes → contacts → importance → categories; learner
count 4). **Also grep the repo file itself for inline comments that enumerate the `p_*` param shape**
(the `create`/`update` doc-comments in `*_repository.dart` + the model's `toRpcParams` comment) — they
list the OLD param set after the RPC gains one, prose the compiler can't catch (recurred: `p_contacts`
2b100b7, `p_categories` d95f85b; learner count 2).

## Branching & the push gate
- **Branch per slice** — never build on `main`. `main` stays green.
- **Before every push, run the `/fullpush` gate** (`.claude/commands/fullpush.md`):
  `flutter analyze` + `flutter test` + `flutter build web`, then **`/crlocal`** (mandatory
  CodeRabbit local review — `.claude/commands/crlocal.md`), then **ask for explicit push approval**.
- CodeRabbit is installed org-wide, so the cloud bot also reviews the PR on push — that's the authoritative gate; `/crlocal` is the cheaper pre-push preview. Cloud CR is **scoped to code/SQL/config** (`.coderabbit.yaml` `path_filters` exclude `**/*.md` + `.claude/**`) — docs + agent files are the in-house fleet's job, not CR's (Decision 44).
- **Answering the cloud bot is two commands, split by moment** (both call `scripts/cr-findings.sh`):
  **`/coderabbit`** triages the cloud review (investigate each finding vs source → fix/defer/skip,
  records dispositions on the PR) → **`/fullpush`** pushes the fixes → **`/replycoderabbit`** posts the
  reply. Triage before reply; `/coderabbit` never pushes, `/replycoderabbit` never triages.
- **Mechanical git hooks** (`.githooks/`, activate with `scripts/setup-hooks.sh`; modeled on LMS Plus's lefthook, no Node): **pre-commit** = `dart format` check + `flutter analyze` (blocking); **commit-msg** = Conventional Commits (blocking); **pre-push** = secret scan (blocks `.env`/`dev-defines`/keys/JWTs). These are the deterministic tier; `/crlocal` + review stay in `/fullpush`. Grow them only as a miss recurs (≥2×).
- **CI/CD** (GitHub Actions: analyze + test + build) is added *with Slice 1*, when there's a Flutter project to run against.
- **At end of session, run `/wrapup`** (`.claude/commands/wrapup.md`) — sync docs, dispose of every open finding, leave `main` clean.

## The agent fleet (reviewers in `.claude/agents/`)
A 10-agent reviewer fleet ported from LMS Plus, Flutter-adapted (Decision 22). **Orchestrator-driven,
advisory:** I launch each reviewer via the Agent tool at its moment in the session so findings are
visible and fixed in-chat; the human approval step in `/fullpush` stays the only real gate. The
git hooks stay mechanical — the new **post-commit** hook just *nudges* the pipeline.
- **plan-critic** (plan time) · **implementation-critic** (pre-commit) · post-commit parallel:
  **code-reviewer · semantic-reviewer · doc-updater · test-writer** → **learner** → conditional
  **red-team** (migrations/auth) · **coderabbit-sync** (rule/config files) · **db-security-reviewer**
  (pre-push, in `/fullpush`, = the `security-auditor` role).
- The pipeline, severity, multi-round discipline, model tiers, and finding-validation live in
  **`.claude/rules/agent-workflow.md`**; memory format in **`.claude/rules/agent-memory.md`**.

## NEVER DO
- **NEVER** build a large feature from a vague ask — propose the next thinnest slice and confirm first.
- **NEVER** commit or push without the user's explicit go-ahead.
- **NEVER** put secrets in committed files (settings, source, docs). Use env / `.env` (gitignored).
- **NEVER** rewrite a past decision in `docs/decisions.md` — append, or amend in place with a date.
- **NEVER** hit raw Postgres from the Flutter client — always via PostgREST/GoTrue under RLS.

## Binding docs (read these)
- `docs/plan.md` — read first each session: goal, status, next slice.
- `docs/decisions.md` — the append-only decision ledger.
- `docs/database.md` — DB conventions (apply as slices need them).
- `docs/design-principles.md` — how we apply the UI/UX principles (light wrapper; advisory, not a gate). Its two source-verified encyclopedias (`docs/UI-Principles-*.md`, `docs/UX-Principles-*.md`) are on-demand references — reach for their Build Checklists **only at UI slices**, not every session.
- `HANDOVER.md` — where we left off.

## Environment
- Flutter 3.44.5 at `~/flutter` (not on PATH — use `~/flutter/bin/flutter`).
  Web + Linux desktop ready. Android SDK installed (`~/Android/Sdk`); emulators
  `galaxy_s23plus` + `pixel_api35` available — `~/flutter/bin/flutter emulators --launch galaxy_s23plus`,
  then QA via `adb exec-out screencap -p` (reliable; desktop xdotool clicking is flaky on this
  multi-monitor setup). The emulator reaches homebase over the host's tailnet.
- Run: `~/flutter/bin/flutter run -d chrome` (web) · `-d linux` (desktop).
