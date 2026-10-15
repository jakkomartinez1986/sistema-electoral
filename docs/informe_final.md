# Informe final de entrega (Etapa 6)

Cierre del **Sistema Electoral Estudiantil**: estado de los entregables,
verificación ejecutada, decisiones relevantes, límites conocidos y trabajo
pendiente. Es un documento honesto: lo que no se ha verificado o no está
implementado se declara como tal.

## 1. Resumen ejecutivo

El sistema consta de dos aplicaciones Flutter y un backend Supabase (PostgreSQL
+ RLS + RPC + Edge Functions), con un paquete de dominio compartido. Se
entregaron las seis etapas del plan:

| Etapa | Alcance | Estado |
|---|---|---|
| 1 — Inspección y diseño | Arquitectura, modelo de datos y plan | ✅ |
| 2 — Backend | Migraciones `000001`–`000015`, RLS, RPC, Edge Function, datos demo | ✅ |
| 3 — Administración | App Windows con 10 módulos A–J sobre el backend | ✅ |
| 4 — Votación | App Android/Windows offline-first (padrón, papeleta, outbox) | ✅ |
| 5 — Integración | Guard de cierre, conciliación, verificación contra backend | ✅¹ |
| 6 — Entrega | Análisis, pruebas, artefactos, documentación e informe | 🟡² |

¹ Cerrada salvo la prueba manual de **corte de red en vivo entre dos
dispositivos físicos** (ver §7).
² Las **compilaciones de release** se ejecutan **manualmente** (ver §6) y no se
marcan como verificadas hasta confirmarlas.

## 2. Alcance entregado

### Backend (`supabase/`)

- **15 migraciones** versionadas (≈1.9k líneas de SQL) que crean el esquema,
  los roles, las políticas RLS, las funciones y los ajustes de seguridad y
  rendimiento.
- **Funciones RPC `SECURITY DEFINER`** con `search_path` fijo y permisos
  mínimos: `cast_ballot`, `get_operation_status`, `get_device_bundle`,
  `import_election_padron`, `get_tutor_scope`, `transition_election`,
  `election_reconciliation`, `generate_election_config`, entre otras.
- **Edge Function `enroll-device`** (Deno) para el emparejamiento de
  dispositivos con código de un solo uso, sin exponer la `service_role` a las
  apps.
- **Datos ficticios de demostración** (`seed.sql`) con UUID fijos.
- **Separación estricta** entre identidad del votante (participación) y la
  papeleta (`ballots` sin referencia al votante).

### Aplicación de Administración (`apps/administracion_electoral`, Windows)

- Acceso del personal con **Supabase Auth**; panel con contadores reales según
  RLS.
- Diez módulos funcionales (A–J): institución y años lectivos, cursos y mesas,
  padrón, listas y candidatos, elecciones, dispositivos, sincronización,
  resultados, archivo y sistema. Cada módulo con su repositorio y proveedores
  Riverpod.
- **Importación del padrón desde CSV/Excel** (módulo Padrón): detección de
  columnas y delimitador, validación por fila y carga por lote vía
  `import_election_padron`, con previsualización y resumen de resultados.
- **PIN de votación**: el módulo Padrón permite **fijar/limpiar** el PIN de un
  estudiante (4–8 dígitos) con estado visible (`Definido` / `Sin PIN`).
- **Informe gráfico de resultados**: dona (reparto) y barras (votos por lista)
  sobre la vista `election_results`, más un gráfico de barras incluido en el
  **acta PDF**.
- **Exportación de resultados y acta en PDF y Excel** desde Resultados y desde
  el detalle de una elección archivada, con diálogo nativo de "Guardar como".
  Las funciones de generación son puras y sin identidad del votante.
- **Vista de tutor** de solo lectura: un usuario con rol `tutor` (y sin rol de
  gestión) entra directo a su área y ve únicamente sus cursos y los estudiantes
  de esos cursos (ámbito impuesto por el backend).

### Aplicación de Votación (`apps/votacion_estudiantil`, Android y Windows)

- **Emparejamiento** del dispositivo (código de un solo uso, sin cámara).
- **Descarga y verificación** de la configuración y el padrón
  (`get_device_bundle`) con persistencia local transaccional (drift/SQLite).
