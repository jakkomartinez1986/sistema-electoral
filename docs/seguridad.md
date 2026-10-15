# Seguridad y privacidad

## 1. Principios

- **Denegar por defecto** en todas las tablas expuestas.
- **Mínimo privilegio** por rol.
- Las operaciones críticas se ejecutan en el servidor, nunca desde el cliente.
- La `service_role` **nunca** llega a una app Flutter.
- La seguridad se apoya en el backend, no en el ejecutable ni en la interfaz.

## 2. Roles

| Rol | Ámbito | Puede |
|---|---|---|
| `admin` | Institución | Configurar todo, abrir/cerrar elecciones, autorizar/revocar dispositivos, resolver conflictos, publicar resultados |
| `operator` | Institución | Gestionar padrón, listas y dispositivos según lo autorizado; no publicar resultados |
| `tutor` | Sus cursos/mesas | Consultar y operar **solo** lo asignado a sus cursos |
| `device` | Un dispositivo autorizado | Únicamente ejecutar RPC de votación/sincronización y descargar su configuración |

Los roles viven en `user_roles` (personal) y en `voting_devices` (dispositivos),
no en el cliente. El rol se resuelve en la base a partir de `auth.uid()`.

## 3. Row Level Security

- RLS **habilitado** en todas las tablas de `public`.
- Políticas distintas para lectura y escritura; ninguna tabla acepta escritura
  directa desde `anon`/`authenticated` salvo lo estrictamente necesario.
- `ballots` y `participation_records`: **sin** INSERT/UPDATE/DELETE para los
  roles de cliente. Solo el RPC `SECURITY DEFINER` escribe en ellas.
- `tutor`: filtrado por cursos/mesas asignados mediante `tutor_assignments`
  (cursos → `voting_tables` → `election_voters`); no ve nada fuera de sus cursos.
  Como el rol no tiene lectura directa sobre `election_voters`/`elections`, el
  ámbito se entrega por el RPC `get_tutor_scope` (`SECURITY DEFINER`, acotado por
  `auth.uid()`). La asignación de tutor (`courses.tutor_profile_id`) se refleja en
  `tutor_assignments` y en el rol `tutor` mediante el disparador
  `sync_course_tutor`; el alcance de la interfaz de tutor es de **solo lectura**.
- Los dispositivos (`device`) solo ven su propia configuración y su propio
  estado de operaciones (se resuelven por `voting_devices.auth_user_id`).

### Reglas de las funciones `SECURITY DEFINER`

- `SET search_path = public, pg_temp` (evita secuestro de `search_path`).
- `REVOKE ALL ... FROM public` y `GRANT EXECUTE` únicamente al rol que
  corresponde.
- Validan rol/estado **dentro** de la función; no confían en parámetros.
- No registran contenido de voto en logs ni en `audit_logs`.

## 4. Gestión de credenciales

- La `anon key` es pública por diseño (RLS decide qué se ve).
- La `service_role` vive solo en el servidor (Edge Functions / CLI). Está
  prohibida en ambos clientes Flutter.
- Los tokens de dispositivo y del personal se guardan en
  `flutter_secure_storage` (Keystore en Android, DPAPI en Windows).
- `.env` nunca se sube; `.env.example` solo tiene valores ficticios.

### Cambio de credenciales y revocación

- **Contraseña del personal**: se cambia desde Supabase Auth (o panel); las
  sesiones se pueden revocar desde Auth.
- **Dispositivo**: `voting_devices.status = 'revoked'` invalida su autorización;
  el RPC rechaza nuevas operaciones. Además, se puede rotar/eliminar el usuario
  de Auth asociado al dispositivo. Ver `docs/instalacion.md`.

## 5. Auditoría

Se registran en `audit_logs` (sin datos sensibles):

- accesos administrativos relevantes,
- cambios de configuración,
- apertura y cierre de elecciones,
- autorización y revocación de dispositivos,
- resolución de incidencias y conflictos.

**Nunca** se registran contraseñas, tokens ni votos.

## 6. Modelo de amenazas (resumen)

| Amenaza | Mitigación |
|---|---|
| Insertar/modificar papeletas desde el cliente | Sin grants de escritura; solo RPC; RLS deny-by-default |
| Auto-autorizarse como dispositivo | No existe endpoint de auto-enrolamiento; requiere código emitido por un admin |
| Modificar el reloj de la tablet para reabrir una elección | Apertura/cierre se deciden con el reloj del **servidor**, no del dispositivo |
| Un tutor accede a cursos ajenos | RLS + `get_tutor_scope` filtran por `tutor_assignments` (solo sus cursos); la asignación se sincroniza por disparador |
| Un tutor se otorga más ámbito del asignado | El rol `tutor` y la asignación los concede el disparador `SECURITY DEFINER` al escribir `courses.tutor_profile_id`; el rol `tutor` en sí solo habilita lectura de su ámbito |
| Robo de credenciales de un dispositivo comprometido | Token en almacenamiento seguro; revocación server-side; sin secretos administrativos en la tablet |
| Doble voto en modo offline | Padrones exclusivos por dispositivo + detección de duplicados + conciliación (no se promete garantía global offline) |
| Correlacionar identidad y voto | Separación de tablas, sin claves compartidas, sin voto en auditoría, timestamps gruesos |
| Exfiltrar resultados antes del cierre | Resultados solo tras cierre y consolidación; sin lectura parcial durante `open` |

## 7. Riesgos residuales (documentados, no ocultados)

- Un dispositivo con acceso físico y comprometido podría intentar reenviar
  operaciones; la idempotencia y la validación server-side limitan el daño, pero
  la seguridad física del dispositivo es responsabilidad operativa.
- La correlación por metadatos de tiempo/orden es posible con acceso total a la
  base; se mitiga, no se elimina.
- La identidad del votante en la tablet depende del método de identificación
  elegido (código estudiantil, cédula o QR); ninguno es infalible contra
  suplantación presencial sin supervisión.

Estas limitaciones se comunican en la operación real y en los manuales.
