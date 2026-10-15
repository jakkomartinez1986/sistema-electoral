-- =============================================================================
--  20261013000011 — Endurecimiento de rendimiento
-- -----------------------------------------------------------------------------
--  1) Índices de cobertura para claves foráneas (advisor unindexed_foreign_keys).
--  2) Políticas RLS que reevalúan auth.uid() por fila → envolver en
--     (select auth.uid()) (advisor auth_rls_initplan).
--  No cambia la semántica de acceso; solo el plan de ejecución.
-- =============================================================================

-- 1) Índices de claves foráneas -------------------------------------------------
create index if not exists idx_ballots_device          on public.ballots(device_id);
create index if not exists idx_ballots_election_list   on public.ballots(election_id, candidate_list_id);
create index if not exists idx_list_members_student    on public.candidate_list_members(student_id);
create index if not exists idx_assignments_table       on public.device_assignments(voting_table_id);
create index if not exists idx_enrollment_codes_author on public.device_enrollment_codes(created_by);
create index if not exists idx_incidents_device        on public.electoral_incidents(device_id);
create index if not exists idx_incidents_operation     on public.electoral_incidents(operation_id);
create index if not exists idx_incidents_resolved_by   on public.electoral_incidents(resolved_by);
create index if not exists idx_participation_device    on public.participation_records(device_id);
create index if not exists idx_voting_devices_auth     on public.voting_devices(auth_user_id);

-- 2) RLS: inicializar auth.uid() una sola vez por consulta ----------------------
drop policy own_profile_select on public.user_profiles;
create policy own_profile_select on public.user_profiles
  for select to authenticated
  using (id = (select auth.uid()) or public.is_admin());

drop policy own_profile_update on public.user_profiles;
create policy own_profile_update on public.user_profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

drop policy own_roles_select on public.user_roles;
create policy own_roles_select on public.user_roles
  for select to authenticated
  using (profile_id = (select auth.uid()) or public.is_admin());

drop policy tutor_select_courses on public.courses;
create policy tutor_select_courses on public.courses
  for select to authenticated using (
    public.is_staff()
    or (public.has_role('tutor') and exists (
      select 1 from public.tutor_assignments ta
      where ta.course_id = courses.id and ta.profile_id = (select auth.uid())
    ))
  );

drop policy tutor_select_students on public.students;
create policy tutor_select_students on public.students
  for select to authenticated using (
    public.is_staff()
    or (public.has_role('tutor') and exists (
      select 1
      from public.election_voters ev
      join public.voting_tables vt on vt.id = ev.voting_table_id
      join public.tutor_assignments ta on ta.course_id = vt.course_id
      where ev.student_id = students.id and ta.profile_id = (select auth.uid())
    ))
  );

drop policy tutor_select_voting_tables on public.voting_tables;
create policy tutor_select_voting_tables on public.voting_tables
  for select to authenticated using (
    public.is_staff()
    or (public.has_role('tutor') and exists (
      select 1 from public.tutor_assignments ta
      where ta.course_id = voting_tables.course_id and ta.profile_id = (select auth.uid())
    ))
  );
