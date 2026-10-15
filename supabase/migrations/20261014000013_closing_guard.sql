-- =============================================================================
--  20261014000013 — Cierre seguro: no consolidar con pendientes ni conflictos
-- =============================================================================
--  Una elección no debe pasar a 'closing' ni 'closed' mientras queden
--  operaciones de voto sin resolver (status 'pending') o incidencias
--  abiertas/en revisión. cast_ballot solo acepta con la elección en 'open', así
--  que cerrar la captura con dispositivos pendientes provocaría rechazos al
--  sincronizar (regla de "cierre con pendientes" de docs/arquitectura.md).

-- ----------------------------------------------------------------------------
--  election_reconciliation — contadores de conciliación (sin identidad)
-- ----------------------------------------------------------------------------
create or replace function public.election_reconciliation(p_election_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_pending   integer;
  v_conflict  integer;
  v_incidents integer;
begin
  if not public.is_staff() then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select count(*) into v_pending
  from public.sync_operations
  where election_id = p_election_id and status = 'pending';

  select count(*) into v_conflict
  from public.sync_operations
  where election_id = p_election_id and status = 'conflict';

  select count(*) into v_incidents
  from public.electoral_incidents
  where election_id = p_election_id and status in ('open', 'reviewing');

  return jsonb_build_object(
    'election_id', p_election_id,
    'pending_operations', v_pending,
    'conflict_operations', v_conflict,
    'open_incidents', v_incidents,
    'ready_to_close', (v_pending = 0 and v_incidents = 0)
  );
end;
$$;

revoke all on function public.election_reconciliation(uuid) from public;
grant execute on function public.election_reconciliation(uuid) to authenticated;

-- ----------------------------------------------------------------------------
--  transition_election — se re-declara añadiendo el guard de cierre
-- ----------------------------------------------------------------------------
create or replace function public.transition_election(
  p_election_id uuid,
  p_new_status  public.election_status
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_election public.elections%rowtype;
begin
  if not public.is_admin() then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select * into v_election from public.elections where id = p_election_id;
  if not found then
    raise exception 'election_not_found';
  end if;

  if not public.is_valid_transition(v_election.status, p_new_status) then
    raise exception 'invalid_transition from % to %', v_election.status, p_new_status;
  end if;

  -- Requisitos previos a la apertura.
  if p_new_status = 'open' then
    if not exists (
      select 1 from public.election_voters
      where election_id = p_election_id and enabled = true
    ) then
      raise exception 'cannot_open_without_voters';
    end if;
    if not exists (
      select 1 from public.candidate_lists
      where election_id = p_election_id and enabled = true
    ) then
      raise exception 'cannot_open_without_lists';
    end if;
    if not exists (
      select 1 from public.device_assignments da
      join public.voting_devices d on d.id = da.device_id
      where da.election_id = p_election_id and da.revoked_at is null
        and d.status = 'authorized'
    ) then
      raise exception 'cannot_open_without_devices';
    end if;
  end if;

  -- Cierre seguro: no consolidar con operaciones o incidencias sin resolver.
  if p_new_status in ('closing', 'closed') then
    if exists (
      select 1 from public.sync_operations
      where election_id = p_election_id and status = 'pending'
    ) then
      raise exception 'cannot_close_with_pending_operations';
    end if;
    if exists (
      select 1 from public.electoral_incidents
      where election_id = p_election_id and status in ('open', 'reviewing')
    ) then
      raise exception 'cannot_close_with_unresolved_incidents';
    end if;
  end if;

  update public.elections
    set status = p_new_status,
        config_version = case when p_new_status = 'open' then config_version + 1
                              else config_version end
    where id = p_election_id;

  perform public.log_audit(
    'election_status_change', 'election', p_election_id,
    jsonb_build_object('from', v_election.status, 'to', p_new_status)
  );

  return jsonb_build_object('election_id', p_election_id, 'status', p_new_status);
end;
$$;

revoke all on function public.transition_election(uuid, public.election_status) from public;
grant execute on function public.transition_election(uuid, public.election_status) to authenticated;