- **Flujo de votación offline-first**: identificación por cédula o código+PIN,
  papeleta neutral (lista/blanco/nulo), registro transaccional local y **outbox**
  con reintentos, idempotencia y pantalla de comprobante neutra.
- **Modo kiosco**: durante la votación el equipo queda bloqueado en el flujo
  (barra de sistema oculta en Android y navegación "atrás" bloqueada). El personal
  sale manteniendo pulsado el encabezado y confirmando; el bloqueo a nivel de
  dispositivo (pantalla fijada / Assigned Access) se configura al preparar el
  equipo.

### Núcleo compartido (`packages/electoral_core`, Dart puro)

- Modelos, validaciones (cédula ecuatoriana, código estudiantil), verificadores
  del padrón, identificador del votante y contrato de configuración.

## 3. Arquitectura y stack

- **UI**: `kite_ui` (template Kite, shadcn_ui, MIT).
- **Estado**: `flutter_riverpod` ^3 (sin codegen).
- **Navegación**: `go_router` ^18.
- **Base local**: `drift` + `sqlite3_flutter_libs` (SQLite tipado).
- **Secretos locales**: `flutter_secure_storage`.
- **Exportación**: `pdf` (acta), `excel` (xlsx), `file_selector` (guardar).
- **Backend**: Supabase (Postgres + PostgREST + RPC + Edge Functions).

Regla de dependencias: `presentation → application → domain → data`. La
presentación nunca habla directamente con la red ni con la base local. Detalle
en `docs/arquitectura.md`.

## 4. Métricas del repositorio

| Métrica | Valor |
|---|---|
| Migraciones SQL | 15 (≈1.9k líneas) |
| Edge Functions | 1 (`enroll-device`) |
| Dart en apps + núcleo | ~100 archivos (≈17k líneas, incl. ≈5.9k generadas por drift) |
| Paquete de UI vendorizado | `kite_ui` (MIT), aparte |
| Suites de prueba | 72 pruebas (30 + 25 + 17) |

## 5. Verificación (análisis y pruebas)

Ejecutado con **Flutter 3.47.2 / Dart 3.13.2**:

| Comprobación | Resultado |
|---|---|
| `dart analyze` (núcleo) | Sin hallazgos ✅ |
| `flutter analyze` (administración) | Sin hallazgos ✅ |
| `flutter analyze` (votación) | Sin hallazgos ✅ |
| `dart test` (núcleo) | 30/30 ✅ |
| `flutter test` (administración) | 25/25 ✅ |
| `flutter test` (votación) | 17/17 ✅ |

Escenarios de integración verificados **contra el proyecto Supabase de
pruebas** (SQL): separación del voto, RLS para `anon` (`permission denied` en
`ballots`, `participation_records`, `election_results` y `cast_ballot`), guard de
cierre con pendientes/incidencias, conciliación, dos dispositivos con el mismo
votante (conflicto y apertura de incidencia), idempotencia por `operation_id` y
`get_operation_status = conflict`. Catálogo completo en `docs/pruebas.md`.

## 6. Artefactos y ejecución

```powershell
flutter build windows --release --project-directory apps/administracion_electoral
flutter build windows --release --project-directory apps/votacion_estudiantil
flutter build apk     --release --project-directory apps/votacion_estudiantil
```

| Salida | Ruta |
|---|---|
| Administración (Windows) | `apps/administracion_electoral/build/windows/x64/runner/Release/administracion_electoral.exe` |
| Votación (Windows) | `apps/votacion_estudiantil/build/windows/x64/runner/Release/votacion_estudiantil.exe` |
| Votación (Android) | `apps/votacion_estudiantil/build/app/outputs/flutter-apk/app-release.apk` |

> **Estado de las compilaciones.** La app de **administración** (Windows) se
> compiló correctamente en release, incluyendo el plugin `file_selector`
> (`file_selector_windows_plugin.dll`). Las compilaciones de **votación**
> (Windows y APK) quedan **pendientes (manual)**: requieren la cadena nativa y
> tardan varios minutos. Ambas apps traen valores por defecto del backend de
> pruebas, así que `flutter run`/`build` funcionan sin banderas.

