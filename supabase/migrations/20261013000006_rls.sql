-- =============================================================================
--  20261013000006 — Row Level Security (denegar por defecto) y roles
-- -----------------------------------------------------------------------------
--  * Se activa RLS en TODAS las tablas de public.
--  * Sin política ⇒ sin acceso.
--  * anon no tiene ningún privilegio.
--  * Las tablas del núcleo operativo solo se escriben vía RPC (ver migración 7);
--    desde el cliente solo se permite SELECT según rol.
-- =============================================================================

-- ----------------------------------------------------------------------------
--  Mapeo dispositivo ↔ usuario de Auth (creado por la Edge Function de enrolamiento)
-- ----------------------------------------------------------------------------
alter table public.voting_devices
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

-- ----------------------------------------------------------------------------
--  Funciones de autorización
-- ----------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = public, pg_temp
as $$ select public.has_role('admin'); $$;

create or replace function public.is_staff()
returns boolean language sql stable security definer
set search_path = public, pg_temp
as $$ select public.has_role('admin') or public.has_role('operator'); $$;

-- Institución del usuario autenticado.
create or replace function public.current_institution_id()
returns uuid language sql stable security definer
set search_path = public, pg_temp
as $$ select institution_id from public.user_profiles where id = auth.uid(); $$;

revoke all on function public.is_admin() from public;
revoke all on function public.is_staff() from public;
revoke all on function public.current_institution_id() from public;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_staff() to authenticated;
grant execute on function public.current_institution_id() to authenticated;

-- ----------------------------------------------------------------------------
--  Activar RLS
-- ----------------------------------------------------------------------------
alter table public.institutions            enable row level security;
alter table public.academic_years          enable row level security;
alter table public.user_profiles           enable row level security;
alter table public.user_roles              enable row level security;
alter table public.courses                 enable row level security;
alter table public.students                enable row level security;
alter table public.tutor_assignments       enable row level security;
alter table public.elections               enable row level security;
alter table public.voting_tables           enable row level security;
alter table public.candidate_lists         enable row level security;
alter table public.candidates              enable row level security;
alter table public.candidate_list_members  enable row level security;
alter table public.election_voters         enable row level security;
alter table public.election_configs        enable row level security;
alter table public.voting_devices          enable row level security;
alter table public.device_assignments      enable row level security;
alter table public.device_enrollment_codes enable row level security;
alter table public.participation_records   enable row level security;
alter table public.ballots                 enable row level security;
alter table public.sync_operations         enable row level security;
alter table public.electoral_incidents     enable row level security;
alter table public.audit_logs              enable row level security;

-- ----------------------------------------------------------------------------
--  Revocar privilegios innecesarios
-- ----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon;

-- El núcleo operativo no se escribe desde el cliente (solo vía RPC).
revoke insert, update, delete on public.ballots               from authenticated;
revoke insert, update, delete on public.participation_records from authenticated;
revoke insert, update, delete on public.sync_operations       from authenticated;
revoke insert, update, delete on public.audit_logs            from authenticated;

-- ----------------------------------------------------------------------------
--  Administradores: control total sobre las tablas de gestión
-- ----------------------------------------------------------------------------
create policy admin_all_institutions on public.institutions
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_academic_years on public.academic_years
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_user_roles on public.user_roles
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_courses on public.courses
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_students on public.students
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_elections on public.elections
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_voting_tables on public.voting_tables
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_candidate_lists on public.candidate_lists
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_candidates on public.candidates
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_list_members on public.candidate_list_members
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_election_voters on public.election_voters
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_election_configs on public.election_configs
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_devices on public.voting_devices
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_assignments on public.device_assignments
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_enrollment_codes on public.device_enrollment_codes
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_tutor_assignments on public.tutor_assignments
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_incidents on public.electoral_incidents
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Datos de conciliación: solo administradores pueden leerlos (agregado o no).
create policy admin_select_participation on public.participation_records
  for select to authenticated using (public.is_admin());
create policy admin_select_ballots on public.ballots
  for select to authenticated using (public.is_admin());
create policy admin_select_sync_operations on public.sync_operations
  for select to authenticated using (public.is_admin());
create policy admin_select_audit_logs on public.audit_logs
  for select to authenticated using (public.is_admin());

-- ----------------------------------------------------------------------------
--  Operadores electorales: gestión operativa, sin publicar resultados
-- ----------------------------------------------------------------------------
create policy staff_select_institutions on public.institutions
  for select to authenticated using (public.is_staff());
create policy staff_select_academic_years on public.academic_years
  for select to authenticated using (public.is_staff());
create policy staff_write_courses on public.courses
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_students on public.students
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_election_voters on public.election_voters
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_candidate_lists on public.candidate_lists
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_candidates on public.candidates
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_list_members on public.candidate_list_members
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_voting_tables on public.voting_tables
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_read_elections on public.elections
  for select to authenticated using (public.is_staff());
create policy staff_read_configs on public.election_configs
  for select to authenticated using (public.is_staff());
create policy staff_write_devices on public.voting_devices
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_write_assignments on public.device_assignments
  for all to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_read_tutor_assignments on public.tutor_assignments
  for select to authenticated using (public.is_staff());
create policy staff_read_incidents on public.electoral_incidents
  for select to authenticated using (public.is_staff());
create policy staff_write_incidents on public.electoral_incidents
  for update to authenticated using (public.is_staff()) with check (public.is_staff());
create policy staff_read_sync_operations on public.sync_operations
  for select to authenticated using (public.is_staff());

-- ----------------------------------------------------------------------------
--  Perfil propio
-- ----------------------------------------------------------------------------
create policy own_profile_select on public.user_profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());
create policy own_profile_update on public.user_profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy own_roles_select on public.user_roles
  for select to authenticated using (profile_id = auth.uid() or public.is_admin());

-- ----------------------------------------------------------------------------
--  Tutores: solo sus cursos (y los estudiantes de esos cursos vía padrón)
-- ----------------------------------------------------------------------------
create policy tutor_select_courses on public.courses
  for select to authenticated using (
    public.is_staff()
    or (public.has_role('tutor') and exists (
      select 1 from public.tutor_assignments ta
      where ta.course_id = courses.id and ta.profile_id = auth.uid()
    ))
  );

create policy tutor_select_students on public.students
  for select to authenticated using (
    public.is_staff()
    or (public.has_role('tutor') and exists (
      select 1
      from public.election_voters ev
      join public.voting_tables vt on vt.id = ev.voting_table_id
      join public.tutor_assignments ta on ta.course_id = vt.course_id
      where ev.student_id = students.id and ta.profile_id = auth.uid()
    ))
  );

create policy tutor_select_voting_tables on public.voting_tables
  for select to authenticated using (
    public.is_staff()
    or (public.has_role('tutor') and exists (
      select 1 from public.tutor_assignments ta
      where ta.course_id = voting_tables.course_id and ta.profile_id = auth.uid()
    ))
  );
