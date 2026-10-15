# Decisiones técnicas

Registro de decisiones importantes y sus motivos. Formato: decisión, contexto,
alternativas y consecuencia.

## D1. Monorepo con dos apps Flutter y paquete compartido

- **Decisión**: un repositorio con `apps/administracion_electoral`,
  `apps/votacion_estudiantil`, `packages/electoral_core` y `packages/kite_ui`.
- **Motivo**: un solo backend, código de dominio compartido, versiones alineadas.
- **Consecuencia**: `electoral_core` es Dart puro (sin Flutter) para no arrastrar
  la UI a la lógica.

## D2. UI basada en el template Kite (MIT)

- **Decisión**: vendorizar `packages/kite_ui` desde el template Kite ya presente
  en la máquina (`eduvex`), en lugar de depender de un paquete publicado.
- **Motivo**: es código fuente editable; ya compila en esta máquina; MIT permite
  uso comercial; incluye tabla de datos, gráficos y formularios.
- **Consecuencia**: los widgets se mantienen como código propio; se conserva el
  aviso de licencia MIT.

## D3. Estado con Riverpod y navegación con go_router

- **Decisión**: `flutter_riverpod ^3` y `go_router ^18` (el mismo stack de Kite).
- **Motivo**: sencillo, mantenible, sin codegen innecesario; guardas de sesión y
  rutas anidadas.
- **Consecuencia**: se evitan dependencias pesadas adicionales.

## D4. Supabase sin servidor propio

- **Decisión**: Postgres + RLS + RPC `SECURITY DEFINER` + Edge Functions.
- **Motivo**: requisito; no depender de la PC del administrador encendida.
- **Consecuencia**: las operaciones privilegiadas se implementan en el servidor;
  ningún cliente Flutter ve la `service_role`.

## D5. Enrolamiento de dispositivos por Edge Function

- **Decisión**: el admin genera un código de emparejamiento de un solo uso; la
  tablet lo canjea en una Edge Function que crea/entrega credenciales del
  dispositivo usando `service_role` **solo en el servidor**.
- **Alternativas descartadas**: token HMAC mediante RPC (menos estándar) y alta
  directa desde el cliente (expondría privilegios).
- **Consecuencia**: requiere Edge Functions habilitadas; se documenta el
  despliegue en `docs/instalacion.md`.

## D6. Identificación del votante: código estudiantil + PIN/QR y cédula

- **Decisión** (confirmada por el usuario): soportar **código estudiantil con
  PIN/QR** y también **cédula ecuatoriana**.
- **Motivo**: flexibilidad para la institución; el código interno minimiza datos
  personales, la cédula cubre casos sin carnet.
- **Consecuencia**: `electoral_core` incluye validación de cédula ecuatoriana
  (módulo 10) y reglas configurable de código estudiantil. La identidad se
  comprueba contra el padrón; la cédula es opcional por estudiante.

## D7. Separación de idempotencia y contenido del voto

- **Decisión**: `sync_operations` guarda el UUID de operación **sin** enlazarlo a
  `ballots` ni a `participation_records`; la atomicidad se logra por transacción.
- **Motivo**: cumplir "evitar identificadores compartidos entre participación y
  papeleta".
- **Consecuencia**: para consultar una operación solo se devuelve su estado, no
  el contenido.

## D8. Zona horaria explícita

- **Decisión**: `time_zone` por institución, por defecto `America/Guayaquil`;
  fechas almacenadas en UTC (`timestamptz`).
- **Motivo**: evitar ambigüedad y no depender del reloj del dispositivo.
- **Consecuencia**: apertura/cierre se deciden con el reloj del servidor.

## D9. SQLite local y cifrado

- **Decisión**: `drift` + `sqlite3_flutter_libs`; token/estado en
  `flutter_secure_storage`. Cifrado de la base con SQLCipher **cuando la
  plataforma y las versiones lo permitan**.
- **Motivo**: SQLite es requisito; el cifrado es "cuando sea posible".
- **Pendiente**: confirmar compatibilidad de `sqlcipher_flutter_libs` con
  Android y Windows en las versiones actuales antes de comprometerlo. Si no es
  estable, se documenta la limitación en lugar de simular cifrado.

## D10. Navegación de la administración por barra superior

- **Decisión**: barra superior como navegación principal, sin barra lateral
  permanente (Kite usa sidebar por defecto; se reescribió el shell).
- **Motivo**: requisito explícito de diseño.
- **Consecuencia**: el shell `admin_shell.dart` implementa la barra superior.

## D11. No usar el stack local de Supabase (Docker prohibido)

- **Decisión**: usar la CLI solo para `db push`, `functions deploy`,
  `gen types`; no `supabase start`.
- **Motivo**: la especificación prohíbe Docker.
- **Consecuencia**: las pruebas de base de datos se ejecutan contra un proyecto
  Supabase de **pruebas**, nunca contra datos reales.

## D12. Año lectivo y archivo

- **Decisión**: nunca vaciar la base al iniciar un año; las elecciones anteriores
  quedan en histórico; se copia configuración sin copiar votos ni participación.
