-- Local E2E prelude: Supabase-shaped platform stubs so the REAL committed
-- migrations apply unmodified on plain PostgreSQL 16.
-- Stubs provided: auth schema (users, uid(), jwt()), roles, vault, cron, net.
-- auth.uid()/auth.jwt() read session GUCs, mirroring how PostgREST injects
-- the request JWT — tests set them with `set request.jwt.claim.sub = ...`.
-- service_role gets BYPASSRLS, matching Supabase's real attribute.

-- ---------- roles ----------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

-- ---------- auth schema ----------
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  created_at timestamptz not null default now()
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

-- ---------- vault schema (secrets never leave this stub) ----------
create schema if not exists vault;

create table if not exists vault.secrets (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  secret text not null,
  description text,
  created_at timestamptz not null default now()
);

create or replace function vault.create_secret(
  p_secret text, p_name text default null, p_description text default null
) returns uuid
language plpgsql
as $$
declare v_id uuid;
begin
  insert into vault.secrets(name, secret, description)
  values (coalesce(p_name, gen_random_uuid()::text), p_secret, p_description)
  returning id into v_id;
  return v_id;
end $$;

create or replace function vault.update_secret(
  p_id uuid, p_secret text, p_name text default null, p_description text default null
) returns uuid
language plpgsql
as $$
begin
  update vault.secrets
     set secret = p_secret,
         name = coalesce(p_name, name),
         description = coalesce(p_description, description)
   where id = p_id;
  return p_id;
end $$;

create or replace view vault.decrypted_secrets as
  select id, name, secret as decrypted_secret, description from vault.secrets;

-- ---------- cron / net schema stubs (pg_cron, pg_net are Supabase-only) ----------
-- cron.schedule only records the job; the scheduled bodies (which call
-- net.http_post) are never executed by this harness.
create schema if not exists cron;

create table if not exists cron.job (
  jobid bigserial primary key,
  schedule text not null,
  command text not null
);

create or replace function cron.schedule(p_schedule text, p_command text)
returns bigint
language plpgsql
as $$
declare v_id bigint;
begin
  insert into cron.job(schedule, command) values (p_schedule, p_command)
  returning jobid into v_id;
  return v_id;
end $$;

-- 3-arg overload (job_name, schedule, command) used by project10
create or replace function cron.schedule(
  p_name text, p_schedule text, p_command text
) returns bigint
language plpgsql
as $$
declare v_id bigint;
begin
  insert into cron.job(schedule, command) values (p_schedule, p_name || ' :: ' || p_command)
  returning jobid into v_id;
  return v_id;
end $$;

create schema if not exists net;

create or replace function net.http_post(
  url text, headers jsonb default '{}'::jsonb, body text default null
) returns jsonb
language plpgsql
as $$
begin
  raise exception 'net.http_post is disabled in the local E2E harness'
    using errcode = 'P0001';
end $$;

-- ---------- storage schema stub (buckets/objects RLS touched by one migration) ----------
create schema if not exists storage;

create table if not exists storage.buckets (
  id text primary key,
  name text not null unique,
  public boolean not null default false
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text not null,
  owner uuid,
  created_at timestamptz not null default now()
);

create or replace function storage.foldername(name text)
returns text[]
language sql
immutable
as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
