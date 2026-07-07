Pre-push quality gate. Run BEFORE pushing, to catch drift and broken code. Scaled for this project — grow it as the project earns more checks.

## Self-audit (answer honestly, print each)
1. For every review/CR finding this session: did you READ the source, or rely on labels/summaries?
2. For every SKIP/DEFER: can you cite the specific lines that justify it? If not, verify now.
3. Did you apply "< 10 lines = fix now" before marking anything SKIP/DEFER?
4. Any unresolved findings you're pushing past? If so, say so explicitly (no silent skips).

## Checks (run, report results)
1. **Analyze (read-only):** `~/flutter/bin/flutter analyze` — report errors/warnings.
2. **Test:** `~/flutter/bin/flutter test` — report pass/fail count (skip only if no `test/` exists yet, and say so).
3. **Build:** `~/flutter/bin/flutter build web` — a build failure blocks the push. (Add `flutter build apk` once Android is set up.)
4. **Migrations (conditional):** if the diff touches `*.sql`, validate they apply cleanly on a fresh DB before push. If no DB is available, print a loud `⚠️ MIGRATIONS CHANGED — VALIDATE ON A CLEAN DB` and tell the user — do NOT silently skip.
5. **CodeRabbit local:** run the `/crlocal` loop until its stop condition trips. Do not skip while `coderabbit` is installed.
6. **Ask for explicit push approval.** Never push without it.

## Not covered here (add when the project earns it)
- Multi-agent review pipeline (code-reviewer, semantic-reviewer, red-team, …)
- E2E / integration suites, coverage thresholds, perf/security scanners
- These are LMS-Plus-mature; we add them slice by slice, not up front.

## Why this exists
Forces verification before the push, not after — and makes cr-local a required step, per the user's standing instruction that CodeRabbit local is mandatory before pushing.
