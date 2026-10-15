# Contrato del backend (Supabase)

Resumen de migraciones, funciones expuestas y Edge Functions. Toda operación
privilegiada vive en el servidor; el cliente Flutter solo llama a RPC y lee lo
que RLS permite.

## 1. Migraciones

| Archivo | Contenido |
|---|---|
| `20261013000001_enums_and_core.sql` | Enums, `set_updated_at`, `institutions`, `academic_years`, `user_profiles`, `user_roles`, `has_role` |
| `20261013000002_people_and_org.sql` | `student_status`, `courses`, `students`, `tutor_assignments` |
| `20261013000003_elections_catalog.sql` | `elections`, `voting_tables`, `candidate_lists`, `candidates`, `candidate_list_members`, `election_voters`, `election_configs` |
| `20261013000004_devices.sql` | `voting_devices`, `device_assignments`, `device_enrollment_codes` |
| `20261013000005_operational_core.sql` | `participation_records`, `ballots`, `sync_operations`, `electoral_incidents`, `audit_logs`, vista `election_results` |
| `20261013000006_rls.sql` | RLS deny-by-default, políticas por rol, `auth_user_id`, `is_admin`/`is_staff` |
| `20261013000007_rpc.sql` | `cast_ballot`, `get_operation_status` |
| `20261013000008_state_and_config.sql` | `log_audit`, `is_valid_transition`, `transition_election`, `generate_election_config` |
| `20261013000009_enrollment_codes.sql` | `create_enrollment_code` |
| `20261013000010_harden_function_privileges.sql` | Endurecimiento: revoca `EXECUTE` de `anon`/`PUBLIC` en todas las funciones, fija `search_path` pendiente, retira `log_audit` de `authenticated` y corrige los privilegios por defecto |
| `20261013000011_performance_hardening.sql` | Índices de cobertura para claves foráneas y RLS con `(select auth.uid())` |
| `20261013000012_device_bundle.sql` | `students.access_pin_hash`, `set_student_pin`, `get_device_bundle` (config + padrón con verificadores de cédula/PIN) |
| `20261014000013_closing_guard.sql` | `election_reconciliation`, y `transition_election` re-declarada con guard de cierre (no consolidar con pendientes ni incidencias sin resolver) |
| `20261014000014_padron_import.sql` | `import_election_padron` (carga masiva del padrón desde CSV/Excel) |
| `20261014000015_tutor_scope.sql` | Trigger `sync_course_tutor` (sincroniza `tutor_assignments` y el rol `tutor` desde `courses.tutor_profile_id`) y `get_tutor_scope` (lectura acotada del tutor) |

## 2. Funciones RPC

Todas son `SECURITY DEFINER` con `search_path = public, pg_temp`, `REVOKE ALL
FROM public` y `GRANT EXECUTE` al rol mínimo.

### `cast_ballot(p_operation_id, p_voter_ref, p_option_type, p_candidate_list_id, p_ballot_id)`
Registra participación + papeleta en una transacción. Deriva el dispositivo de
`auth.uid()`; **no** acepta `device_id` del cliente.

- Idempotente por `operation_id` (devuelve el estado existente si ya se procesó).
- Valida dispositivo autorizado, asignación vigente, elección abierta y ventana
  horaria con el **reloj del servidor**, y votante habilitado en el padrón.
- El doble voto produce `status = 'conflict'` + incidencia, no un error genérico.
- Devuelve `{ operation_id, status, error_code?, duplicate? }`.

### `get_operation_status(p_operation_id)`
Recuperación ante respuestas de red perdidas. El dispositivo solo puede consultar
sus propias operaciones; un admin, todas.

### `transition_election(p_election_id, p_new_status)`
Solo `admin`. Valida transiciones (`is_valid_transition`) y requisitos de
apertura (padrón, listas, dispositivos). Audita el cambio en `audit_logs`.

**Guard de cierre**: al pasar a `closing` o `closed` rechaza la operación con
`cannot_close_with_pending_operations` si quedan operaciones `sync_operations`
en `pending`, o `cannot_close_with_unresolved_incidents` si hay incidencias en
`open`/`reviewing`. Cuando el guard salta, la elección permanece en su estado
anterior (la transacción se revierte). Esto evita consolidar una elección con
votos todavía sin sincronizar, que al cerrar ya no se aceptarían
(`cast_ballot` exige la elección en `open`).

### `election_reconciliation(p_election_id)`
`admin`/`operator`. Devuelve los contadores de conciliación de una elección,
sin identidad de votantes:

