-- =============================================================================
--  seed.sql — datos de demostración FICTICIOS
-- -----------------------------------------------------------------------------
--  Este archivo se carga con `supabase db reset` (requiere Docker) o se aplica
--  manualmente contra el proyecto remoto de PRUEBAS. En este proyecto NO usamos
--  el stack local con Docker (ver D11 en docs/decisiones_tecnicas.md).
--
--  REGLAS:
--   * NUNCA incluir datos personales reales.
--   * NUNCA borrar datos reales automáticamente.
--   * Los datos de demostración se marcan con un prefijo reconocible ("DEMO").
--
--  Es idempotente: usa UUID fijos y `on conflict do nothing`, de modo que puede
--  aplicarse varias veces sin duplicar filas.
--
--  Nota: no se crean usuarios de Auth ni perfiles de personal aquí (auth.users
--  se gestiona con la Auth Admin API / panel). Ver docs/instalacion.md §6.
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
--  Institución y año lectivo de demostración
-- ----------------------------------------------------------------------------
insert into public.institutions (id, name, time_zone)
values (
  '00000000-0000-0000-0000-000000000001',
  'DEMO Unidad Educativa de Pruebas',
  'America/Guayaquil'
)
on conflict (id) do nothing;

insert into public.academic_years (id, institution_id, name, starts_on, ends_on)
values (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'DEMO 2025-2026',
  '2025-05-01',
  '2026-02-28'
)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
--  Cursos
-- ----------------------------------------------------------------------------
insert into public.courses (id, academic_year_id, grade, parallel, display_name)
values
  ('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000002', '10', 'A', 'DEMO 10mo A'),
  ('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000002', '10', 'B', 'DEMO 10mo B'),
  ('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-000000000002', '1', 'A', 'DEMO 1ro BGU A')
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
--  Estudiantes (datos inventados; cédula opcional)
-- ----------------------------------------------------------------------------
insert into public.students (id, institution_id, internal_code, cedula, first_name, last_name, status, enabled)
values
  ('00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000001', 'DEMO-001', '1710034065', 'Ana',     'Demo Uno',   'active', true),
  ('00000000-0000-0000-0000-000000000602', '00000000-0000-0000-0000-000000000001', 'DEMO-002', null,         'Luis',    'Demo Dos',   'active', true),
  ('00000000-0000-0000-0000-000000000603', '00000000-0000-0000-0000-000000000001', 'DEMO-003', null,         'María',   'Demo Tres',  'active', true),
  ('00000000-0000-0000-0000-000000000604', '00000000-0000-0000-0000-000000000001', 'DEMO-004', null,         'Carlos',  'Demo Cuatro','active', true),
  ('00000000-0000-0000-0000-000000000605', '00000000-0000-0000-0000-000000000001', 'DEMO-005', null,         'Sofía',   'Demo Cinco', 'active', true),
  ('00000000-0000-0000-0000-000000000606', '00000000-0000-0000-0000-000000000001', 'DEMO-006', null,         'Diego',   'Demo Seis',  'active', true),
  ('00000000-0000-0000-0000-000000000607', '00000000-0000-0000-0000-000000000001', 'DEMO-007', null,         'Elena',   'Demo Siete', 'active', true),
  ('00000000-0000-0000-0000-000000000608', '00000000-0000-0000-0000-000000000001', 'DEMO-008', null,         'Pablo',   'Demo Ocho',  'active', true),
  ('00000000-0000-0000-0000-000000000609', '00000000-0000-0000-0000-000000000001', 'DEMO-009', null,         'Rosa',    'Demo Nueve', 'active', true)
on conflict (id) do nothing;

-- PIN de votación de demostración (1234) para todos los estudiantes DEMO.
-- Es idempotente y no afecta a datos que no sean de demostración.
update public.students
  set access_pin_hash = encode(sha256(convert_to(
        institution_id::text || ':pin:1234', 'UTF8')), 'hex')
  where internal_code like 'DEMO-%';

