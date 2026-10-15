-- =============================================================================
--  20261013000004 — Dispositivos de votación y asignaciones
-- =============================================================================

-- ----------------------------------------------------------------------------
--  voting_devices
-- ----------------------------------------------------------------------------
create table public.voting_devices (
  id            uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id) on delete restrict,
  device_uid    text not null,                  -- identificador de hardware
  label         text not null,
  status        public.device_status not null default 'pending',
  app_version   text,
  last_seen_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint voting_devices_unique unique (institution_id, device_uid),
  constraint voting_devices_label_not_blank check (length(btrim(label)) > 0)
);

create index idx_voting_devices_institution on public.voting_devices(institution_id);
create index idx_voting_devices_status on public.voting_devices(status);

create trigger trg_voting_devices_updated_at
  before update on public.voting_devices
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  device_assignments  (dispositivo ↔ elección ↔ mesa)
-- ----------------------------------------------------------------------------
create table public.device_assignments (
  id              uuid primary key default gen_random_uuid(),
  device_id       uuid not null references public.voting_devices(id) on delete cascade,
  election_id     uuid not null references public.elections(id) on delete restrict,
  voting_table_id uuid references public.voting_tables(id) on delete set null,
  config_version  integer not null default 1,
  authorized_at   timestamptz not null default now(),
  revoked_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint device_assignments_unique unique (device_id, election_id)
);

create index idx_device_assignments_device on public.device_assignments(device_id);
create index idx_device_assignments_election on public.device_assignments(election_id);

create trigger trg_device_assignments_updated_at
  before update on public.device_assignments
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  device_enrollment_codes
--  Código de emparejamiento de un solo uso. Se guarda su HASH, no el texto.
--  El canje lo realiza la Edge Function (con la secret key, del lado servidor).
-- ----------------------------------------------------------------------------
create table public.device_enrollment_codes (
  id            uuid primary key default gen_random_uuid(),
  device_id     uuid not null references public.voting_devices(id) on delete cascade,
  code_hash     text not null,
  expires_at    timestamptz not null,
  used_at       timestamptz,
  created_by    uuid references public.user_profiles(id) on delete set null,
  created_at    timestamptz not null default now(),
  constraint device_enrollment_codes_hash_unique unique (code_hash)
);

create index idx_enrollment_codes_device on public.device_enrollment_codes(device_id);