- **Motivo**: requisito de archivo anual.
- **Consecuencia**: borrados solo con confirmación y autorización explícitas.

## D13. Revocar en `anon` el `EXECUTE` por defecto de las funciones

- **Decisión**: además de `revoke ... from public`, cada migración debe revocar
  explícitamente a `anon` (migración `000010`) y ajustar los privilegios por
  defecto del esquema `public`.
- **Motivo**: Supabase concede `EXECUTE` **directamente** a
  `anon`/`authenticated` en cada función nueva; `REVOKE ... FROM public` no
  elimina ese grant. Sin esta corrección, `anon` podía invocar RPC
  `SECURITY DEFINER` (p. ej. `cast_ballot`).
- **Consecuencia**: `authenticated` conserva solo las funciones concedidas de
  forma explícita; `anon` no ejecuta ninguna. `log_audit` se retira de
  `authenticated` (se usa internamente como `SECURITY DEFINER`) para evitar
  entradas de auditoría forjadas.

## D14. Capa de datos en la app, contratos en `electoral_core`

- **Decisión**: los contratos y modelos puros (configuración de Supabase, nombres
  de RPC, `CastBallotResult`, `StaffProfile`) viven en `electoral_core`; el
  cliente de Supabase y los repositorios viven en `lib/core/` de cada app
  (`data/`, `auth/`). La app de administración los estrena (Etapa 3); la de
  votación los replicará en la Etapa 4.
- **Motivo**: respetar D1 (`electoral_core` es Dart puro, sin Flutter) y el árbol
  de `docs/arquitectura.md` (`core/data` por app), evitando arrastrar Flutter al
  dominio. El `supabase_flutter` solo entra en las apps.
- **Alternativas descartadas**: meter `supabase_flutter` en `electoral_core`
  (rompe la pureza de Dart) y duplicar modelos por app (divergencia).
- **Consecuencia**: la sesión se resuelve con un `AsyncNotifier` que escucha
  `onAuthStateChange`; `go_router` usa un `refreshListenable` que observa ese
  provider para redirigir a `/login`. Las claves se inyectan con
  `--dart-define`; no se lee `.env` en tiempo de ejecución. La app de votación ya
  usa el mismo esquema en `lib/core/` (repositorios de padrón, votación y outbox).

## D15. Frontera de red del voto tras una interfaz (`BallotCastApi`)

- **Decisión**: `OutboxSender` depende de una interfaz
  `BallotCastApi` (`castBallot` + `getOperationStatus`), implementada por
  `BallotGateway` (Supabase). La lógica de identificación vive en
  `electoral_core` (`VoterLookup`) y los repositorios locales en
  `apps/votacion_estudiantil/lib/core/voting/`.
- **Motivo**: probar la cola, los reintentos, la idempotencia y la recuperación
  ante respuesta perdida **sin red ni Supabase**, con un gateway falso y una base
  `drift` en memoria.
- **Consecuencia**: `test/voting_flow_test.dart` cubre identificación, registro
  atómico, doble voto, aceptación, recuperación por estado y conflicto. La red
  real solo se ejercita contra un proyecto Supabase de pruebas (Etapa 5).

## D16. Cierre bloqueado por pendientes y re-descarga que no rehabilita el voto

- **Decisión**: el backend impone el cierre seguro en `transition_election`
  (rechaza `closing`/`closed` con operaciones `pending` o incidencias sin
  resolver; ver `election_reconciliation`). En el cliente, `applyBundle`
  reaplica la marca `hasVoted` desde `participation_local` al reinsertar el
  padrón.
- **Motivo**: (1) no se debe consolidar una elección con votos aún sin
  sincronizar —al cerrar, `cast_ballot` ya no los aceptaría—; (2) al re-descargar
  la configuración, `applyBundle` borraba `localVoters` y dejaba `hasVoted` en
  `false`, lo que **rehabilitaba el voto local** en el mismo equipo (doble
  papeleta permitida; el servidor la detectaría como conflicto, pero se perdía la
  protección local).
- **Consecuencia**: `provisioning_repository.dart` restaura `hasVoted`/`votedAt`
  desde `participation_local` (que se conserva) y `test/voting_flow_test.dart`
  verifica que re-descargar no rehabilita el voto. El guard de cierre se prueba
  contra el backend de pruebas.

## D17. Exportación del acta en PDF y Excel

- **Decisión**: la exportación vive en `lib/shared/export/` como funciones
  **puras** (`buildActaPdf`, `buildActaExcel`, `actaFileName`) sobre un objeto
  `ActaData` con solo **agregados**; el guardado en disco (`ActaExporter`) usa el
  diálogo nativo de `file_selector` y separa la E/S de la generación.
- **Motivo**: poder probar la generación (PDF válido, `.xlsx` bien formado,
  nombre de archivo, totales) sin red, sin Supabase y sin abrir diálogos; y
  garantizar que el acta **no** contiene identidad del votante.
- **Consecuencia**: `pdf` y `excel` aportan las dependencias; `excel` fija
  versiones de `archive`/`xml`, aceptadas. `test/acta_export_test.dart` cubre el
  modelo, el nombre de archivo y ambos formatos. La fuente Type1 estándar usa
  `/WinAnsiEncoding`, suficiente para acentos del español.

