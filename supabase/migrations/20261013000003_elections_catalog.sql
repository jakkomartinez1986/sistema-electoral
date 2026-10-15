-- =============================================================================
--  20261013000003 — Elecciones, oferta electoral, mesas y padrón
-- =============================================================================

-- ----------------------------------------------------------------------------
--  elections
-- ----------------------------------------------------------------------------
create table public.elections (
  id                uuid primary key default gen_random_uuid(),
  institution_id    uuid not null references public.institutions(id) on delete restrict,
  academic_year_id  uuid not null references public.academic_years(id) on delete restrict,
  name              text not null,
  description       text,
  normativa         text,                       -- normativa aplicable (texto)
  status            public.election_status not null default 'draft',
  time_zone         text not null default 'America/Guayaquil',
  opens_at          timestamptz,
  closes_at         timestamptz,
  config_version    integer not null default 1,
  validity_norm     jsonb not null default '{}'::jsonb, -- reglas de validez configurables
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint elections_name_not_blank check (length(btrim(name)) > 0),
  constraint elections_window check (
    opens_at is null or closes_at is null or opens_at <= closes_at
  )
);

create index idx_elections_institution on public.elections(institution_id);
create index idx_elections_academic_year on public.elections(academic_year_id);
create index idx_elections_status on public.elections(status);

create trigger trg_elections_updated_at
  before update on public.elections
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  voting_tables  (mesas / grupos de votación)
-- ----------------------------------------------------------------------------
create table public.voting_tables (
  id          uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections(id) on delete restrict,
  course_id   uuid references public.courses(id) on delete set null,
  code        text not null,
  name        text,
  capacity    integer,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint voting_tables_unique unique (election_id, code),
  constraint voting_tables_code_not_blank check (length(btrim(code)) > 0),
  constraint voting_tables_capacity check (capacity is null or capacity >= 0)
);

create index idx_voting_tables_election on public.voting_tables(election_id);
create index idx_voting_tables_course on public.voting_tables(course_id);

create trigger trg_voting_tables_updated_at
  before update on public.voting_tables
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  candidate_lists  (cantidad variable de listas)
-- ----------------------------------------------------------------------------
create table public.candidate_lists (
  id          uuid primary key default gen_random_uuid(),
  election_id uuid not null references public.elections(id) on delete restrict,
  number      integer not null,
  name        text not null,
  slogan      text,
  emblem_path text,
  enabled     boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint candidate_lists_unique unique (election_id, number),
  constraint candidate_lists_name_not_blank check (length(btrim(name)) > 0)
);

create index idx_candidate_lists_election on public.candidate_lists(election_id);

create trigger trg_candidate_lists_updated_at
  before update on public.candidate_lists
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  candidates
-- ----------------------------------------------------------------------------
create table public.candidates (
  id          uuid primary key default gen_random_uuid(),
  list_id     uuid not null references public.candidate_lists(id) on delete cascade,
  full_name   text not null,
  position    text not null,                    -- cargo (presidente, etc.)
  order_index integer not null default 0,
  photo_path  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint candidates_name_not_blank check (length(btrim(full_name)) > 0)
);

create index idx_candidates_list on public.candidates(list_id);

create trigger trg_candidates_updated_at
  before update on public.candidates
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  candidate_list_members
-- ----------------------------------------------------------------------------
create table public.candidate_list_members (
  id          uuid primary key default gen_random_uuid(),
  list_id     uuid not null references public.candidate_lists(id) on delete cascade,
  student_id  uuid references public.students(id) on delete set null,
  full_name   text,
  role        text,
  created_at  timestamptz not null default now(),
  constraint candidate_list_members_identity check (
    student_id is not null or (full_name is not null and length(btrim(full_name)) > 0)
  )
);

create index idx_candidate_list_members_list on public.candidate_list_members(list_id);

-- ----------------------------------------------------------------------------
--  election_voters  (padrón POR elección; voter_ref es opaco)
-- ----------------------------------------------------------------------------
create table public.election_voters (
  id              uuid primary key default gen_random_uuid(),
  election_id     uuid not null references public.elections(id) on delete restrict,
  student_id      uuid not null references public.students(id) on delete restrict,
  voting_table_id uuid references public.voting_tables(id) on delete set null,
  voter_ref       uuid not null default gen_random_uuid(),
  enabled         boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint election_voters_unique unique (election_id, student_id),
  constraint election_voters_ref_unique unique (voter_ref)
);

create index idx_election_voters_election on public.election_voters(election_id);
create index idx_election_voters_table on public.election_voters(voting_table_id);
create index idx_election_voters_student on public.election_voters(student_id);

create trigger trg_election_voters_updated_at
  before update on public.election_voters
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  election_configs  (configuración descargable + versión + hash)
-- ----------------------------------------------------------------------------
create table public.election_configs (
  id             uuid primary key default gen_random_uuid(),
  election_id    uuid not null references public.elections(id) on delete cascade,
  config_version integer not null,
  payload        jsonb not null,
  hash           text not null,
  generated_at   timestamptz not null default now(),
  constraint election_configs_unique unique (election_id, config_version)
);

create index idx_election_configs_election on public.election_configs(election_id);
