-- =============================================================================
--  20261013000012 — Descarga del dispositivo: configuración + padrón verificado
-- -----------------------------------------------------------------------------
--  * students.access_pin_hash: PIN de votación guardado como HASH (nunca texto).
--  * set_student_pin: el personal define o borra el PIN de un estudiante.
--  * get_device_bundle: entrega al dispositivo autorizado su asignación, la
--    configuración de la elección (listas/candidatos) y el padrón de su mesa con
--    verificadores OPACOS para identificar al votante sin conexión.
--
--  Privacidad: el bundle NO lleva nombres ni cédulas en claro. El dispositivo
--  compara el hash de lo que digita el estudiante contra el verificador.
--
--    verificador = sha256( salt || ':' || tipo || ':' || secreto_normalizado )
--    salt        = institutions.id (viaja en el bundle como `verifier_salt`)
--    tipo        = 'cedula' | 'pin'
--
--  Registro de dispositivo: el dispositivo NO lee tablas; todo pasa por este RPC
--  SECURITY DEFINER que deriva el dispositivo de auth.uid().
-- =============================================================================

-- ----------------------------------------------------------------------------
--  PIN de votación por estudiante (hash; alimenta el verificador del padrón)
-- ----------------------------------------------------------------------------
alter table public.students
  add column if not exists access_pin_hash text;

comment on column public.students.access_pin_hash is
  'sha256(institution_id || '':pin:'' || pin); nunca se guarda el PIN en claro.';

