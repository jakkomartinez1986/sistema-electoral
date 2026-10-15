# Pruebas

Estrategia y catálogo de escenarios. **No se usan datos personales reales.**

## 1. Niveles

- **Unitarias** (Dart puro, `package:test`) — dominio en `electoral_core`.
- **De widget/UI** (`flutter_test`) — pantallas de ambas apps.
- **De integración/seguridad** — contra un proyecto Supabase de **pruebas**
  (RLS, RPC, idempotencia, separación del voto). Se implementan en la Etapa 2.

## 2. Comandos

```powershell
# Núcleo compartido
dart test --directory packages/electoral_core

# Administración
flutter test --directory apps/administracion_electoral

# Votación
flutter test --directory apps/votacion_estudiantil

# Análisis estático
dart analyze --directory packages/electoral_core
flutter analyze --directory apps/administracion_electoral
flutter analyze --directory apps/votacion_estudiantil
```

## 3. Estado actual (Etapas 1–6)

| Escenario | Nivel | Estado |
|---|---|---|
| Validación de cédula ecuatoriana (módulo 10) | unitaria | ✅ |
| Reglas de código estudiantil | unitaria | ✅ |
| Modelo `BallotOption` (lista/blanco/nulo, sin identidad) | unitaria | ✅ |
| Estados de elección (`ElectionStatus`) | unitaria | ✅ |
| Identificación del votante en el padrón local (cédula y código+PIN) | unitaria (app) | ✅ |
| Registro de voto atómico local (participación + outbox) | unitaria (app) | ✅ |
| Prevención de doble voto local (8/14, parte de cliente) | unitaria (app) | ✅ |
| Outbox: voto aceptado marca la participación como sincronizada | unitaria (app) | ✅ |
| Outbox: fallo de red consulta el estado antes de reintentar (12) | unitaria (app) | ✅ |
| Outbox: conflicto del servidor se conserva como conflicto (20) | unitaria (app) | ✅ |
| Dos sincronizaciones simultáneas no duplican el envío | unitaria (app) | ✅ |
| Reinicio con operaciones pendientes: el outbox persiste en disco (10) | unitaria (app) | ✅ |
| Re-descargar la configuración conserva outbox y participación (16) | unitaria (app) | ✅ |
| Re-descargar no rehabilita el voto local del mismo equipo (8, 16) | unitaria (app) | ✅ |
| Totales del acta (válidos/blancos/nulos) y orden por votos | unitaria (app) | ✅ |
| Nombre de archivo del acta (sin acentos ni símbolos) | unitaria (app) | ✅ |
| Generación del acta en PDF (encabezado `%PDF`) | unitaria (app) | ✅ |
| Generación de resultados en Excel (contenedor ZIP `.xlsx`) | unitaria (app) | ✅ |
| Importación del padrón: parser CSV (delimitador, comillas, fechas, validaciones) | unitaria (app) | ✅ |
| Importación del padrón: lectura `.xlsx` y serialización de filas a JSON | unitaria (app) | ✅ |
| Informe gráfico: reparto de votos (blancos/nulos solo si tienen votos) | unitaria (app) | ✅ |
| Ámbito de tutor: parseo de cursos/estudiantes y filtrado por curso | unitaria (app) | ✅ |
| Pin del estudiante en el padrón: se guarda solo el hash en el servidor | integración (SQL) | ✅ |
| Importación de padrón por lote y `padron_locked` con la elección abierta | integración (SQL) | ✅ |
| Trigger de tutor crea `tutor_assignments`/rol y `get_tutor_scope` acota | integración (SQL) | ✅ |
| La administración abre en el panel | widget | ✅ |
| La votación inicia bloqueada ("Dispositivo no autorizado") | widget | ✅ |
| Flujo completo de votación: identificación → papeleta → confirmación → recibo | widget | ✅ |
| El modo kiosco oculta el botón atrás y bloquea el "atrás" del sistema | widget | ✅ |
| Mantener pulsado el encabezado pide confirmación para salir del kiosco | widget | ✅ |
| Confirmar la salida desbloquea el equipo y vuelve al inicio | widget | ✅ |
| Compilación Windows (ambas apps) | build | ✅ |
| Cierre con operaciones `pending` bloqueado (19, 26) | integración (SQL) | ✅ |
| Cierre con incidencias sin resolver bloqueado (20, 26) | integración (SQL) | ✅ |
| Cierre exitoso tras conciliar pendientes (18, 26) | integración (SQL) | ✅ |
| `election_reconciliation` refleja pendientes y `ready_to_close` | integración (SQL) | ✅ |
| `anon` no lee `ballots`, `participation_records` ni `election_results` (23) | integración (SQL) | ✅ |
| `anon` no ejecuta `cast_ballot` (23) | integración (SQL) | ✅ |
| `ballots` sin columna de identidad del votante (24, 25) | integración (SQL) | ✅ |
| Dos dispositivos, mismo votante: el segundo entra en conflicto (14) | integración (SQL) | ✅ |
| Reenvío del mismo `operation_id`: idempotente, no duplica (12, 13) | integración (SQL) | ✅ |
| `get_operation_status` devuelve `conflict` para el duplicado (12) | integración (SQL) | ✅ |