-- ----------------------------------------------------------------------------
--  Elección (borrador) y mesas
-- ----------------------------------------------------------------------------
insert into public.elections (id, institution_id, academic_year_id, name, description, status)
values (
  '00000000-0000-0000-0000-000000000200',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  'DEMO Elección del Consejo Estudiantil 2025',
  'Datos ficticios para pruebas del sistema.',
  'draft'
)
on conflict (id) do nothing;

insert into public.voting_tables (id, election_id, course_id, code, name, capacity)
values
  ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000101', 'DEMO-T1', 'DEMO Mesa 10mo A', 30),
  ('00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000102', 'DEMO-T2', 'DEMO Mesa 10mo B', 30),
  ('00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000103', 'DEMO-T3', 'DEMO Mesa 1ro BGU A', 30)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
--  Listas y candidatos
-- ----------------------------------------------------------------------------
insert into public.candidate_lists (id, election_id, number, name, slogan)
values
  ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000200', 1, 'DEMO Lista 1', 'Compromiso y transparencia'),
  ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000200', 2, 'DEMO Lista 2', 'Todos por la institución'),
  ('00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000200', 3, 'DEMO Lista 3', 'Nuevas ideas')
on conflict (id) do nothing;

insert into public.candidates (id, list_id, full_name, position, order_index)
values
  ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000401', 'DEMO Candidato A1', 'Presidente', 0),
  ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000401', 'DEMO Candidato A2', 'Vicepresidente', 1),
  ('00000000-0000-0000-0000-000000000503', '00000000-0000-0000-0000-000000000402', 'DEMO Candidato B1', 'Presidente', 0),
  ('00000000-0000-0000-0000-000000000504', '00000000-0000-0000-0000-000000000402', 'DEMO Candidato B2', 'Vicepresidente', 1),
  ('00000000-0000-0000-0000-000000000505', '00000000-0000-0000-0000-000000000403', 'DEMO Candidato C1', 'Presidente', 0),
  ('00000000-0000-0000-0000-000000000506', '00000000-0000-0000-0000-000000000403', 'DEMO Candidato C2', 'Vicepresidente', 1)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
--  Padrón (todos los estudiantes habilitados), asignados a mesas
-- ----------------------------------------------------------------------------
insert into public.election_voters (id, election_id, student_id, voting_table_id, voter_ref, enabled)
values
  ('00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-0000000007a1', true),
  ('00000000-0000-0000-0000-000000000702', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000602', '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-0000000007a2', true),
  ('00000000-0000-0000-0000-000000000703', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000603', '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-0000000007a3', true),
  ('00000000-0000-0000-0000-000000000704', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000604', '00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-0000000007a4', true),
  ('00000000-0000-0000-0000-000000000705', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000605', '00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-0000000007a5', true),
  ('00000000-0000-0000-0000-000000000706', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000606', '00000000-0000-0000-0000-000000000302', '00000000-0000-0000-0000-0000000007a6', true),
  ('00000000-0000-0000-0000-000000000707', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000607', '00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-0000000007a7', true),
  ('00000000-0000-0000-0000-000000000708', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000608', '00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-0000000007a8', true),
  ('00000000-0000-0000-0000-000000000709', '00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000609', '00000000-0000-0000-0000-000000000303', '00000000-0000-0000-0000-0000000007a9', true)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
--  Dispositivos de votación (pendientes de enrolamiento)
-- ----------------------------------------------------------------------------
insert into public.voting_devices (id, institution_id, device_uid, label, status)
values
  ('00000000-0000-0000-0000-000000000801', '00000000-0000-0000-0000-000000000001', 'DEMO-DEVICE-001', 'DEMO Tablet 1', 'pending'),
  ('00000000-0000-0000-0000-000000000802', '00000000-0000-0000-0000-000000000001', 'DEMO-DEVICE-002', 'DEMO Tablet 2', 'pending')
on conflict (id) do nothing;

commit;
