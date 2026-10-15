-- =============================================================================
--  20261013000005 — Núcleo operativo: participación, papeletas, idempotencia,
--  incidencias, auditoría y vista de resultados.
-- -----------------------------------------------------------------------------
--  REGLA DURA: la identidad del votante (participation_records) y la opción
--  depositada (ballots) NO comparten ninguna clave. La coherencia "1 voto =
--  1 participación + 1 papeleta" la garantiza la transacción del RPC, no un FK.
-- =============================================================================

-- ----------------------------------------------------------------------------
--  Asegurar que una lista pertenece a la misma elección (garantía del servidor).
--  Se logra con un FK compuesto; requiere un índice único (election_id, id).
-- ----------------------------------------------------------------------------
alter table public.candidate_lists
  add constraint candidate_lists_id_election_unique unique (election_id, id);

-- ----------------------------------------------------------------------------
--  participation_records  (CON identidad)
-- ----------------------------------------------------------------------------
create table public.participation_records (
  id                uuid primary key default gen_random_uuid(),
  election_id       uuid not null references public.elections(id) on delete restrict,
  election_voter_id uuid not null references public.election_voters(id) on delete restrict,
  voting_table_id   uuid references public.voting_tables(id) on delete set null,
  device_id         uuid references public.voting_devices(id) on delete set null,
  cast_at           timestamptz not null default now(),
  -- anti-doble-voto dentro del ámbito de la elección:
  constraint participation_records_unique unique (election_id, election_voter_id)
);

create index idx_participation_election on public.participation_records(election_id);
create index idx_participation_voter on public.participation_records(election_voter_id);
create index idx_participation_table on public.participation_records(voting_table_id);

-- ----------------------------------------------------------------------------
--  ballots  (SIN identidad)
-- ----------------------------------------------------------------------------
create table public.ballots (
  id                uuid primary key default gen_random_uuid(),  -- aleatorio
  election_id       uuid not null references public.elections(id) on delete restrict,
  voting_table_id   uuid references public.voting_tables(id) on delete set null,
  device_id         uuid references public.voting_devices(id) on delete set null,
  option_type       public.ballot_option_type not null,
  candidate_list_id uuid,
  cast_bucket       timestamptz not null default date_trunc('minute', now()),
  -- Coherencia opción ↔ lista:
  constraint ballots_option_valid check (
    (option_type = 'list' and candidate_list_id is not null)
    or (option_type in ('blank', 'null') and candidate_list_id is null)
  ),
  -- La lista debe pertenecer a la MISMA elección (FK compuesto):
  constraint ballots_list_same_election
    foreign key (election_id, candidate_list_id)
    references public.candidate_lists(election_id, id)
    on delete restrict
);

create index idx_ballots_election on public.ballots(election_id);
create index idx_ballots_list on public.ballots(candidate_list_id);
create index idx_ballots_table on public.ballots(voting_table_id);

-- ----------------------------------------------------------------------------
--  sync_operations  (ledger de idempotencia; NO enlaza participación ni papeleta)
-- ----------------------------------------------------------------------------
create table public.sync_operations (
  operation_id uuid primary key,               -- UUID aleatorio del cliente
  device_id    uuid references public.voting_devices(id) on delete set null,
  election_id  uuid references public.elections(id) on delete set null,
  status       public.sync_status not null default 'pending',
  error_code   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_sync_operations_device on public.sync_operations(device_id);
create index idx_sync_operations_election on public.sync_operations(election_id);
create index idx_sync_operations_status on public.sync_operations(status);

create trigger trg_sync_operations_updated_at
  before update on public.sync_operations
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  electoral_incidents  (incidencias y conflictos; sin contenido de voto)
-- ----------------------------------------------------------------------------
create table public.electoral_incidents (
  id            uuid primary key default gen_random_uuid(),
  election_id   uuid references public.elections(id) on delete set null,
  device_id     uuid references public.voting_devices(id) on delete set null,
  operation_id  uuid references public.sync_operations(operation_id) on delete set null,
  kind          text not null,                 -- duplicate, config_mismatch, ...
  description   text,
  status        text not null default 'open',  -- open, reviewing, resolved, dismissed
  resolution    text,
  resolved_by   uuid references public.user_profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint electoral_incidents_kind_not_blank check (length(btrim(kind)) > 0)
);

create index idx_incidents_election on public.electoral_incidents(election_id);
create index idx_incidents_status on public.electoral_incidents(status);

create trigger trg_electoral_incidents_updated_at
  before update on public.electoral_incidents
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  audit_logs  (NUNCA registra votos, contraseñas ni tokens)
-- ----------------------------------------------------------------------------
create table public.audit_logs (
  id               uuid primary key default gen_random_uuid(),
  institution_id   uuid references public.institutions(id) on delete set null,
  actor_profile_id uuid references public.user_profiles(id) on delete set null,
  action           text not null,
  target_type      text,
  target_id        uuid,
  detail           jsonb,
  created_at       timestamptz not null default now(),
  constraint audit_logs_action_not_blank check (length(btrim(action)) > 0)
);

create index idx_audit_logs_institution on public.audit_logs(institution_id);
create index idx_audit_logs_actor on public.audit_logs(actor_profile_id);
create index idx_audit_logs_created on public.audit_logs(created_at);

-- ----------------------------------------------------------------------------
--  Vista de resultados (solo agregados; sin identidad)
--  security_invoker = true para que apliquen las RLS de las tablas base.
-- ----------------------------------------------------------------------------
create view public.election_results
with (security_invoker = true)
as
select
  b.election_id,
  b.option_type,
  b.candidate_list_id,
  count(*)::bigint as total
from public.ballots b
group by b.election_id, b.option_type, b.candidate_list_id;
