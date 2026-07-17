# Backend — trimmed Supabase (local dev)

The Supabase-shaped data layer for the app, run **locally** for development:
**Postgres + PostgREST + a Caddy gateway** (giving the `/rest/v1` path so
`supabase_flutter` works unmodified). There is **no GoTrue / no login** — single-user + tailnet-only
is the security boundary (Decision 37); the API is anon-permissive over the tailnet.
This mirrors what will run on `homebase` in `okpilot/selfhost` behind the existing Caddy.

See `docs/decisions.md` (Decisions 5 & 10) and `docs/database.md` for the rules.

## One-time
```bash
cd backend
./gen-env.sh          # writes .env (gitignored) + ../dev-defines.json with a matching anon key
```

## Run
```bash
cd backend
docker compose up -d          # first run applies migrations + seed on a fresh volume
docker compose logs -f db     # watch [init] lines
docker compose down           # stop (keeps data)
docker compose down -v        # stop + wipe (re-inits from migrations/ + seed.sql on next up)
```

Gateway: <http://localhost:8000> · data path `/rest/v1/…` · Postgres on `127.0.0.1:5433`.

> **⚠️ Local schema drift — re-init before trusting any `## Verify:` block below.**
> `init/init.sh` runs **only on a fresh volume** (`docker-entrypoint-initdb.d`), and there is **no
> migration ledger locally** — so a long-lived local volume silently rots as migrations land: they
> get hand-applied, or not at all. Found 2026-07-17 (issue #19) on a volume from 2026-07-11:
> `create_contact` missing outright, `create_event` still the pre-D41 9-arg signature,
> `task_category_links` absent — every local curl-run since 2026-07-12 had been hitting a stale
> schema. Nothing warns you; the RPC just 404s (PGRST202) or, worse, passes for the wrong reason.
> **Homebase is unaffected** (`deploy-homebase.sh` keeps a real ledger). Before verifying:
> ```bash
> cd backend
> docker compose down -v && docker compose up -d   # wipes local data; re-applies the full chain
> # up -d returns when the CONTAINERS start, not when the chain is applied — init.sh runs async
> # inside db, and the healthcheck's pg_isready is answered by the temp init server, so PostgREST
> # can serve curls MID-chain. Wait for the marker before trusting anything below:
> until docker compose logs db 2>&1 | grep -q '\[init\] done'; do sleep 1; done
> ```

## Smoke test
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "http://localhost:8000/rest/v1/contacts?select=name&order=name"
```

## Verify: pre-auth lockdown (Decision 36 — issue #3 auth-independent subset)
`20260715120000_preauth_lockdown.sql` closed the direct anon write path (RPC is the sole write
path), revoked `EXECUTE … from public` on every SECURITY DEFINER RPC, and added the parent-task
guard to the 4 `task_comment` RPCs. These curls prove the boundary: a **direct** anon write is now
rejected with **401/403 (permission denied)** — pre-lockdown anon held the write grant — while the
**RPC** write still works; and every comment op on an **archived** task is refused:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# direct anon write is now CLOSED on ALL 5 still-open mutable tables -> 401/403 (permission denied;
# the grant is gone, so PostgREST rejects at the permission layer before any body validation):
for t in contacts event_types event_comments tasks task_comments; do
  curl -s -o /dev/null -w "direct insert $t: %{http_code}\n" \
    -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
    -H "Content-Type: application/json" "$REST/$t" -d '{}'
done
# the RPC write path still works -> returns a uuid
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"Ada","p_dob":null,"p_email":null,"p_phone":null,"p_company":null,"p_remarks":null}'
# reads still work directly -> 200
curl -s -o /dev/null -w 'select contacts: %{http_code}\n' -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/contacts?select=id&limit=1"
# archived-task guard: make a task + a LIVE comment on it, archive the task, then confirm ALL FOUR
# task_comment RPCs refuse it -> no_data_found:
TID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" \
  -d '{"p_title":"frozen","p_notes":null,"p_contacts":[]}' | tr -d '"')
CID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_comment" \
  -d "{\"p_task_id\":\"$TID\",\"p_body\":\"live\"}" | tr -d '"')
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_task" -d "{\"p_id\":\"$TID\"}" >/dev/null
# 1) create on the archived task, 2) update / 3) soft_delete / 4) restore its comment -> all no_data_found
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  "$REST/rpc/create_task_comment" -d "{\"p_task_id\":\"$TID\",\"p_body\":\"sneaky\"}"
for rpc in update_task_comment soft_delete_task_comment restore_task_comment; do
  body=$([ "$rpc" = update_task_comment ] && echo "{\"p_id\":\"$CID\",\"p_body\":\"x\"}" || echo "{\"p_id\":\"$CID\"}")
  curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
    -H "Content-Type: application/json" "$REST/rpc/$rpc" -d "$body"   # -> {"code":"no_data_found",...}
done
```
An anon curl can't prove PUBLIC lost EXECUTE (anon calls via its own explicit grant), so confirm the
revoke with a privileged psql check (as `postgres`, on homebase inside the db container) — this lists
**any** SECURITY DEFINER RPC that still leaks PUBLIC execute; expect **zero rows** across all 21:
```bash
psql -c "select p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
         where n.nspname='public' and p.prosecdef
           and exists (select 1 from unnest(p.proacl) a where (a::text) like '=%');"
```

## Verify: event comment write RPCs (Decision 26, Slice 3)
Comment writes route through the `create_comment` / `update_comment` / `soft_delete_comment` /
`restore_comment` RPCs, which are now the **sole** write path — the direct anon/authenticated write
grants + policies were removed by the Decision 36 lockdown (`20260715120000`). (The table's
`using (true)` SELECT is a **read/archive** property — it keeps archived rows selectable for the
"show archived" feature — not a way to write directly.) These curls prove the RPC write path AND
that archiving stays **non-destructive** with no hard-delete surface — the archived row remains
selectable because SELECT is `using (true)`:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
EID=$(curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?select=id&limit=1" | python3 -c 'import sys,json;print(json.load(sys.stdin)[0]["id"])')
# create: padded body trimmed server-side -> returns the new uuid
CID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_comment" \
  -d "{\"p_event_id\":\"$EID\",\"p_body\":\"  hello  \"}" | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID&select=body"                   # -> body "hello" (trimmed)
# edit (body only): returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_comment" \
  -d "{\"p_id\":\"$CID\",\"p_body\":\"edited\"}"
# archive: sets deleted_at; the row is STILL selectable (using(true)) — the feature
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_comment" -d "{\"p_id\":\"$CID\"}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID&select=id,body,deleted_at"     # -> row present, deleted_at non-null
# restore (unarchive): clears deleted_at back to null
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/restore_comment" -d "{\"p_id\":\"$CID\"}"
# guards: blank body -> check violation; edit of an archived row -> no_data_found; no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_comment" \
  -d "{\"p_event_id\":\"$EID\",\"p_body\":\"   \"}"                # -> 400
# edit refuses an archived comment: archive it, then update_comment -> no_data_found (P0002)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_comment" -d "{\"p_id\":\"$CID\"}"
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_comment" \
  -d "{\"p_id\":\"$CID\",\"p_body\":\"x\"}"                        # -> {"code":"P0002", ... "not found or already archived"}
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_comments?id=eq.$CID"                                # -> 401 (no delete grant)
```

## Verify: contact write RPCs (Decision 26, Slice 1)
`create_contact` / `update_contact` are the RPC write path for contacts. All six of `create_contact`'s
value params are required — only its **trailing** `p_id` defaults (Decision 41); `update_contact`
defaults nothing, and its `p_id` leads. These curls prove the server-side normalization, that
`update_contact` refuses a soft-deleted / absent row (`no_data_found`) rather than silently mutating
a hidden row, and that **soft-delete is non-destructive** — provable only as a superuser, since
`contacts_select` is `using (deleted_at is null)` and `soft_delete_contact` returns `void`, so
*nothing anon can observe* tells a soft-delete apart from a hard one (issue #19):
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create: padded name trimmed, empty email nullified server-side -> returns the new uuid
NID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"  Ada  ","p_dob":null,"p_email":"   ","p_phone":"123","p_company":null,"p_remarks":null}' \
  | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/contacts?id=eq.$NID&select=name,email,phone"             # -> name "Ada", email null, phone "123"
# update: fields change, returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_contact" \
  -d "{\"p_id\":\"$NID\",\"p_name\":\"Bob\",\"p_dob\":null,\"p_email\":\"b@x.io\",\"p_phone\":null,\"p_company\":null,\"p_remarks\":null}"
# blank name -> check violation (contacts_name_check)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"   ","p_dob":null,"p_email":null,"p_phone":null,"p_company":null,"p_remarks":null}'  # -> 400
# the new guard: soft-delete the row, then update_contact on it -> no_data_found (row not resurrected)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_contact" -d "{\"p_id\":\"$NID\"}"
# NON-DESTRUCTIVE (issue #19), in two halves. To anon the row simply VANISHES — byte-for-byte what a
# hard DELETE would look like, because contacts_select is `using (deleted_at is null)`:
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/contacts?id=eq.$NID&select=name"                         # -> [] (invisible — proves nothing on its own)
# ...so prove SURVIVAL as superuser. This read is the whole point: the row is still there, just flagged.
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select id, deleted_at is not null from public.contacts where id = '$NID';"  # -> row present, deleted_at set (t)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_contact" \
  -d "{\"p_id\":\"$NID\",\"p_name\":\"X\",\"p_dob\":null,\"p_email\":null,\"p_phone\":null,\"p_company\":null,\"p_remarks\":null}"
  # -> {"code":"P0002", ... "contact <uuid> not found or already deleted"} — the guard rolled back
```

## Verify: event type write RPCs (Decision 26, Slice 2)
`create_event_type` / `update_event_type` are the RPC write path for event types. Same shape as
the contact RPCs — server-side name trim, `update_event_type` refuses a soft-deleted / absent
row (`no_data_found`), and soft-delete is non-destructive (superuser read, same reasoning as the
contacts block). The second block below proves the **null-embed contract** that `Event.fromJson`
depends on (issue #19):
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create: padded name trimmed -> returns the new uuid
TID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"  Focus  ","p_color":"#4E7BC9"}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_types?id=eq.$TID&select=name,color"                # -> name "Focus", color "#4E7BC9"
# update: rename + recolor, returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_event_type" \
  -d "{\"p_id\":\"$TID\",\"p_name\":\"Deep work\",\"p_color\":\"#22A06B\"}"
# blank name -> check violation (event_types name check)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"   ","p_color":"#4E7BC9"}'                        # -> 400
# malformed colour -> check violation (color ~ '^#[0-9A-Fa-f]{6}$', fires through the RPC)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"Bad","p_color":"red"}'                            # -> 400
# the new guard: soft-delete the row, then update_event_type on it -> no_data_found
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_event_type" -d "{\"p_id\":\"$TID\"}"
# NON-DESTRUCTIVE (issue #19): hidden from anon (`using (deleted_at is null)`), still on disk.
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select id, deleted_at is not null from public.event_types where id = '$TID';"  # -> row present, deleted_at set (t)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_event_type" \
  -d "{\"p_id\":\"$TID\",\"p_name\":\"X\",\"p_color\":\"#4E7BC9\"}"
  # -> {"code":"P0002", ... "event type <uuid> not found or already deleted"} — the guard rolled back
```

**Soft-deleted type → the event's embed reads back `null`** (issue #19). `lib/models/event.dart`
treats a null `event_types` embed as "No type", and `events_repository.dart` uses a **plain** embed
(never `!inner`, which would drop the whole event). These curls pin that contract at the DB layer.
Needs a **fresh** type + event — `$TID` above is already soft-deleted. Note `create_event`'s first **eight**
params are all required (only `p_type_id` / `p_id` default) — hence the explicit nulls: an omitted
param is a **PGRST202**, not a default. (`create_event` *normalizes* an all-day event's times to
null itself, so `events_time_valid` never bites this direction — it only fires on `all_day:false`
with null/inverted times.):
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
ETID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event_type" \
  -d '{"p_name":"Review","p_color":"#22A06B"}' | tr -d '"')
EID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event" \
  -d "{\"p_title\":\"Quarterly review\",\"p_event_date\":\"2026-08-01\",\"p_all_day\":true,\"p_start_time\":null,\"p_end_time\":null,\"p_location\":null,\"p_notes\":null,\"p_attendees\":[],\"p_type_id\":\"$ETID\"}" | tr -d '"')
# sanity: both must be uuids — a bad payload returns an error BODY here, and every check below
# would then silently query a garbage id while still "passing"
echo "$ETID / $EID"
# before: the embed carries the type
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?id=eq.$EID&select=title,type_id,event_types(id,name)"
  # -> [{"title":"Quarterly review","type_id":"<uuid>","event_types":{"id":"<uuid>","name":"Review"}}]
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_event_type" -d "{\"p_id\":\"$ETID\"}"
# after: embed is null — but the EVENT SURVIVES (plain embed, not !inner) and type_id STILL holds
# the id. That pair is the proof: the link was never cut, the type row is merely hidden by RLS.
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?id=eq.$EID&select=title,type_id,event_types(id,name)"
  # -> [{"title":"Quarterly review","type_id":"<uuid, same as above>","event_types":null}]
# and the type row itself is on disk, flagged not erased
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select id, deleted_at is not null from public.event_types where id = '$ETID';"  # -> row present, deleted_at set (t)
```

## Verify: event write RPCs + the attendee parent-gate (Decision 18)
`create_event` / `update_event` / `soft_delete_event` are the RPC write path for events. Beyond the
usual non-destructiveness proof, this block covers the one place in the schema where a **child**
table is hidden by its **parent's** soft-delete: `event_attendees_select` gates on
`exists(… events.deleted_at is null)`, so archiving an event also hides its attendee rows from anon
— while both survive on disk. (every other child table —
`task_contacts`, `task_category_links`, `event_comments`, `task_comments` — is `using (true)`, so
events/attendees are genuinely the only such pair.) `p_attendees` are NOT NULL FKs into `contacts`,
so this block mints its own contact rather than borrowing one:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
C1=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"Grace","p_dob":null,"p_email":null,"p_phone":null,"p_company":null,"p_remarks":null}' | tr -d '"')
# all-day event with one attendee. All 8 leading params are required — omit one and it's a PGRST202,
# so $EID silently becomes an error body (the echo below is what catches that). The explicit null
# times mirror what the RPC stores: it normalizes an all-day event's times to null itself, so
# events_time_valid only bites the all_day:false direction, never this one.
EID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_event" \
  -d "{\"p_title\":\"Standup\",\"p_event_date\":\"2026-08-02\",\"p_all_day\":true,\"p_start_time\":null,\"p_end_time\":null,\"p_location\":null,\"p_notes\":null,\"p_attendees\":[\"$C1\"]}" | tr -d '"')
echo "$C1 / $EID"                                                 # -> both must be uuids, not error bodies
# before: event + its attendee roster are visible to anon
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?id=eq.$EID&select=title,event_attendees(contact_id,contacts(name))"
  # -> event_attendees[0].contacts.name "Grace"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_attendees?event_id=eq.$EID&select=contact_id"      # -> 1 row
# archive the event
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_event" -d "{\"p_id\":\"$EID\"}"
# after: BOTH vanish for anon — the event by its own `deleted_at is null` policy, the attendee rows
# by the parent-live gate. Neither read distinguishes this from a cascading hard DELETE:
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?id=eq.$EID&select=title"                          # -> []
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/event_attendees?event_id=eq.$EID&select=contact_id"      # -> [] (parent-gated, NOT deleted)
# ...so prove BOTH survive as superuser — this is the only read that can:
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select 'event' as what, e.id::text, (e.deleted_at is not null)::text from public.events e where e.id='$EID'
   union all
   select 'attendees', count(*)::text, '' from public.event_attendees where event_id='$EID'
   order by what desc;"
  # -> event|<uuid>|true
  # -> attendees|1|          — the join row was never cascaded away
# update_event refuses the archived event -> no_data_found (P0002). This is the guard that makes the
# line above hold: the call below passes p_attendees:[] , so WITHOUT the guard it would silently wipe
# the roster of a hidden event and return success (see the rationale in 20260710120300:101-104).
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_event" \
  -d "{\"p_id\":\"$EID\",\"p_title\":\"Hijacked\",\"p_event_date\":\"2026-08-02\",\"p_all_day\":true,\"p_start_time\":null,\"p_end_time\":null,\"p_location\":null,\"p_notes\":null,\"p_attendees\":[],\"p_type_id\":null}"
  # -> {"code":"P0002", ... "event <uuid> not found or already deleted"} — the guard rolled back
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select count(*) from public.event_attendees where event_id = '$EID';"  # -> 1 (roster survived the refused update)
# no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/events?id=eq.$EID"                                       # -> 401 (no delete grant)
```

## Verify: task category write RPCs (Decision 39, Slice A)
`create_task_category` / `update_task_category` / `soft_delete_task_category` are the RPC write path
for task categories — a separate taxonomy from event types, same shape as the event-type RPCs.
Born on the RPC path (post-Decision-36): the table is **SELECT-only** for clients (no insert/update
grant or policy), so these curls also prove writes are RPC-only. `update_task_category` refuses a
soft-deleted / absent row (`no_data_found`), and soft-delete is non-destructive (the row survives
with `deleted_at` set — provable only as a superuser, since the `using (deleted_at is null)` SELECT
policy hides it from anon):
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create: padded name trimmed -> returns the new uuid
CID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_category" \
  -d '{"p_name":"  Follow-up  ","p_color":"#4E7BC9"}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_categories?id=eq.$CID&select=name,color"            # -> name "Follow-up", color "#4E7BC9"
# update: rename + recolor, returns the same id
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task_category" \
  -d "{\"p_id\":\"$CID\",\"p_name\":\"Waiting-on\",\"p_color\":\"#22A06B\"}"
# SELECT-only closure: direct write as anon is refused (never granted) — writes are RPC-only
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/task_categories" \
  -d '{"name":"Direct","color":"#4E7BC9"}'                        # -> 401 (no insert grant)
curl -s -o /dev/null -w '%{http_code}\n' -X PATCH -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/task_categories?id=eq.$CID" \
  -d '{"name":"Direct"}'                                          # -> 401 (no update grant)
# blank name -> check violation (task_categories name check)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_category" \
  -d '{"p_name":"   ","p_color":"#4E7BC9"}'                       # -> 400
# malformed colour -> check violation (color ~ '^#[0-9A-Fa-f]{6}$', fires through the RPC).
# This is the DB guard behind the model's #RRGGBB parser (its grey fallback is defensive-only).
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_category" \
  -d '{"p_name":"Bad","p_color":"blue"}'                          # -> 400
# soft-delete is NON-DESTRUCTIVE (run the read as superuser: the SELECT policy hides it from anon,
# so an anon read would prove only invisibility, not survival):
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_task_category" -d "{\"p_id\":\"$CID\"}"
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select id, deleted_at is not null from public.task_categories where id = '$CID';"  # -> row present, deleted_at set (t)
# update refuses the soft-deleted row -> no_data_found (P0002)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task_category" \
  -d "{\"p_id\":\"$CID\",\"p_name\":\"X\",\"p_color\":\"#4E7BC9\"}"
  # -> {"code":"P0002", ... "task category <uuid> not found or already deleted"} — the guard rolled back
# no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_categories?id=eq.$CID"                              # -> 401 (no delete grant)
```

## Verify: task write RPCs (Decision 27)
`create_task` / `update_task` / `soft_delete_task` / `restore_task` are the RPC write path for
tasks. Like `event_comments`, `tasks` uses a `using (true)` SELECT policy so archived tasks stay
readable (the "view archived" section) — these curls prove the four RPCs, the archived-readable
behaviour, the optional-`notes` normalization (blank/whitespace → NULL, like `title`'s trim), and
the guards:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create: padded title + notes trimmed server-side -> returns the new uuid; is_done defaults false
TID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" \
  -d '{"p_title":"  Buy milk  ","p_notes":"  ring the supplier  "}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$TID&select=title,is_done,notes,deleted_at"  # -> title "Buy milk", is_done false, notes "ring the supplier", deleted_at null
# update: rename + mark done + edit notes (one path serves the form save AND the list complete-toggle)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task" \
  -d "{\"p_id\":\"$TID\",\"p_title\":\"Buy oat milk\",\"p_is_done\":true,\"p_notes\":\"  call the supplier back  \",\"p_contacts\":[],\"p_importance\":0,\"p_categories\":[]}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$TID&select=title,is_done,notes"            # -> "Buy oat milk", is_done true, notes "call the supplier back" (trimmed)
# archive: sets deleted_at; the row — INCLUDING its notes — is STILL selectable (using(true)) = the "view archived" feature
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_task" -d "{\"p_id\":\"$TID\"}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$TID&select=id,is_done,notes,deleted_at"    # -> row present, notes "call the supplier back" readable, deleted_at non-null
# update refuses an archived task -> no_data_found (P0002)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task" \
  -d "{\"p_id\":\"$TID\",\"p_title\":\"x\",\"p_is_done\":false,\"p_notes\":null,\"p_contacts\":[],\"p_importance\":0,\"p_categories\":[]}"  # -> {"code":"P0002", ... "not found or already archived"}
# restore (unarchive): clears deleted_at back to null
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/restore_task" -d "{\"p_id\":\"$TID\"}"
# notes normalization: blank/whitespace p_notes -> NULL (like title's trim); p_notes omitted -> default null
BID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" -d '{"p_title":"blank-note","p_notes":"   "}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$BID&select=notes"                          # -> notes null (whitespace normalized to NULL)
NID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" -d '{"p_title":"No-note task"}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$NID&select=notes"                          # -> notes null (p_notes omitted -> default null)
# guards: blank title -> check violation; no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" -d '{"p_title":"   "}'  # -> 400
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$TID"                                        # -> 401 (no delete grant)
```

## Verify: task People (task_contacts, Decision 34)
`create_task` / `update_task` also carry `p_contacts uuid[]` — the linked-contacts ("People")
set, written atomically into the `task_contacts` join (membership is set ONLY by these RPCs;
`task_contacts` grants anon SELECT only). These curls prove: `p_contacts` links contacts,
`on conflict do nothing` dedupes a repeated id, `update` replaces the whole set (delete +
reinsert), and the embed reads them back. It mints its own two contacts (all six `create_contact`
value params are required — only the trailing `p_id` defaults):
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
C1=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"Nadia","p_dob":null,"p_email":null,"p_phone":null,"p_company":"Acme","p_remarks":null}' | tr -d '"')
C2=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_contact" \
  -d '{"p_name":"Bo","p_dob":null,"p_email":null,"p_phone":null,"p_company":null,"p_remarks":null}' | tr -d '"')
# create with People (C1 listed twice -> on conflict dedupes to one row)
PID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" \
  -d "{\"p_title\":\"Prep the pitch\",\"p_contacts\":[\"$C1\",\"$C1\",\"$C2\"]}" | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$PID&select=title,task_contacts(contact_id,contacts(id,name,company))"  # -> two People (dup collapsed), embed resolves
# update replaces the whole set -> only C2 remains
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task" \
  -d "{\"p_id\":\"$PID\",\"p_title\":\"Prep the pitch\",\"p_is_done\":false,\"p_notes\":null,\"p_contacts\":[\"$C2\"],\"p_importance\":0,\"p_categories\":[]}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$PID&select=task_contacts(contact_id)"      # -> exactly one row, contact_id = $C2
# update with empty People clears the set
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task" \
  -d "{\"p_id\":\"$PID\",\"p_title\":\"Prep the pitch\",\"p_is_done\":false,\"p_notes\":null,\"p_contacts\":[],\"p_importance\":0,\"p_categories\":[]}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_contacts?task_id=eq.$PID"                          # -> [] (set cleared)
# no direct write: anon INSERT into the join is refused (membership is RPC-only)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/task_contacts" \
  -d "{\"task_id\":\"$PID\",\"contact_id\":\"$C1\"}"             # -> 401 (no insert grant)
```

## Verify: task categories (task_category_links, Decision 40, Slice B)
`create_task` / `update_task` also carry `p_categories uuid[]` — the linked-category set, written
atomically into the `task_category_links` join (membership is set ONLY by these RPCs;
`task_category_links` grants anon SELECT only, no write). Mirrors `p_contacts` exactly. These curls
prove: `p_categories` links categories, `update` replaces the whole set, the embed reads them back,
and a direct anon write to the join is refused. It mints its own two categories:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
K1=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_category" \
  -d '{"p_name":"Work","p_color":"#4E7BC9"}' | tr -d '"')
K2=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_category" \
  -d '{"p_name":"Home","p_color":"#22A06B"}' | tr -d '"')
# create with categories (create_task defaults every arg but p_title, so name only the ones we set)
TCID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" \
  -d "{\"p_title\":\"Prep the pitch\",\"p_categories\":[\"$K1\",\"$K2\"]}" | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$TCID&select=title,task_category_links(category_id,task_categories(id,name,color))"  # -> two categories, embed resolves
# update replaces the whole set -> only K2 remains (p_categories is REQUIRED on update — no default)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task" \
  -d "{\"p_id\":\"$TCID\",\"p_title\":\"Prep the pitch\",\"p_is_done\":false,\"p_notes\":null,\"p_contacts\":[],\"p_importance\":0,\"p_categories\":[\"$K2\"]}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_category_links?task_id=eq.$TCID&select=category_id"   # -> exactly one row, category_id = $K2
# no direct write: anon INSERT into the join is refused (membership is RPC-only)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/task_category_links" \
  -d "{\"task_id\":\"$TCID\",\"category_id\":\"$K1\"}"               # -> 401 (no insert grant)
```

## Verify: task comment write RPCs (Decision 33, Slice 2b)
`create_task_comment` / `update_task_comment` / `soft_delete_task_comment` / `restore_task_comment`
are the RPC write path for `task_comments` — the task-side twin of `event_comments`. Same
`using (true)` archived-readable SELECT policy. It mints its own task. These curls prove the four
RPCs, archived-readable, and the guards:
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
TID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" -d '{"p_title":"Task with comments"}' | tr -d '"')
# create: padded body trimmed server-side -> returns the new comment uuid
CID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_comment" \
  -d "{\"p_task_id\":\"$TID\",\"p_body\":\"  first note  \"}" | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_comments?id=eq.$CID&select=body,task_id"           # -> body "first note" (trimmed), task_id = $TID
# edit (body only)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task_comment" \
  -d "{\"p_id\":\"$CID\",\"p_body\":\"edited note\"}"
# archive: sets deleted_at; the row stays selectable (using(true)) = the "view archived" feature
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/soft_delete_task_comment" -d "{\"p_id\":\"$CID\"}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_comments?id=eq.$CID&select=id,body,deleted_at"     # -> row present, deleted_at non-null
# edit refuses an archived comment -> no_data_found (P0002)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task_comment" \
  -d "{\"p_id\":\"$CID\",\"p_body\":\"nope\"}"                   # -> {"code":"P0002", ... "not found or already archived"}
# restore (unarchive): clears deleted_at back to null
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/restore_task_comment" -d "{\"p_id\":\"$CID\"}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_comments?id=eq.$CID&select=deleted_at"            # -> deleted_at back to null
# restore refuses a live (not-archived) comment -> no_data_found (P0002)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/restore_task_comment" -d "{\"p_id\":\"$CID\"}"  # -> {"code":"P0002", ... "not found or not archived"}
# guards: blank body -> check violation; no hard-delete grant
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task_comment" -d "{\"p_task_id\":\"$TID\",\"p_body\":\"   \"}"  # -> 400
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/task_comments?id=eq.$CID"                               # -> 401 (no delete grant)
```

## Verify: task importance (Decision 38)
`create_task` / `update_task` also carry `p_importance smallint` — a fixed 0..3 priority marker.
These curls prove: importance round-trips, out-of-range is rejected by the `check (importance between
0 and 3)`, and — the signature-bump lockdown invariant — the recreated RPCs did **not** reopen
`EXECUTE` to `PUBLIC` (the `has_function_privilege` check must be run as a DB superuser via `psql`,
not over anon REST — an anon curl can't observe PUBLIC's grant, only its own).
```bash
ANON=$(grep SUPABASE_ANON_KEY .env | cut -d= -f2)
REST=http://localhost:8000/rest/v1
# create at importance 3, read it back
IID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" \
  -d '{"p_title":"Ship the release","p_importance":3}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$IID&select=title,importance"              # -> importance 3
# update lowers it to 1 (must re-send the whole task: title/is_done/notes/contacts/importance/categories)
curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/update_task" \
  -d "{\"p_id\":\"$IID\",\"p_title\":\"Ship the release\",\"p_is_done\":false,\"p_notes\":null,\"p_contacts\":[],\"p_importance\":1,\"p_categories\":[]}"
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$IID&select=importance"                    # -> importance 1
# out-of-range -> 400 check violation (importance_check)
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" \
  -d '{"p_title":"bad","p_importance":4}'                        # -> 400
# omitted p_importance defaults to 0 (none)
DID=$(curl -s -X POST -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  -H "Content-Type: application/json" "$REST/rpc/create_task" -d '{"p_title":"No-priority task"}' | tr -d '"')
curl -s -H "apikey: $ANON" -H "Authorization: Bearer $ANON" \
  "$REST/tasks?id=eq.$DID&select=importance"                    # -> importance 0
# LOCKDOWN INVARIANT (run as superuser, not anon): the recreated RPCs stay revoked from PUBLIC
docker compose exec -T db psql -U postgres -d postgres -tAc \
  "select has_function_privilege('public','public.create_task(text,text,uuid[],smallint)','execute'), \
          has_function_privilege('public','public.update_task(uuid,text,boolean,text,uuid[],smallint)','execute');"  # -> f|f
```

## Layout
```text
docker-compose.yml   db + rest + gateway
gen-env.sh           writes .env + dev-defines.json (dev secrets, gitignored)
.env.example         template (safe to commit)
init/init.sh         runs once on a fresh volume: roles -> migrations -> seed
migrations/*.sql     forward-only, timestamped. Never edit one that has run; add a new one.
seed.sql             dev-only sample data (not a migration)
caddy/Caddyfile      /rest/v1 -> PostgREST, + permissive CORS for the Flutter web target
```

## Conventions in play (docs/database.md)
- RLS on every table; anon may **read** non-deleted rows directly, but **all writes go through the
  RPCs** — the direct anon/authenticated INSERT/UPDATE grants were revoked by Decision 36 (see below).
- **Soft-delete only** — no hard `DELETE` grant. Deletes go through the
  `soft_delete_contact(uuid)` `SECURITY DEFINER` RPC (a direct UPDATE of `deleted_at`
  fails the SELECT policy via PostgREST's RETURNING — that's why the RPC exists).
- `updated_at` is bumped by a trigger on every update.
- **`event_comments`, `task_comments` and `tasks` are the exceptions to "soft-deleted = hidden":**
  their SELECT policy is `using (true)` so archived rows stay readable (the "view archived"
  toggle/section; tasks: Decision 27; task comments: Decision 33). Their **writes** are not an
  exception — event comments route through `create_comment` … RPCs (Decision 26 / Slice 3), and
  `task_comments` is born on the RPC path via `create_task_comment` / `update_task_comment` /
  `soft_delete_task_comment` / `restore_task_comment` — for uniformity; the `using (true)` policy
  means there was never a 42501 forcing a direct write. Still no hard-`DELETE` grant.
  **RPCs are the *enforced* sole write path (Decision 36):** the direct `anon`/`authenticated`
  INSERT/UPDATE grants and the direct-write RLS policies were revoked/dropped, and `EXECUTE` was
  revoked from `PUBLIC` on every SECURITY DEFINER RPC — so a PostgREST client can no longer bypass
  the RPCs. `auth.uid()` owner checks are **WON'T-DO (Decision 37)** — single-user + tailnet-only is
  the security boundary, no login is planned; issue #3 is closed (only the optional `search_path=''`
  hardening remains).

## To homebase (later)
Move this stack into `okpilot/selfhost/stacks/`, drop the local Caddy gateway (the
existing homebase Caddy adds the route + TLS), and regenerate real secrets — never reuse
these dev values. **No GoTrue** — single-user + tailnet-only is the security boundary and
login is WON'T-DO (Decision 37), not deferred.
