-- 0001_extensions.sql
-- Required PostgreSQL extensions for the community app.

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Used for semantic candidate retrieval (AI matching / news). Safe no-op if
-- the platform already ships it; guarded so environments without pgvector
-- available do not fail migration entirely-critical paths.
do $$
begin
  create extension if not exists vector;
exception when others then
  raise notice 'pgvector extension not available in this environment, skipping';
end $$;
