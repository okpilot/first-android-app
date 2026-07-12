-- 20260712120000_pgrst_ddl_watch.sql
-- Auto-reload PostgREST's schema cache on every schema change.
--
-- PostgREST reads the schema ONCE at startup and caches it. Until it reloads, a table or function
-- created by a later migration is invisible to it — the symptom is a live relation that GETs fine
-- but 404s on write (this bit us on `event_comments`: adding a comment 404'd while the DB, RLS and
-- grants were all correct — Decision 25). These two event triggers are the canonical Supabase
-- mechanism: any DDL fires `NOTIFY pgrst, 'reload schema'`, so PostgREST re-reads immediately —
-- for tables AND functions, and even for ad-hoc `psql` DDL applied outside `deploy-homebase.sh`.
-- Once verified, this supersedes the manual reload that `deploy-homebase.sh` runs post-migration
-- (removed in the same slice).
--
-- Forward-only; never edit after it has run somewhere — add a new migration instead. Creating event
-- triggers requires superuser; the deploy runs as `postgres`.

-- One function serves both triggers. It only issues NOTIFY and touches no schema objects, so
-- search_path is pinned to '' as defence-in-depth (zero injection surface). Not SECURITY DEFINER:
-- it runs in the DDL executor's context and NOTIFY needs no elevated privilege.
create or replace function public.pgrst_watch()
  returns event_trigger
  language plpgsql
  set search_path = ''
as $$
begin
  notify pgrst, 'reload schema';
end;
$$;

-- ddl_command_end covers CREATE / ALTER / GRANT / REVOKE; sql_drop covers DROP.
-- drop-if-exists first so the migration is safe to re-apply on a fresh DB.
drop event trigger if exists pgrst_ddl_watch;
create event trigger pgrst_ddl_watch on ddl_command_end execute function public.pgrst_watch();

drop event trigger if exists pgrst_drop_watch;
create event trigger pgrst_drop_watch on sql_drop execute function public.pgrst_watch();