-- ----------------------------------------------------------------------------
--  set_student_pin(p_student_id, p_pin)
--  p_pin nulo o vacío borra el PIN. Formato: 4 a 8 dígitos.
-- ----------------------------------------------------------------------------
create or replace function public.set_student_pin(
  p_student_id uuid,
  p_pin        text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_student public.students%rowtype;
  v_pin     text;
begin
  if not public.is_staff() then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  select * into v_student from public.students where id = p_student_id;
  if not found then
    raise exception 'student_not_found';
  end if;

  v_pin := nullif(btrim(coalesce(p_pin, '')), '');
  if v_pin is not null and v_pin !~ '^[0-9]{4,8}$' then
    raise exception 'invalid_pin';
  end if;

  update public.students
    set access_pin_hash = case
      when v_pin is null then null
      else encode(sha256(convert_to(
        v_student.institution_id::text || ':pin:' || v_pin, 'UTF8')), 'hex')
    end
    where id = p_student_id;

  perform public.log_audit(
    case when v_pin is null then 'student_pin_cleared' else 'student_pin_set' end,
    'student', p_student_id, '{}'::jsonb
  );

  return jsonb_build_object(
    'student_id', p_student_id,
    'has_pin', v_pin is not null
  );
end;
$$;

revoke all on function public.set_student_pin(uuid, text) from public;
grant execute on function public.set_student_pin(uuid, text) to authenticated;

-- ----------------------------------------------------------------------------
--  get_device_bundle()
--  Devuelve a la tablet: asignación vigente, configuración de la elección,
--  padrón de su mesa (o del padrón completo si la asignación no fija mesa) y los
--  verificadores para identificación offline. Sella `last_seen_at`.
-- ----------------------------------------------------------------------------
create or replace function public.get_device_bundle()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_device      public.voting_devices%rowtype;
  v_assignment  public.device_assignments%rowtype;
  v_election    public.elections%rowtype;
  v_institution public.institutions%rowtype;
  v_table       public.voting_tables%rowtype;
  v_salt        text;
  v_lists       jsonb;
  v_candidates  jsonb;
  v_config      jsonb;
  v_hash        text;
  v_voters      jsonb;
begin
  -- 1. Dispositivo autorizado (derivado de la sesión, no del cliente).
  select * into v_device
  from public.voting_devices
  where auth_user_id = auth.uid() and status = 'authorized';
  if not found then
    raise exception 'device_not_authorized' using errcode = '42501';
  end if;

  -- 2. Asignación vigente más reciente.
  select * into v_assignment
  from public.device_assignments
  where device_id = v_device.id and revoked_at is null
  order by authorized_at desc
  limit 1;
  if not found then
    raise exception 'device_not_assigned' using errcode = '42501';
  end if;

  select * into v_election from public.elections where id = v_assignment.election_id;
  if not found then
    raise exception 'election_not_found';
  end if;

  select * into v_institution from public.institutions where id = v_election.institution_id;
  v_salt := v_election.institution_id::text;

  if v_assignment.voting_table_id is not null then
    select * into v_table from public.voting_tables where id = v_assignment.voting_table_id;
  end if;

  -- 3. Oferta electoral habilitada.
  v_lists := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id, 'number', l.number, 'name', l.name,
      'slogan', l.slogan, 'emblem_path', l.emblem_path
    ) order by l.number)
    from public.candidate_lists l
    where l.election_id = v_election.id and l.enabled = true
  ), '[]'::jsonb);

  v_candidates := coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'list_id', c.list_id, 'full_name', c.full_name,
      'position', c.position, 'order_index', c.order_index, 'photo_path', c.photo_path
    ) order by c.order_index)
    from public.candidates c
    join public.candidate_lists l on l.id = c.list_id
    where l.election_id = v_election.id and l.enabled = true
  ), '[]'::jsonb);

  -- 4. Configuración + hash de integridad (mismo criterio que generate_election_config).
  v_config := jsonb_build_object(
    'election', jsonb_build_object(
      'id', v_election.id,
      'name', v_election.name,
      'description', v_election.description,
      'normativa', v_election.normativa,
      'status', v_election.status,
      'time_zone', v_election.time_zone,
      'opens_at', v_election.opens_at,
      'closes_at', v_election.closes_at,
      'config_version', v_election.config_version,
      'validity_norm', v_election.validity_norm
    ),
    'lists', v_lists,
    'candidates', v_candidates
  );
  v_hash := encode(sha256(convert_to(v_config::text, 'UTF8')), 'hex');

  -- 5. Padrón de la mesa asignada (o completo si no fija mesa): solo referencias
  --    opacas + verificadores; sin nombres ni cédulas en claro.
  v_voters := coalesce((
    select jsonb_agg(jsonb_build_object(
      'voter_ref', ev.voter_ref,
      'code', s.internal_code,
      'voting_table_id', ev.voting_table_id,
      'cedula_verifier', case
        when s.cedula is not null and length(btrim(s.cedula)) > 0
        then encode(sha256(convert_to(v_salt || ':cedula:' || btrim(s.cedula), 'UTF8')), 'hex')
        else null end,
      'pin_verifier', s.access_pin_hash
    ) order by s.internal_code)
    from public.election_voters ev
    join public.students s on s.id = ev.student_id
    where ev.election_id = v_election.id
      and ev.enabled = true
      and (v_assignment.voting_table_id is null or ev.voting_table_id = v_assignment.voting_table_id)
  ), '[]'::jsonb);

  update public.voting_devices set last_seen_at = now() where id = v_device.id;

  return jsonb_build_object(
    'device', jsonb_build_object(
      'device_id', v_device.id, 'device_uid', v_device.device_uid, 'label', v_device.label
    ),
    'institution', jsonb_build_object(
      'id', v_institution.id, 'name', v_institution.name, 'time_zone', v_institution.time_zone
    ),
    'assignment', jsonb_build_object(
      'election_id', v_assignment.election_id,
      'voting_table_id', v_assignment.voting_table_id,
      'config_version', v_assignment.config_version,
      'authorized_at', v_assignment.authorized_at
    ),
    'voting_table', case when v_table.id is null then null else jsonb_build_object(
      'id', v_table.id, 'code', v_table.code, 'name', v_table.name
    ) end,
    'verifier_salt', v_salt,
    'config', v_config,
    'config_version', v_election.config_version,
    'config_hash', v_hash,
    'voters', v_voters,
    'server_time', now()
  );
end;
$$;

revoke all on function public.get_device_bundle() from public;
grant execute on function public.get_device_bundle() to authenticated;
