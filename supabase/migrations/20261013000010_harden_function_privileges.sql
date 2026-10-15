-- =============================================================================
--  20261013000010 — Endurecimiento de privilegios de funciones
-- -----------------------------------------------------------------------------
--  Supabase concede EXECUTE a anon/authenticated por defecto en cada función
--  nueva del esquema public; "revoke ... from public" NO elimina ese grant
--  explícito a anon. Se elimina el acceso de anon/PUBLIC a toda función y se
--  corrige el default para funciones futuras. authenticated conserva solo las
--  funciones concedidas explícitamente por las migraciones 1, 6, 7, 8 y 9.
-- =============================================================================

-- search_path fijo en las funciones que aún no lo tenían.
alter function public.set_updated_at() set search_path = public, pg_temp;
alter function public.is_valid_transition(public.election_status, public.election_status)
  set search_path = public, pg_temp;

-- Quitar EXECUTE a anon y a PUBLIC de TODAS las funciones del esquema public.
revoke all on all functions in schema public from anon;
revoke all on all functions in schema public from public;

-- log_audit no forma parte del contrato público (se usa internamente como
-- SECURITY DEFINER); se retira de authenticated para evitar entradas forjadas.
revoke all on function public.log_audit(text, text, uuid, jsonb) from authenticated;

-- Futuras funciones/tablas/secuencias del esquema public no se conceden a anon
-- ni a PUBLIC automáticamente.
alter default privileges in schema public revoke execute on functions from anon;
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on tables from public;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on sequences from public;