## 7. Trabajo pendiente y límites conocidos

Se declaran abiertamente; no se ocultan.

1. **Corte de red en vivo entre dos dispositivos físicos: pendiente** (prueba
   manual de integración; el comportamiento se validó por SQL y con base en
   memoria).
2. **Compilaciones de release de votación (Windows y APK): pendientes de
   confirmar** (§6). La de **administración (Windows) ya se verificó** tras
   integrar el plugin `file_selector`.
3. **Exportación de listados del padrón: no implementada.** La **importación**
   CSV/Excel del padrón **sí** está implementada (módulo Padrón) y la exportación
   de resultados/acta (PDF/Excel) también; queda fuera la exportación de listados.
4. **Vista de tutor: implementada**, pero **requiere aprovisionamiento**: el
   usuario de Auth y su `user_profiles` se crean fuera de la app (Supabase
   Dashboard o CLI) y el tutor se asigna desde Cursos; el disparador otorga el rol
   y el ámbito. No hay alta de usuarios de personal desde el panel.
5. **Cifrado SQLCipher** de la base local: decisión abierta (ver
   `docs/decisiones_tecnicas.md`, §«Decisiones pendientes de confirmar»). El
   **PIN sí está implementado** (hash en el servidor, nunca en claro).
6. **Usuario demo** (`admin@demo.test`) y datos ficticios: solo para el proyecto
   de **pruebas**; deben eliminarse o rotarse antes de cualquier uso real.
7. **Correlación identidad↔voto** por metadatos de tiempo/orden con acceso total
   a la base: mitigada, no eliminada. Un voto por estudiante con varios
   dispositivos desconectados y padrones superpuestos no está garantizado
   globalmente.

## 8. Decisiones relevantes

El detalle está en `docs/decisiones_tecnicas.md` (D1–D20). Las más importantes
para la entrega:

- **D14**: lógica pura en `electoral_core`; **D15**: frontera de red del voto
  tras `BallotCastApi` (permite probar sin red); **D16**: cierre bloqueado por
  pendientes y re-descarga que no rehabilita el voto local; **D17**: exportación
  del acta en PDF/Excel con funciones puras y sin identidad del votante;
  **D18**: modo kiosco como bloqueo dentro de la app (sin plugins nativos);
  **D19**: informes gráficos con `KiteBarChart`/`KiteDonut` en pantalla y barras
  vectoriales dentro del PDF; **D20**: ámbito de tutor por disparador
  (`tutor_assignments` + rol) y lectura vía RPC `SECURITY DEFINER`.

## 9. Inventario de documentación

- `docs/arquitectura.md` — arquitectura y plan por etapas.
- `docs/modelo_datos.md` — esquema relacional y separación del voto.
- `docs/seguridad.md` — RLS, roles y modelo de amenazas.
- `docs/sincronizacion_offline.md` — estrategia offline-first.
- `docs/decisiones_tecnicas.md` — decisiones y sus motivos.
- `docs/backend_rpc.md` — contrato del backend (RPC y Edge Functions).
- `docs/instalacion.md` — puesta en marcha paso a paso.
- `docs/manual_administrador.md` — uso del panel.
- `docs/manual_votacion.md` — uso de la tablet.
- `docs/pruebas.md` — estrategia, catálogo y verificación.
- `docs/informe_final.md` — este informe.

## 10. Recomendaciones para pase a producción

1. Ejecutar y registrar las **compilaciones de release** de los tres artefactos.
2. Completar la prueba manual de **corte de red en vivo** entre dos dispositivos.
3. Definir el **aprovisionamiento de usuarios de personal** (incluidos tutores):
   hoy se crean fuera de la app; valorar un módulo de alta de usuarios.
4. **Rotar/eliminar** credenciales de demostración y desactivar el registro
   público en Supabase Auth.
5. Definir la **marca institucional fina** y las políticas de retención y
   respaldo.
6. Revisar los avisos de los *advisors* de Supabase (solo WARN estándar de RPC
   `SECURITY DEFINER` invocables por `authenticated`, intencional).
