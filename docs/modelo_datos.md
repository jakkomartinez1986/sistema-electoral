# Modelo de datos

Diseño relacional para PostgreSQL (Supabase). Todas las tablas incluyen
`id uuid default gen_random_uuid() primary key`, `created_at timestamptz` y
`updated_at timestamptz` (salvo las de ledger, donde la semántica es distinta).
Las claves foráneas tienen política `ON DELETE` explícita y hay índices sobre
las columnas de consulta frecuente.

## 1. Inventario de tablas

### Catálogo e institución

| Tabla | Propósito | Notas |
|---|---|---|
| `institutions` | Institución: nombre, zona horaria, logotipo | `time_zone` por defecto `America/Guayaquil` |
| `academic_years` | Año lectivo / período | `institution_id`, `name` (p. ej. "2025-2026"), `starts_on`, `ends_on` |
| `user_profiles` | Perfil del personal, ligado a `auth.users` | `id = auth.uid()`; datos mínimos |
| `user_roles` | Rol por usuario y ámbito | `role ∈ {admin, operator, tutor}`; `scope` opcional (curso/mesa) |

### Padrón y organización

| Tabla | Propósito | Notas |
|---|---|---|
| `courses` | Grados/cursos y paralelos | `academic_year_id`, `grade`, `parallel`, `tutor_profile_id` |
| `students` | Estudiante (datos mínimos) | `internal_code` único, `cedula` (opcional, única si presente), `access_pin_hash` (hash del PIN de votación; nunca en claro), nombres |
| `voting_tables` | Mesas/grupos de votación | `election_id`, `course_id`, capacidad, `code` |
| `election_voters` | Padrón **por elección** | `election_id`, `student_id`, `voting_table_id`, `voter_ref` (UUID opaco), `enabled` |

`election_voters.voter_ref` es el identificador que viaja a la tablet y que la
papeleta/participación referencian; no es el identificador personal del
estudiante ni se usa para exponerlo.

La verificación **offline** del votante usa un esquema de hash con sal: en el
bundle viajan `cedula_verifier`/`pin_verifier` =
`sha256(institution_id || ':' || kind || ':' || secreto)`, con `kind ∈ {cedula,
pin}`. La cédula se normaliza a solo dígitos y el PIN (guardado como
`students.access_pin_hash`) se fija con `set_student_pin`. El dispositivo solo
compara hashes; nunca recibe datos personales en claro.

### Oferta electoral

| Tabla | Propósito | Notas |
|---|---|---|
| `candidate_lists` | Listas (cantidad variable) | `election_id`, `number`, `name`, `slogan`, `emblem_path`, `enabled` |
| `candidates` | Candidatos | `list_id`, `full_name`, `position`, `order_index` |
| `candidate_list_members` | Integrantes/roles de apoyo | `list_id`, `profile_id`/`student_id`, `role` |

### Dispositivos

| Tabla | Propósito | Notas |
|---|---|---|
| `voting_devices` | Dispositivo autorizado | `device_uid` (hardware), `label`, `status ∈ {pending, authorized, revoked}`, `app_version` |
| `device_assignments` | Asignación dispositivo ↔ elección ↔ mesa | `device_id`, `election_id`, `voting_table_id`, `config_version` |
| `election_configs` | Configuración descargable y su versión | `election_id`, `config_version`, `payload jsonb`, `generated_at`, `hash` |

### Operación electoral (núcleo)

| Tabla | Propósito | Contiene identidad |
|---|---|---|
| `participation_records` | Marca que un votante participó | **Sí** (por `election_voter_id`) |
| `ballots` | Opción depositada | **No** |
| `sync_operations` | Ledger de idempotencia | No (solo operación/dispositivo) |
| `electoral_incidents` | Incidencias y conflictos | Referidas a participación, no al contenido del voto |
| `audit_logs` | Auditoría administrativa | **Nunca** votos |

### Vistas

- `election_results` (vista/materializada): agregados por lista, blancos y
  nulos. Solo accesible a roles autorizados y solo cuando la elección está
  `closed`.

## 2. Separación del voto secreto (regla dura)

El requisito central es **no poder reconstruir qué estudiante eligió qué lista**.

### 2.1 `participation_records` (identidad)

```
participation_records(
  id                 uuid pk,
  election_id        uuid not null references elections(id),
  election_voter_id  uuid not null references election_voters(id),
  voting_table_id    uuid not null references voting_tables(id),
  device_id          uuid references voting_devices(id),
  cast_at            timestamptz not null default now(),
  unique (election_id, election_voter_id)          -- anti-doble-voto
)
```

### 2.2 `ballots` (sin identidad)