## D18. Modo kiosco como bloqueo **dentro de la app**

- **Decisión**: al pulsar **Comenzar a votar** la app activa un modo kiosco
  implementado solo en Dart (`lib/features/kiosk/kiosk.dart`): oculta las barras
  del sistema en Android (`SystemUiMode.immersiveSticky`), envuelve cada pantalla
  del flujo en un `PopScope(canPop: false)` y retira la flecha de "atrás" de la
  barra de la app. El personal sale manteniendo pulsado el encabezado (zona
  `KioskExitZone`) y confirmando con un diálogo.
- **Motivo**: mantener al votante dentro del flujo sin añadir **plugins nativos**
  ni dependencias frágiles; el bloqueo funciona igual en Android y Windows y es
  testeable en `flutter test` (`test/kiosk_widget_test.dart`). Las llamadas a
  `SystemChrome` se lanzan sin `await` para no bloquear la navegación (y porque en
  las pruebas no hay respondedor de plataforma).
- **Consecuencia**: es un bloqueo **de la app**, no del sistema operativo; no
  impide usar los botones físicos de inicio/ajustes. El bloqueo a nivel de
  dispositivo (pantalla fijada en Android / Assigned Access en Windows) se
  configura al preparar el equipo y se documenta en `docs/manual_votacion.md`
  §3.1. `KioskGuard` solo intercepta la navegación de la persona; los
  `pop`/`popUntil` programáticos (volver a la papeleta, cerrar el flujo) siguen
  operando.

## D19. Informes gráficos con widgets de Kite y barras vectoriales en el PDF

- **Decisión**: los gráficos de resultados usan `KiteDonut` (reparto con el total
  en el centro) y un nuevo `KiteBarChart` en `kite_ui` (barras verticales con la
  grilla y tipografía del tema), alimentados por una función **pura**
  `voteDistribution(...)` (blancos y nulos solo si tienen votos) en
  `lib/features/resultados/chart_data.dart`. El acta PDF dibuja su propio gráfico
  de barras con rectángulos de `pdf` (sin rasterizar).
- **Motivo**: mantener el informe gráfico en pantalla y en el PDF **sin
  dependencias nuevas** (fl_chart ya estaba en `kite_ui`) y sin embeber imágenes
  rasterizadas (que exigirían un `Scene`/`PictureRecorder` fuera de `flutter
  test`). La paleta categórica (`KiteChartPalette`) es fija y ordenada para que la
  misma lista conserve su color entre la dona y las barras.
- **Consecuencia**: `test/results_chart_test.dart` cubre el reparto puro; el
  gráfico queda como parte del acta PDF y de la pantalla de Resultados.

## D20. Ámbito de tutor por disparador + RPC de lectura acotada

- **Decisión**: la administración sigue asignando el tutor escribiendo
  `courses.tutor_profile_id`; un disparador `SECURITY DEFINER`
  (`sync_course_tutor`) refleja esa asignación en `tutor_assignments` y concede el
  rol `tutor`. La lectura del ámbito se entrega por el RPC `get_tutor_scope()`
  (`SECURITY DEFINER`, acotado por `auth.uid()`), no por RLS sobre las tablas.
- **Motivo**: el diseño de RLS ya filtraba al tutor por `tutor_assignments`, pero
  (a) la asignación del panel no creaba esas filas ni el rol, y (b) el rol no tiene
  lectura directa sobre `election_voters`/`elections`, que el ámbito necesita. El
  disparador cierra el hueco (a) y el RPC resuelve (b) sin abrir esas tablas.
- **Consecuencia**: el rol `tutor` no se retira al desasignar (un perfil puede
  tutorar varios cursos); la interfaz de tutor es de **solo lectura** y enruta
  automáticamente a un usuario `tutor` sin rol de gestión.

---

## Decisiones pendientes de confirmar

1. **Marca institucional fina** (matices exactos de azul/rojo, logotipo): el tema
   actual usa el esquema azul de Kite con rojo reservado como acento. Se ajustará
   por configuración cuando se defina la identidad visual definitiva.
2. **Método de identificación del votante**: el PIN ya está implementado (4–8
   dígitos, solo su hash en el servidor) y la cédula se valida con el algoritmo
   ecuatoriano; queda por confirmar la **combinación exacta** habilitada por
   institución (solo cédula, solo código+PIN, o ambos).
3. **Política exacta de votos locales previos al cierre** (aceptar/revisar):
   requiere la normativa institucional. La implementación dejará el
   comportamiento configurable y, por defecto, el más conservador (revisión
   manual).
4. **Cifrado SQLCipher**: confirmar estabilidad multiplataforma antes de
   adoptarlo.

## Limitaciones conocidas (no se ocultan)

- Correlación identidad↔voto por metadatos de tiempo/orden con acceso total a la
  base (mitigada, no eliminada).
- Sin garantía global de un voto por estudiante con varios dispositivos
  desconectados y padrones superpuestos.
- La seguridad física del dispositivo y la supervisión presencial de la
  identificación son responsabilidad operativa.
