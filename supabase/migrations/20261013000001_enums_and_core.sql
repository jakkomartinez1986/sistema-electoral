-- =============================================================================
--  20261013000001 — Tipos, tablas núcleo e infraestructura
-- -----------------------------------------------------------------------------
--  Crea los enums del dominio y las tablas base: instituciones, años lectivos,
--  perfiles de usuario y roles. Todas las tablas expuestas usan RLS (se activa
--  en la migración de seguridad) y deniegan por defecto.
-- =============================================================================

-- gen_random_uuid() es nativo de PostgreSQL 13+; no se requieren extensiones.

-- ----------------------------------------------------------------------------
--  Enums
-- ----------------------------------------------------------------------------
create type public.election_status as enum (
  'draft', 'ready', 'open', 'closing', 'closed', 'archived', 'cancelled'
);

create type public.user_role as enum ('admin', 'operator', 'tutor');

create type public.device_status as enum ('pending', 'authorized', 'revoked');

create type public.ballot_option_type as enum ('list', 'blank', 'null');

create type public.sync_status as enum ('pending', 'accepted', 'rejected', 'conflict');

-- ----------------------------------------------------------------------------
--  Helper: mantener updated_at
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
--  institutions
-- ----------------------------------------------------------------------------
create table public.institutions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  time_zone   text not null default 'America/Guayaquil',
  logo_path   text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint institutions_name_not_blank check (length(btrim(name)) > 0)
);

create trigger trg_institutions_updated_at
  before update on public.institutions
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  academic_years
-- ----------------------------------------------------------------------------
create table public.academic_years (
  id              uuid primary key default gen_random_uuid(),
  institution_id  uuid not null references public.institutions(id) on delete restrict,
  name            text not null,               -- p. ej. "2025-2026"
  starts_on       date,
  ends_on         date,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint academic_years_unique unique (institution_id, name),
  constraint academic_years_dates check (
    starts_on is null or ends_on is null or starts_on <= ends_on
  )
);

create index idx_academic_years_institution on public.academic_years(institution_id);

create trigger trg_academic_years_updated_at
  before update on public.academic_years
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  user_profiles  (1:1 con auth.users)
-- ----------------------------------------------------------------------------
create table public.user_profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  institution_id  uuid references public.institutions(id) on delete set null,
  full_name       text not null,
  email           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint user_profiles_name_not_blank check (length(btrim(full_name)) > 0)
);

create index idx_user_profiles_institution on public.user_profiles(institution_id);

create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  user_roles  (un usuario puede tener varios roles/ámbitos)
-- ----------------------------------------------------------------------------
create table public.user_roles (
  id              uuid primary key default gen_random_uuid(),
  profile_id      uuid not null references public.user_profiles(id) on delete cascade,
  institution_id  uuid references public.institutions(id) on delete cascade,
  role            public.user_role not null,
  created_at      timestamptz not null default now(),
  constraint user_roles_unique unique (profile_id, role, institution_id)
);

create index idx_user_roles_profile on public.user_roles(profile_id);
create index idx_user_roles_institution on public.user_roles(institution_id);

-- ----------------------------------------------------------------------------
--  Helper: ¿el usuario autenticado tiene un rol?
--  SECURITY DEFINER para poder leer user_roles sin recursión de RLS.
-- ----------------------------------------------------------------------------
create or replace function public.has_role(p_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.profile_id = auth.uid()
      and ur.role = p_role
  );
$$;

revoke all on function public.has_role(public.user_role) from public;
grant execute on function public.has_role(public.user_role) to authenticated;