```
ballots(
  id                 uuid pk default gen_random_uuid(),   -- aleatorio, no derivado
  election_id        uuid not null references elections(id),
  voting_table_id    uuid references voting_tables(id),
  device_id          uuid references voting_devices(id),  -- solo conciliación
  option_type        text not null check (option_type in ('list','blank','null')),
  candidate_list_id  uuid references candidate_lists(id),
  cast_bucket        timestamptz not null,                -- marca de tiempo gruesa
  -- una lista debe pertenecer a la misma elección (trigger/validación)
  check (
    (option_type = 'list' and candidate_list_id is not null) or
    (option_type in ('blank','null') and candidate_list_id is null)
  )
)
```

### 2.3 Reglas de no-correlación

1. **Sin clave compartida**: `ballots` no referencia `participation_records` ni
   `election_voters` ni `students`. No existe columna común que los una.
2. **Idempotencia separada**: `sync_operations(operation_id pk, device_id,
   election_id, status)` **no** guarda `ballot_id` ni `participation_id`. La
   operación se consulta por su UUID; el servidor responde su estado sin
   reconstruir el vínculo.
3. **Atomicidad por transacción**, no por FK: el RPC `cast_ballot` inserta
   ambas filas en una sola transacción. Si la participación choca con el
   `unique`, toda la transacción falla de forma controlada.
4. **`audit_logs` no registra votos** ni el contenido de ninguna papeleta.
5. **`cast_bucket`** reduce la precisión temporal (p. ej. minuto) para dificultar
   la correlación por orden/instante de sincronización.
6. **Permisos separados** de lectura entre ambas tablas (ver `docs/seguridad.md`).

### 2.4 `cast_ballot` (pseudocódigo transaccional)

```
cast_ballot(operation_id, election_id, voting_device_id, voting_table_id,
            voter_ref, option_type, candidate_list_id, ballot_id)
  SECURITY DEFINER, search_path = public, pg_temp
  1. Validar que el dispositivo está autorizado y asignado a esta elección/mesa.
  2. Validar que la elección está `open` y el reloj del servidor está en rango.
  3. Validar que `candidate_list_id` (si aplica) pertenece a esta elección
     y está habilitada.
  4. Idempotencia: INSERT INTO sync_operations(operation_id,...) ON CONFLICT DO NOTHING.
     Si ya existía y su estado es `accepted` → devolver `accepted` sin reinsertar.
  5. INSERT INTO participation_records(election_id, election_voter_id, ...)
     -- el unique(election_id, election_voter_id) aborta si ya participó.
  6. INSERT INTO ballots(ballot_id, election_id, option_type, candidate_list_id, ...)
     -- ballot_id aleatorio, sin vínculo con participación.
  7. Marcar sync_operations.status = 'accepted' y devolver el estado.
  Ante conflicto de participación: status = 'rejected'/'conflict' controlado.
```

El cliente **nunca** escribe estas tablas directamente: solo puede ejecutar el
RPC, y solo con las credenciales de dispositivo.

## 3. Idempotencia y recuperación de red

- Cada operación de sincronización lleva un `operation_id` UUID aleatorio con
  restricción de unicidad en `sync_operations`.
- Enviar el mismo UUID dos veces **no** duplica la participación ni la papeleta.
- Si se pierde la respuesta de red, el dispositivo **consulta el estado** de la
  operación por su UUID antes de reenviarla. Un timeout no se interpreta como
  fallo.

## 4. Aceptación exclusiva de opciones

La base de datos exige, del lado servidor:

- `option_type = 'list'` ⇒ `candidate_list_id` no nulo y perteneciente a la
  elección y habilitada.
- `option_type in ('blank','null')` ⇒ `candidate_list_id` nulo.

No se confía en la validación de la interfaz. Una lista de otra elección, o
deshabilitada, es rechazada por el servidor.

## 5. Límites de privacidad documentados

- La separación impide la asociación **directa** identidad ↔ papeleta, pero con
  acceso total a la base y a los metadatos de sincronización todavía puede
  inferirse una correlación por **tiempo, orden de llegada o dispositivo**. Es
  una limitación inherente al modelo y se mitiga con `cast_bucket`, sincronización
  por lotes y minimización de metadatos; no se elimina por completo.
- **Modo offline**: varios dispositivos desconectados no pueden garantizar por sí
  solos un único voto por estudiante si sus padrones se superponen. Ver
  `docs/sincronizacion_offline.md`.
- Estos límites se comunican explícitamente; no se simula una garantía que no
  existe.

## 6. Políticas de borrado

- `ON DELETE RESTRICT` para jerarquías electorales (no borrar una elección con
  historial sin un procedimiento explícito).
- `ON DELETE CASCADE` solo en relaciones de composición segura (p. ej.
  `candidates` al borrar una `candidate_list` **en estado `draft`**).
- Nunca se vacía la base al iniciar un año lectivo; el archivo anual conserva el
  historial (ver `docs/decisiones_tecnicas.md`).
