-- =============================================================================
--  20261013000009 — Códigos de emparejamiento de dispositivos
-- -----------------------------------------------------------------------------
--  El administrador genera un código de un solo uso; se guarda su HASH y se
--  devuelve el texto UNA sola vez. La Edge Function 'enroll-device' lo canjea y
--  entrega credenciales propias al dispositivo.
-- =============================================================================

create or replace function public.create_enrollment_code(
  p_device_id   uuid,
  p_ttl_minutes integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_code text;
  v_id   uuid;
begin
  if not public.is_admin() then
    raise exception 'not_allowed' using errcode = '42501';
  end if;

  if not exists (select 1 from public.voting_devices where id = p_device_id) then
    raise exception 'device_not_found';
  end if;

  -- Código aleatorio legible (12 caracteres hexadecimales en mayúsculas).
  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));

  insert into public.device_enrollment_codes(device_id, code_hash, expires_at, created_by)
  values (
    p_device_id,
    encode(sha256(convert_to(v_code, 'UTF8')), 'hex'),
    now() + make_interval(mins => greatest(p_ttl_minutes, 1)),
    auth.uid()
  )
  returning id into v_id;

  perform public.log_audit(
    'enrollment_code_created', 'voting_device', p_device_id,
    jsonb_build_object('code_id', v_id, 'ttl_minutes', p_ttl_minutes)
  );

  -- El texto del código se devuelve UNA vez; no se almacena en claro.
  return jsonb_build_object('code_id', v_id, 'code', v_code,
                            'expires_in_minutes', p_ttl_minutes);
end;
$$;

revoke all on function public.create_enrollment_code(uuid, integer) from public;
grant execute on function public.create_enrollment_code(uuid, integer) to authenticated;
