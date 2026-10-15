-- =============================================================================
--  20261014000015 — Flujo de tutor: sincronización de ámbito y lectura acotada
-- -----------------------------------------------------------------------------
--  La administración asigna al tutor de un curso escribiendo
--  `courses.tutor_profile_id`. Las políticas RLS de tutor, en cambio, se apoyan
--  en `tutor_assignments` y en el rol `tutor`, así que hasta ahora el tutor no
--  veía nada. Esta migración:
--
--    1. Mantiene `tutor_assignments` en sincronía con `courses.tutor_profile_id`
--       (alta, cambio y baja) mediante un trigger.
--    2. Asegura que el perfil asignado tenga el rol `tutor`.
--    3. Expone `get_tutor_scope()`: un RPC SECURITY DEFINER que devuelve, ya
--       acotado por `auth.uid()`, los cursos del tutor y los estudiantes de esos
--       cursos (con elección y mesa). El tutor no puede leer `election_voters`
--       ni `elections` directamente, por eso el RPC.
-- =============================================================================

-- ----------------------------------------------------------------------------
--  Sincronía courses.tutor_profile_id → tutor_assignments + rol `tutor`
-- ----------------------------------------------------------------------------
create or replace function public.sync_course_tutor()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_course_id uuid;
  v_profile   uuid;
  v_inst      uuid;
begin
  v_course_id := coalesce(new.id, old.id);

  -- Reconstruye las asignaciones del curso: una sola, la del tutor vigente.
  delete from public.tutor_assignments where course_id = v_course_id;

  v_profile := case when tg_op = 'DELETE' then null else new.tutor_profile_id end;

  if v_profile is not null then
    insert into public.tutor_assignments(profile_id, course_id)
    values (v_profile, v_course_id)
    on conflict (profile_id, course_id) do nothing;

    -- Otorga el rol `tutor` una sola vez por perfil (sin duplicar por institución).
    select institution_id into v_inst
    from public.user_profiles
    where id = v_profile;

    insert into public.user_roles(profile_id, institution_id, role)
    select v_profile, v_inst, 'tutor'::public.user_role
    where not exists (
      select 1 from public.user_roles
      where profile_id = v_profile and role = 'tutor'
    );
  end if;

  return null; -- trigger AFTER
end;
$$;

drop trigger if exists trg_courses_sync_tutor on public.courses;
create trigger trg_courses_sync_tutor
  after insert or update of tutor_profile_id or delete on public.courses
  for each row execute function public.sync_course_tutor();

-- Backfill: refleja las asignaciones que ya existían en courses.tutor_profile_id.
insert into public.tutor_assignments(profile_id, course_id)
select c.tutor_profile_id, c.id
from public.courses c
where c.tutor_profile_id is not null
on conflict (profile_id, course_id) do nothing;

insert into public.user_roles(profile_id, institution_id, role)
select distinct c.tutor_profile_id, up.institution_id, 'tutor'::public.user_role
from public.courses c
join public.user_profiles up on up.id = c.tutor_profile_id
where c.tutor_profile_id is not null
  and not exists (
    select 1 from public.user_roles ur
    where ur.profile_id = c.tutor_profile_id and ur.role = 'tutor'
  );

-- ----------------------------------------------------------------------------
--  Lectura acotada del tutor (evita depender de RLS sobre election_voters)
-- ----------------------------------------------------------------------------
create or replace function public.get_tutor_scope()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_profile  uuid := auth.uid();
  v_courses  jsonb;
  v_students jsonb;
begin
  if v_profile is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  v_courses := coalesce((
    select jsonb_agg(jsonb_build_object(
      'course_id',        c.id,
      'display_name',     c.display_name,
      'grade',            c.grade,
      'parallel',         c.parallel,
      'academic_year_id', c.academic_year_id
    ) order by c.display_name)
    from public.courses c
    join public.tutor_assignments ta on ta.course_id = c.id
    where ta.profile_id = v_profile
  ), '[]'::jsonb);

  v_students := coalesce((
    select jsonb_agg(jsonb_build_object(
      'election_id',       ev.election_id,
      'election_name',     e.name,
      'course_id',         vt.course_id,
      'voting_table_code', vt.code,
      'internal_code',     s.internal_code,
      'first_name',        s.first_name,
      'last_name',         s.last_name,
      'cedula',            s.cedula,
      'status',            s.status,
      'enabled',           ev.enabled
    ) order by e.name, vt.code, s.last_name, s.first_name)
    from public.tutor_assignments ta
    join public.voting_tables vt on vt.course_id = ta.course_id
    join public.election_voters ev on ev.voting_table_id = vt.id
    join public.students s on s.id = ev.student_id
    join public.elections e on e.id = ev.election_id
    where ta.profile_id = v_profile
  ), '[]'::jsonb);

  return jsonb_build_object('courses', v_courses, 'students', v_students);
end;
$$;

revoke all on function public.get_tutor_scope() from public;
grant execute on function public.get_tutor_scope() to authenticated;
