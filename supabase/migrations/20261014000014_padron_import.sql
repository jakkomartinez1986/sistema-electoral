-- =============================================================================
--  20261014000014 — Importación del padrón (CSV/Excel → estudiantes + padrón)
-- -----------------------------------------------------------------------------
--  import_election_padron(p_election_id, p_rows)
--
--  Recibe filas ya normalizadas por el cliente y, en una sola transacción:
--    * crea o actualiza el estudiante (clave: institución + código interno);
--    * lo inscribe en el padrón de la elección (election_voters) y, si la fila
--      trae código de mesa, lo asigna a esa mesa;
--    * opcionalmente fija el PIN de votación (mismo hash que set_student_pin).
--
--  Cada fila se procesa en un bloque aislado: un error no aborta el resto y se
--  informa por fila. Solo el personal (admin/operator) puede importar, y solo
--  mientras la elección no esté abierta (padrón congelado al abrir).
--
--  Privacidad: nunca se registra la cédula ni el PIN en las auditorías.
-- =============================================================================

create or replace function public.import_election_padron(
  p_election_id uuid,
  p_rows        jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_election   public.elections%rowtype;
  v_row        jsonb;
  v_index      integer := 0;
  v_code       text;
  v_first      text;
  v_last       text;
  v_cedula     text;
  v_pin        text;
  v_birth      date;
  v_status     public.student_status;
  v_enabled    boolean;
  v_table_code text;
  v_table_id   uuid;
  v_student_id uuid;
  v_created    integer := 0;
  v_updated    integer := 0;
  v_assigned   integer := 0;
  v_err_count  integer := 0;
  v_errors     jsonb := '[]'::jsonb;
begin
  if not public.is_staff() then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'invalid_payload';
  end if;

  select * into v_election from public.elections where id = p_election_id;
  if not found then
    raise exception 'election_not_found';
  end if;

  if v_election.status not in ('draft', 'ready') then
    raise exception 'padron_locked';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows)
  loop
    v_index := v_index + 1;
    begin
      v_code       := btrim(coalesce(v_row->>'internal_code', ''));
      v_first      := btrim(coalesce(v_row->>'first_name', ''));
      v_last       := btrim(coalesce(v_row->>'last_name', ''));
      v_cedula     := nullif(btrim(coalesce(v_row->>'cedula', '')), '');
      v_pin        := nullif(btrim(coalesce(v_row->>'pin', '')), '');
      v_table_code := nullif(btrim(coalesce(v_row->>'table_code', '')), '');
      v_enabled    := coalesce((nullif(btrim(coalesce(v_row->>'enabled', '')), ''))::boolean, true);
      v_status     := coalesce(
                        nullif(btrim(coalesce(v_row->>'status', '')), '')::public.student_status,
                        'active'
                      );

      if v_code = '' then
        raise exception 'missing_code';
      end if;
      if v_first = '' or v_last = '' then
        raise exception 'missing_name';
      end if;
      if v_pin is not null and v_pin !~ '^[0-9]{4,8}$' then
        raise exception 'invalid_pin';
      end if;

      v_birth := null;
      if nullif(btrim(coalesce(v_row->>'birth_date', '')), '') is not null then
        v_birth := (v_row->>'birth_date')::date;
      end if;

      v_table_id := null;
      if v_table_code is not null then
        select id into v_table_id
        from public.voting_tables
        where election_id = p_election_id and code = v_table_code;
        if not found then
          raise exception 'table_not_found';
        end if;
      end if;

      select id into v_student_id
      from public.students
      where institution_id = v_election.institution_id and internal_code = v_code;

      if found then
        update public.students set
          first_name      = v_first,
          last_name       = v_last,
          cedula          = v_cedula,
          birth_date      = coalesce(v_birth, birth_date),
          status          = v_status,
          enabled         = v_enabled,
          access_pin_hash = case
            when v_pin is null then access_pin_hash
            else encode(sha256(convert_to(
              v_election.institution_id::text || ':pin:' || v_pin, 'UTF8')), 'hex')
          end
        where id = v_student_id;
        v_updated := v_updated + 1;
      else
        insert into public.students(
          institution_id, internal_code, cedula, first_name, last_name,
          birth_date, status, enabled, access_pin_hash
        ) values (
          v_election.institution_id, v_code, v_cedula, v_first, v_last,
          v_birth, v_status, v_enabled,
          case when v_pin is null then null
            else encode(sha256(convert_to(
              v_election.institution_id::text || ':pin:' || v_pin, 'UTF8')), 'hex')
          end
        )
        returning id into v_student_id;
        v_created := v_created + 1;
      end if;

      insert into public.election_voters(
        election_id, student_id, voting_table_id, enabled
      ) values (
        p_election_id, v_student_id, v_table_id, v_enabled
      )
      on conflict (election_id, student_id) do update
        set voting_table_id = excluded.voting_table_id,
            enabled         = excluded.enabled;
      v_assigned := v_assigned + 1;
    exception when others then
      v_err_count := v_err_count + 1;
      v_errors := v_errors || jsonb_build_object('row', v_index, 'message', sqlerrm);
    end;
  end loop;

  perform public.log_audit(
    'padron_imported', 'election', p_election_id,
    jsonb_build_object(
      'created', v_created, 'updated', v_updated,
      'assigned', v_assigned, 'errors', v_err_count
    )
  );

  return jsonb_build_object(
    'total', v_index,
    'created', v_created,
    'updated', v_updated,
    'assigned', v_assigned,
    'error_count', v_err_count,
    'errors', v_errors
  );
end;
$$;

revoke all on function public.import_election_padron(uuid, jsonb) from public;
grant execute on function public.import_election_padron(uuid, jsonb) to authenticated;