Las pruebas unitarias del núcleo (`packages/electoral_core`) y del registro
local (`apps/votacion_estudiantil/test/voting_flow_test.dart`) usan una base
`drift` en memoria y un gateway falso: **no** tocan red ni datos reales. Las de
interfaz de votación viven en `test/voting_widget_flow_test.dart` (flujo) y
`test/kiosk_widget_test.dart` (modo kiosco).

## 4. Catálogo obligatorio (se completan en Etapas 2–5)

1. Registro de una elección nueva.
2. Importación de estudiantes.
3. Detección de estudiantes duplicados.
4. Registro de listas con cantidad variable.
5. Voto por una lista.
6. Voto blanco.
7. Voto nulo.
8. Prevención de doble participación.
9. Registro local sin conexión.
10. Reinicio de la aplicación con operaciones pendientes.
11. Sincronización tras recuperar Internet.
12. Reintento de una operación cuya respuesta se perdió.
13. Envío repetido del mismo UUID.
14. Dos dispositivos intentando registrar al mismo estudiante.
15. Dispositivos con padrones exclusivos.
16. Configuración electoral desactualizada.
17. Dispositivo revocado.
18. Elección cerrada.
19. Voto local pendiente después del cierre.
20. Conflictos de sincronización.
21. Permisos de un tutor.
22. Intento de acceso no autorizado a datos.
23. Comprobación de RLS.
24. Separación entre participación y papeletas.
25. Imposibilidad de consultar el voto individual de un estudiante.
26. Conciliación de totales y resultados.
27. Archivo anual sin alterar elecciones anteriores.
28. Restauración de datos de prueba desde una copia.
29. Funcionamiento de las interfaces en Android y Windows.

## 5. Cómo se probarán los escenarios críticos (notas de diseño)

- **Doble participación (8, 14)**: `unique(election_id, election_voter_id)` en
  `participation_records`; el segundo intento devuelve conflicto controlado.
- **Idempotencia (12, 13)**: mismo `operation_id` dos veces ⇒ una sola
  participación y una sola papeleta. Estado consultable por UUID.
- **Separación del voto (24, 25)**: consulta directa con la anon key a `ballots`
  y a las vistas de resultados no debe exponer el vínculo con el estudiante.
- **Offline (9–11, 19)**: simulación de corte de red y reinicio con `outbox`
  persistente; verificación de que nada se borra hasta confirmación del servidor.
- **RLS (21–23)**: usuarios de prueba con cada rol; comprobar denegaciones por
  defecto y filtrado del tutor por curso/mesa. Para el tutor, el ámbito se entrega
  por el RPC `get_tutor_scope` (el rol no lee `election_voters`/`elections`
  directamente), y la asignación se propaga por el disparador `sync_course_tutor`.
- **Conciliación (26)**: los totales de resultados cuadran con las operaciones
  `accepted`; los conflictos no se cuentan hasta resolverse.

## 6. Reglas

- Nunca afirmar que una prueba pasó si no se ejecutó.
- Nunca usar datos personales reales en pruebas automatizadas.
- Las pruebas de base de datos apuntan a un proyecto de pruebas, jamás a datos
  de una jornada real.

## 7. Verificación de entrega (Etapa 6)

Ejecutado con **Flutter 3.47.2 / Dart 3.13.2**.

| Comprobación | Comando | Resultado |
|---|---|---|
| Análisis del núcleo | `dart analyze` (packages/electoral_core) | Sin hallazgos ✅ |
| Análisis de administración | `flutter analyze` | Sin hallazgos ✅ |
| Análisis de votación | `flutter analyze` | Sin hallazgos ✅ |
| Pruebas del núcleo | `dart test` | 30/30 ✅ |
| Pruebas de administración | `flutter test` | 25/25 ✅ |
| Pruebas de votación | `flutter test` | 17/17 ✅ |
| Compilación Windows (administración) | `flutter build windows --release` | ✅ |
| Compilación Windows (votación) | `flutter build windows --release` | Pendiente (manual) |
| Compilación Android (votación) | `flutter build apk --release` | Pendiente (manual) |

> La verificación estática y las suites se ejecutan en cada cambio. **Las
> compilaciones de release se ejecutan manualmente** (requieren la cadena nativa
> Visual Studio / Android SDK y tardan varios minutos); su salida se describe en
> `docs/instalacion.md` §9. No se marcan como verificadas hasta confirmarlas.
