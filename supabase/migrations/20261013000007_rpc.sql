-- =============================================================================
--  20261013000007 — Operaciones críticas del servidor
-- -----------------------------------------------------------------------------
--  * cast_ballot: registra participación y papeleta en UNA transacción, de forma
--    idempotente, sin crear vínculo entre identidad y opción.
--  * get_operation_status: permite consultar el estado de una operación cuyo
--    resultado de red se perdió (no se asume fallo).
--
--  Contrato de dispositivo: el dispositivo NO escribe tablas; llama a este RPC
--  con un usuario de Auth (auth_user_id en voting_devices). La función deriva el
--  dispositivo y su asignación; nunca confía en un id pasado por el cliente.
-- =============================================================================

create or replace function public.cast_ballot(
  p_operation_id     uuid,
  p_voter_ref        uuid,
  p_option_type      public.ballot_option_type,
  p_candidate_list_id uuid default null,
  p_ballot_id        uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_device        public.voting_devices%rowtype;
  v_assignment    public.device_assignments%rowtype;
  v_election      public.elections%rowtype;
  v_voter         public.election_voters%rowtype;
  v_existing      public.sync_status;
begin
  -- 1. Dispositivo autorizado (derivado de la sesión, no del cliente).
  select * into v_device
  from public.voting_devices
  where auth_user_id = auth.uid() and status = 'authorized';
  if not found then
    raise exception 'device_not_authorized' using errcode = '42501';
  end if;

  -- 2. Asignación vigente.
  select * into v_assignment
  from public.device_assignments
  where device_id = v_device.id and revoked_at is null
  order by authorized_at desc
  limit 1;
  if not found then
    raise exception 'device_not_assigned' using errcode = '42501';
  end if;

  -- 3. Idempotencia: ¿ya se procesó esta operación?
  select status into v_existing
  from public.sync_operations
  where operation_id = p_operation_id;
  if found then
    return jsonb_build_object(
      'operation_id', p_operation_id,
      'status', v_existing,
      'duplicate', true
    );
  end if;

  -- 4. Registrar la operación desde el inicio (para conciliación).
  insert into public.sync_operations(operation_id, device_id, election_id, status)
  values (p_operation_id, v_device.id, v_assignment.election_id, 'pending');

  -- 5. Validar elección abierta (reloj del servidor, no del dispositivo).
  select * into v_election from public.elections where id = v_assignment.election_id;
  if v_election.status <> 'open' then
    update public.sync_operations
      set status = 'rejected', error_code = 'election_not_open'
      where operation_id = p_operation_id;
    return jsonb_build_object('operation_id', p_operation_id, 'status', 'rejected',
                              'error_code', 'election_not_open');
  end if;
  if (v_election.opens_at is not null and now() < v_election.opens_at)
     or (v_election.closes_at is not null and now() > v_election.closes_at) then
    update public.sync_operations
      set status = 'rejected', error_code = 'outside_window'
      where operation_id = p_operation_id;
    return jsonb_build_object('operation_id', p_operation_id, 'status', 'rejected',
                              'error_code', 'outside_window');
  end if;

  -- 6. Validar votante habilitado en el padrón de ESTA elección.
  select * into v_voter
  from public.election_voters
  where voter_ref = p_voter_ref and election_id = v_election.id and enabled = true;
  if not found then
    update public.sync_operations
      set status = 'rejected', error_code = 'voter_not_found'
      where operation_id = p_operation_id;
    return jsonb_build_object('operation_id', p_operation_id, 'status', 'rejected',
                              'error_code', 'voter_not_found');
  end if;

  -- 7. Participación + papeleta: atómico. El unique convierte el doble voto en
  --    conflicto controlado, no en un error genérico.
  begin
    insert into public.participation_records(
      election_id, election_voter_id, voting_table_id, device_id
    ) values (
      v_election.id, v_voter.id,
      coalesce(v_assignment.voting_table_id, v_voter.voting_table_id),
      v_device.id
    );

    insert into public.ballots(
      id, election_id, voting_table_id, device_id,
      option_type, candidate_list_id, cast_bucket
    ) values (
      p_ballot_id, v_election.id,
      coalesce(v_assignment.voting_table_id, v_voter.voting_table_id),
      v_device.id,
      p_option_type,
      case when p_option_type = 'list' then p_candidate_list_id else null end,
      date_trunc('minute', now())
    );

    update public.sync_operations
      set status = 'accepted' where operation_id = p_operation_id;

    return jsonb_build_object('operation_id', p_operation_id, 'status', 'accepted');

  exception when unique_violation then
    update public.sync_operations
      set status = 'conflict', error_code = 'duplicate_participation'
      where operation_id = p_operation_id;

    insert into public.electoral_incidents(
      election_id, device_id, operation_id, kind, description, status
    ) values (
      v_election.id, v_device.id, p_operation_id, 'duplicate_participation',
      'El votante ya tenía una participación registrada en esta elección.',
      'open'
    );

    return jsonb_build_object('operation_id', p_operation_id, 'status', 'conflict',
                              'error_code', 'duplicate_participation');
  end;
end;
$$;

-- ----------------------------------------------------------------------------
--  get_operation_status  (consultar estado por UUID; solo la propia operación)
-- ----------------------------------------------------------------------------
create or replace function public.get_operation_status(p_operation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_device public.voting_devices%rowtype;
  v_op     public.sync_operations%rowtype;
begin
  select * into v_device
  from public.voting_devices
  where auth_user_id = auth.uid();

  select * into v_op from public.sync_operations where operation_id = p_operation_id;
  if not found then
    return jsonb_build_object('operation_id', p_operation_id, 'status', 'unknown');
  end if;

  -- El dispositivo solo puede consultar sus propias operaciones; un admin, todas.
  if not (public.is_admin() or (v_device.id is not null and v_op.device_id = v_device.id)) then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'operation_id', v_op.operation_id,
    'status', v_op.status,
    'error_code', v_op.error_code
  );
end;
$$;

-- ----------------------------------------------------------------------------
--  Permisos de ejecución
-- ----------------------------------------------------------------------------
revoke all on function public.cast_ballot(uuid, uuid, public.ballot_option_type, uuid, uuid) from public;
revoke all on function public.get_operation_status(uuid) from public;

grant execute on function public.cast_ballot(uuid, uuid, public.ballot_option_type, uuid, uuid) to authenticated;
grant execute on function public.get_operation_status(uuid) to authenticated;
