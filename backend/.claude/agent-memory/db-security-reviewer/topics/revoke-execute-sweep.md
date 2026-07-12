# Revoke-execute-from-public sweep (issue #3)

**Fact:** No migration in `backend/migrations/**` issues `revoke execute on function … from public`.
Postgres grants EXECUTE to `PUBLIC` by default, so every SECURITY DEFINER RPC is callable by any role
regardless of the explicit `grant execute … to anon, authenticated` (which is additive, not a lock-down).

**Why it's not a per-slice blocker now:** this is exactly issue #3's "revoke PUBLIC execute" hardening
item, and the whole project is pre-auth (every RPC is deliberately anon-callable). Flag as **ISSUE,
ref issue #3, DEFER acceptable** while #3 is open. Do NOT re-litigate on every RPC — one consolidated ISSUE per
multi-RPC sweep, enumerating the functions.

**When it flips to FIX (regression):** once #3 lands and the first `revoke execute … from public` appears,
a NEW RPC missing it becomes a regression → FIX-NOW (`revoke execute on function <name>(<args>) from public;`).

**RPCs currently affected (grep `create … function` sorted by ts prefix for the live set):**
create_task, update_task, soft_delete_task, restore_task (tasks slice) + all contact/event/event_type/
event_comment write RPCs. Re-grep before enumerating — the list grows each write-RPC slice.
