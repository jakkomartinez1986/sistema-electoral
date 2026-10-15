-- =============================================================================
--  20261013000008 — Máquina de estados, auditoría y configuración descargable
-- =============================================================================

-- ----------------------------------------------------------------------------
--  Auditoría (nunca registra votos, contraseñas ni tokens)
-- ----------------------------------------------------------------------------
create or replace function public.log_audit(
  p_action      text,
  p_target_type text default null,
  p_target_id   uuid default null,
  p_detail      jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.audit_logs(
    institution_id, actor_profile_id, action, target_type, target_id, detail
  ) values (
    public.current_institution_id(), auth.uid(), p_action, p_target_type, p_target_id, p_detail
  );
$$;

revoke all on function public.log_audit(text, text, uuid, jsonb) from public;
grant execute on function public.log_audit(text, text, uuid, jsonb) to authenticated;

-- ----------------------------------------------------------------------------
--  Transiciones válidas de estado
-- ----------------------------------------------------------------------------
create or replace function public.is_valid_transition(
  p_from public.election_status,
  p_to   public.election_status
) returns boolean
language sql immutable
as $$
  select case
    when p_from = 'draft'     and p_to in ('ready', 'cancelled')            then true
    when p_from = 'ready'     and p_to in ('open', 'draft', 'cancelled')    then true
    when p_from = 'open'      and p_to in ('closing', 'cancelled')          then true
    when p_from = 'closing'   and p_to in ('closed', 'open')               then true
    when p_from = 'closed'    and p_to = 'archived'                         then true
    else false
  end;
$$;

-- ----------------------------------------------------------------------------
--  transition_election  (solo administradores; audita el cambio)
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

-- ----------------------------------------------------------------------------
--  generate_election_config  (arma el payload que descargan los dispositivos)
--  No incluye votos ni participación.
-- ----------------------------------------------------------------------------
create or replace function public.generate_election_config(p_election_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_election public.elections%rowtype;
  v_payload  jsonb;
  v_hash     text;
  v_version  integer;
begin
  if not public.is_staff() then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select * into v_election from public.elections where id = p_election_id;
  if not found then
    raise exception 'election_not_found';
  end if;

  v_payload := jsonb_build_object(
    'election', jsonb_build_object(
      'id', v_election.id,
      'name', v_election.name,
      'status', v_election.status,
      'time_zone', v_election.time_zone,
      'opens_at', v_election.opens_at,
      'closes_at', v_election.closes_at
    ),
    'lists', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'number', l.number, 'name', l.name,
        'slogan', l.slogan, 'emblem_path', l.emblem_path
      ) order by l.number)
      from public.candidate_lists l
      where l.election_id = p_election_id and l.enabled = true
    ), '[]'::jsonb),
    'candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id, 'list_id', c.list_id, 'full_name', c.full_name,
        'position', c.position, 'order_index', c.order_index
      ) order by c.order_index)
      from public.candidates c
      join public.candidate_lists l on l.id = c.list_id
      where l.election_id = p_election_id and l.enabled = true
    ), '[]'::jsonb)
  );

  v_hash := encode(sha256(convert_to(v_payload::text, 'UTF8')), 'hex');
  v_version := v_election.config_version;

  insert into public.election_configs(election_id, config_version, payload, hash)
  values (p_election_id, v_version, v_payload, v_hash)
  on conflict (election_id, config_version)
  do update set payload = excluded.payload, hash = excluded.hash, generated_at = now();

  perform public.log_audit(
    'config_generated', 'election', p_election_id,
    jsonb_build_object('config_version', v_version, 'hash', v_hash)
  );

  return jsonb_build_object('config_version', v_version, 'hash', v_hash, 'payload', v_payload);
end;
$$;

revoke all on function public.generate_election_config(uuid) from public;
grant execute on function public.generate_election_config(uuid) to authenticated;