- `pending_operations`: operaciones en `pending`.
- `conflict_operations`: operaciones en `conflict`.
- `open_incidents`: incidencias en `open`/`reviewing`.
- `ready_to_close`: `true` solo si no hay pendientes ni incidencias abiertas.

La administración lo usa para bloquear el cierre en la interfaz antes de
intentarlo; el backend lo vuelve a imponer con el guard de `transition_election`.

### `generate_election_config(p_election_id)`
`admin`/`operator`. Genera el payload descargable (elección, listas, candidatos),
calcula su `sha256` y lo guarda versionado en `election_configs`.

### `create_enrollment_code(p_device_id, p_ttl_minutes)`
Solo `admin`. Genera un código de un solo uso, guarda su **hash** y devuelve el
texto **una sola vez**.

### `set_student_pin(p_student_id, p_pin)`
Personal (`is_staff()`). Fija el **PIN** de un estudiante (4–8 dígitos) y guarda
solo su **hash** (`sha256(institution_id || ':pin:' || pin)`). Un PIN vacío o
`null` lo borra. Audita el cambio.

### `import_election_padron(p_election_id, p_rows)`
Personal (`is_staff()`). **Carga masiva del padrón** por elección: recibe un
`jsonb` con la matriz de filas ya parseada en el cliente (CSV/Excel) y, por cada
fila, hace *upsert* del estudiante por (institución, `internal_code`), lo
inscribe en `election_voters` (resolviendo la mesa por `table_code`) y, si viene,
fija su PIN. Cada fila se procesa en un bloque aislado, de modo que un error no
aborta el lote.

- Claves por fila: `internal_code, first_name, last_name, cedula, table_code,
  pin, birth_date, status, enabled`.
- Solo permite elecciones en `draft`/`ready`; en otro estado lanza
  `padron_locked` (un padrón ya desplegado no se reescribe).
- Devuelve `{ total, created, updated, assigned, error_count, errors[] }`, con
  `errors[] = { row, message }` y mensajes como `missing_code`, `missing_name`,
  `invalid_pin`, `table_not_found`.
- Audita `padron_imported`.

### `get_tutor_scope()`
`SECURITY DEFINER`. Devuelve, acotado por `auth.uid()`, los cursos de los que la
persona es tutor (vía `tutor_assignments`) y los estudiantes de las mesas de esos
cursos (con elección y mesa). Existe porque el tutor **no** tiene permiso de
lectura directo sobre `election_voters` ni `elections`; el RPC resuelve el ámbito
sin abrir esas tablas.

- Devuelve `{ courses[], students[] }`. Los `students[]` incluyen `cedula` y el
  estado de habilitación, solo de los cursos asignados.
- Lanza `not_authenticated` (`42501`) sin sesión.

### `sync_course_tutor()` (trigger)
Trigger `AFTER INSERT/UPDATE/DELETE` sobre `courses`. Mantiene `tutor_assignments`
en sincronía con `courses.tutor_profile_id` y asegura que el perfil asignado
tenga el rol `tutor` en `user_roles`. Corre como `SECURITY DEFINER` para poder
escribir esas tablas aunque el operador que asigna el tutor no sea `admin`. El rol
`tutor` no se retira al desasignar (un perfil puede tutorar varios cursos).

### `get_device_bundle()`
`SECURITY DEFINER`; el dispositivo se deriva de `auth.uid()` (autorizado y con
asignación vigente); errores `device_not_authorized`, `device_not_assigned`,
`election_not_found`. Devuelve la configuración (elección, listas, candidatos),
la mesa e institución, y el **padrón** de su mesa con verificadores opacos:

- `verifier_salt`: `institution_id` (sal pública del esquema).
- `voters[]`: `{ voter_ref, code, voting_table_id, cedula_verifier, pin_verifier }`
  (solo referencia opaca y hashes; sin nombres ni cédulas en claro).
- Verificadores: `sha256(salt || ':' || kind || ':' || secret)` en hex, con
  `kind ∈ {cedula, pin}` y el secreto normalizado (cédula solo con dígitos).
- `config_version`, `config_hash` (sha256 del JSON de configuración) y
  `server_time`. Actualiza `last_seen_at`.

## 3. Edge Function `enroll-device`

`supabase/functions/enroll-device/index.ts`.

- Entrada: `{ enrollment_code, device_uid, app_version? }`.
- Verifica el hash del código, caducidad y uso; comprueba que el `device_uid`
  coincide con el registrado.
- Crea/reemplaza el usuario de Auth del dispositivo, lo vincula
  (`voting_devices.auth_user_id`), marca el dispositivo `authorized` y consume el
  código.
