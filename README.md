# Sistema Electoral Estudiantil

Sistema de votación y administración electoral para una institución educativa
de Ecuador. Dos aplicaciones Flutter independientes sobre un mismo backend
Supabase:

| Aplicación | Ruta | Plataformas |
|---|---|---|
| **Administración Electoral** | `apps/administracion_electoral` | Windows |
| **Votación Estudiantil** | `apps/votacion_estudiantil` | Android y Windows |
| **Núcleo compartido** | `packages/electoral_core` | Dart puro |
| **UI (template Kite)** | `packages/kite_ui` | Flutter (MIT) |

> Estado: **Etapa 6 — Entrega en curso**. El backend (Etapa 2) está completo:
> migraciones `000001`–`000015`, RLS y RPC, Edge Function `enroll-device` y datos
> ficticios de demostración. La app de **administración** (Etapa 3) se conecta al
> backend (acceso del personal con Supabase Auth y panel con contadores reales
> según RLS), con exportación de resultados y del acta en PDF/Excel, importación
> del padrón desde CSV/Excel, gestión del PIN de votación e informes gráficos de
> resultados. La app de **votación** (Etapa 4) enrolla el dispositivo con código
> de un solo uso, descarga y verifica la configuración y el padrón, y ejecuta el
> flujo de votación **offline-first**: identificación por cédula o código+PIN,
> papeleta (lista/blanco/nulo), registro transaccional local y outbox con
> reintentos e idempotencia, con **modo kiosco** que bloquea el equipo durante la
> votación. En la **integración** (Etapa 5) el cierre queda
> bloqueado mientras haya operaciones pendientes o incidencias sin resolver, con
> panel de conciliación en administración. Un usuario con rol **tutor** accede a
> una vista de solo lectura de sus cursos y estudiantes. La **entrega** (Etapa 6)
> fija análisis estático limpio, suites de pruebas en verde y los artefactos
> (Windows/APK). Ver `docs/backend_rpc.md` para el contrato del backend,
> `docs/decisiones_tecnicas.md` para el detalle, `docs/informe_final.md` para el
> cierre del proyecto y `docs/arquitectura.md` para el plan de etapas.

## Requisitos

- Flutter 3.47+ y Dart 3.13+ (probado con Flutter 3.47.2 / Dart 3.13.2).
- Visual Studio con "Desktop development with C++" (para Windows).
- Android SDK (para el APK de la tablet). Aceptar licencias:
  `flutter doctor --android-licenses`.
- Supabase CLI 2.x.
- Git.

## Arranque rápido

Ambas apps traen **valores por defecto** (el proyecto Supabase actual), así que
`flutter run` funciona sin banderas. Para apuntar a **otro** proyecto, inyecta las
variables con `--dart-define` (o `--dart-define-from-file=dart_defines.json`):

```powershell
# Votación (Windows)
flutter run -d windows --project-directory apps/votacion_estudiantil

# Votación (Android, emulador Small Tablet)
flutter run -d emulator-5554 --project-directory apps/votacion_estudiantil

# Administración (Windows)
flutter run -d windows --project-directory apps/administracion_electoral
```

El acceso a la administración requiere una cuenta de personal creada por un
administrador (ver `docs/instalacion.md` §6). La app de votación muestra el
**emparejamiento por código de un solo uso** hasta que el dispositivo sea
autorizado por un administrador; después descarga la configuración y el padrón y
habilita la votación. Para apuntar a otro proyecto Supabase, usa
`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`.

## Documentación

- [`docs/arquitectura.md`](docs/arquitectura.md) — arquitectura y plan por etapas.
- [`docs/modelo_datos.md`](docs/modelo_datos.md) — esquema relacional y separación del voto.
- [`docs/seguridad.md`](docs/seguridad.md) — RLS, roles y modelo de amenazas.
- [`docs/sincronizacion_offline.md`](docs/sincronizacion_offline.md) — estrategia offline-first.
- [`docs/decisiones_tecnicas.md`](docs/decisiones_tecnicas.md) — decisiones y sus motivos.
- [`docs/instalacion.md`](docs/instalacion.md) — puesta en marcha paso a paso.
- [`docs/manual_administrador.md`](docs/manual_administrador.md) — uso del panel.
- [`docs/manual_votacion.md`](docs/manual_votacion.md) — uso de la tablet.
- [`docs/pruebas.md`](docs/pruebas.md) — estrategia y escenarios de prueba.
- [`docs/informe_final.md`](docs/informe_final.md) — cierre de la entrega y verificación final.

## Licencia

El paquete `packages/kite_ui` es el template **Kite** de Colorlib, con licencia
MIT (ver `packages/kite_ui/LICENSE`). El resto del código es del proyecto.
