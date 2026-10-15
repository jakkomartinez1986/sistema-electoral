-- =============================================================================
--  20261013000002 — Personas y organización: cursos, estudiantes, tutores
-- =============================================================================

create type public.student_status as enum ('active', 'inactive', 'graduated');

-- ----------------------------------------------------------------------------
--  courses  (grados/cursos y paralelos por año lectivo)
-- ----------------------------------------------------------------------------
create table public.courses (
  id                uuid primary key default gen_random_uuid(),
  academic_year_id  uuid not null references public.academic_years(id) on delete restrict,
  grade             text not null,      -- p. ej. "1", "10", "3ro BGU"
  parallel          text not null,      -- p. ej. "A"
  display_name      text not null,      -- p. ej. "10mo A"
  tutor_profile_id  uuid references public.user_profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint courses_unique unique (academic_year_id, grade, parallel),
  constraint courses_display_not_blank check (length(btrim(display_name)) > 0)
);

create index idx_courses_academic_year on public.courses(academic_year_id);
create index idx_courses_tutor on public.courses(tutor_profile_id);

create trigger trg_courses_updated_at
  before update on public.courses
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  students  (datos personales MÍNIMOS; identificadores internos estables)
-- ----------------------------------------------------------------------------
create table public.students (
  id              uuid primary key default gen_random_uuid(),
  institution_id  uuid not null references public.institutions(id) on delete restrict,
  internal_code   text not null,                 -- identificador estable del colegio
  cedula          text,                          -- opcional
  first_name      text not null,
  last_name       text not null,
  birth_date      date,
  status          public.student_status not null default 'active',
  enabled         boolean not null default true, -- habilitación electoral
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint students_code_not_blank check (length(btrim(internal_code)) > 0),
  constraint students_unique_code unique (institution_id, internal_code)
);

-- La cédula es única por institución solo cuando está presente.
create unique index students_unique_cedula
  on public.students(institution_id, cedula)
  where cedula is not null;

create index idx_students_institution on public.students(institution_id);
create index idx_students_name on public.students(last_name, first_name);

create trigger trg_students_updated_at
  before update on public.students
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
--  tutor_assignments  (limited scope for tutors: only their courses)
-- ----------------------------------------------------------------------------
create table public.tutor_assignments (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.user_profiles(id) on delete cascade,
  course_id   uuid not null references public.courses(id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint tutor_assignments_unique unique (profile_id, course_id)
);

create index idx_tutor_assignments_profile on public.tutor_assignments(profile_id);
create index idx_tutor_assignments_course on public.tutor_assignments(course_id);