- Devuelve `access_token`/`refresh_token` propios del dispositivo.
- Se despliega **sin** verificación JWT (es pre-autenticación; el código es la
  credencial):

  ```
  supabase functions deploy enroll-device --no-verify-jwt
  ```

## 4. Pendiente

- Endurecer el canje de emparejamiento con un límite de intentos por dispositivo.
- Rotación de credenciales del dispositivo y cierre de sesión remoto.
- Exportación de listados (padrón) además del acta de resultados.
- Etapa 5: queda como prueba **manual en vivo** el corte de red entre dos
  dispositivos físicos (los escenarios de duplicados, cierre con pendientes,
  conciliación y separación del voto ya están verificados contra el backend).

## 5. Estado de ejecución

Aplicado al proyecto de Supabase de pruebas (ref `kxaizzbbntdzrzywpzyv`, región
`sa-east-1`) mediante el MCP de Supabase:

- Migraciones `000001`–`000015` aplicadas; el historial remoto quedó alineado
  con los nombres de archivo locales para que `supabase db push` no las repita.
- RLS activo en las 22 tablas; verificado que `anon` no ejecuta ninguna función
  ni accede a tablas.
- Edge Function `enroll-device` desplegada (versión 1, `verify_jwt = false`);
  comprobada su ejecución (`invalid_code` con un código inexistente).
- Datos ficticios de demostración cargados (`supabase/seed.sql`).
- Usuario de personal de prueba `admin@demo.test` (rol `admin`, institución DEMO)
  creado en Auth + `user_profiles` + `user_roles`; verificado el inicio de sesión
  y la lectura del perfil/roles bajo RLS.

Integridad de `cast_ballot` verificada: primer voto `accepted`, misma operación
idempotente (`duplicate = true`), doble voto con otra operación → `conflict`
(`duplicate_participation`), voto en blanco `accepted`, votante fuera del padrón
→ `rejected` (`voter_not_found`).

`get_device_bundle` verificado con el dispositivo de demostración (sesión
simulada): devolvió la elección, listas, candidatos y el padrón de su mesa, y sus
verificadores coinciden exactamente con los hashes calculados en el cliente
(cédula `1710034065` y PIN `1234`, esto último tras aplicar
`supabase/seed.sql`).

Escenario de **dos dispositivos** verificado (Etapa 5) sobre la elección demo,
con dos identidades de Auth: el dispositivo A registra un voto → `accepted`;
reenviar la misma operación → `duplicate = true` (idempotente); el dispositivo B
intenta registrar al mismo votante → `conflict` (`duplicate_participation`) y
abre una incidencia. `get_operation_status` devuelve `conflict` para la operación
del segundo dispositivo. Los datos de prueba se eliminaron al terminar.

Para aplicar el proyecto en un entorno nuevo desde la CLI, ver
`docs/instalacion.md` §5.

Guard de cierre verificado (Etapa 5) con una elección de prueba desechable y una
sesión de admin simulada: con una operación `pending` el paso a `closing`
devuelve `cannot_close_with_pending_operations` y la elección no cambia de
estado; con una incidencia `open` devuelve `cannot_close_with_unresolved_incidents`.
Tras limpiar pendientes e incidencias, `election_reconciliation` marca
`ready_to_close = true` y las transiciones `closing → closed` se aplican. La
elección de prueba y sus artefactos se eliminaron al terminar (la base quedó sin
residuos).

Separación del voto y RLS verificadas (Etapa 5) sobre el mismo proyecto: con el
rol `anon` se obtiene `permission denied` al leer `ballots`,
`participation_records` y la vista `election_results`, y al ejecutar
`cast_ballot` (`42501`). La tabla `ballots` no tiene ninguna columna que vincule
la papeleta con el votante (el vínculo existe solo en `participation_records`),
así que la separación es estructural.

`import_election_padron` verificada sobre una elección de prueba desechable:
un lote con altas, actualizaciones y errores devolvió
`{ total: 4, created: 1, updated: 1, assigned: 2, error_count: 2 }`, con
`missing_code` y `invalid_pin` por fila; con la elección en `open` devolvió
`padron_locked`. Los datos de prueba se eliminaron y los PIN de demostración se
restauraron al terminar.

Trigger de tutor e `get_tutor_scope` verificados: al escribir
`courses.tutor_profile_id` el trigger creó la fila correspondiente en
`tutor_assignments` y otorgó el rol `tutor`; `get_tutor_scope()` (sesión
simulada del tutor) devolvió su curso y los 3 estudiantes de la mesa de ese
curso; al limpiar el tutor, el trigger retiró la asignación. El estado de
demostración se restauró al terminar.
