# Instalación y puesta en marcha

## 1. Requisitos y versiones

| Componente | Versión probada |
|---|---|
| Flutter | 3.47.2 (stable) |
| Dart | 3.13.2 |
| Visual Studio (Desktop C++) | Community 2026 18.6 |
| Android SDK | 37.0.0 (Build-Tools/Platform) |
| Supabase CLI | 2.120.0 |
| Git | 2.48.1 |

Verificar:

```powershell
flutter --version
flutter doctor -v
supabase --version
```

### Android: aceptar licencias

```powershell
flutter doctor --android-licenses   # aceptar todas
```

## 2. Bootstrap del repositorio

```powershell
cd sistema-electoral
flutter pub get --directory apps/administracion_electoral
flutter pub get --directory apps/votacion_estudiantil
dart pub get --directory packages/electoral_core
```

## 3. Crear el proyecto Supabase

1. Entrar a <https://supabase.com> y crear un proyecto (región más cercana).
2. Anotar del dashboard: **Project URL**, **publishable key**, **secret key** y
   **Project ref**.
3. La **secret key** (equivalente a `service_role`) se usa solo en el servidor;
   no se copia a las apps.

> Este repositorio **no** ejecuta migraciones automáticamente. Debes ejecutarlas
> tú (sección 5) contra tu proyecto de **pruebas**.

## 4. Variables de entorno

Copia `.env.example` a `.env` y rellena los valores reales. En Flutter se
inyectan en compilación con `--dart-define` (no se lee `.env` dentro de la app).
Ambas apps traen **valores por defecto** (el proyecto actual) para que
`flutter run` funcione sin banderas; úsalas solo cuando quieras apuntar a otro
proyecto:

```powershell
flutter run -d windows --project-directory apps/administracion_electoral `
  --dart-define=SUPABASE_URL=https://OTRO-REF.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=OTRA_PUBLISHABLE_KEY
```

Para no repetir las banderas en cada `flutter run`, copia
`dart_defines.example.json` a `dart_defines.json` (ignorado por git) y usa el
archivo en **toda** invocación —`flutter run`, `flutter build` o depuración—:

```powershell
flutter run -d windows --project-directory apps/administracion_electoral `
  --dart-define-from-file=dart_defines.json
```

> El parámetro `--dart-define` tiene prioridad sobre el valor por defecto. Solo
> verás "falta configurar el backend" si compilas con defines **vacíos** de forma
> explícita.

## 5. Enlazar la CLI y ejecutar migraciones

```powershell
cd sistema-electoral
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase db push          # aplica supabase/migrations/ (000001 … 000013)
```

> Requisitos: `supabase login` (o `SUPABASE_ACCESS_TOKEN`) y la contraseña de la
> base cuando la CLI la pida. En Windows **no** se usa Docker ni `psql`.

### Desplegar las Edge Functions

```powershell
supabase functions deploy enroll-device --no-verify-jwt
```

> `--no-verify-jwt` porque el enrolamiento ocurre **antes** de que el dispositivo
> tenga sesión; la credencial es el código de un solo uso.

### Secretos del servidor (Edge Functions)

```powershell
supabase secrets set --project-ref TU_PROJECT_REF
```

Las variables `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` y `SUPABASE_SECRET_KEY`
las inyecta Supabase automáticamente en el runtime; no hace falta copiarlas.

### Tipos de la base para el cliente (opcional)

```powershell
supabase gen types --lang=dart --project-id TU_PROJECT_REF > tipos_supabase.dart
```

## 6. Configuración de autenticación

- Auth por email/contraseña para el personal. En Supabase → Authentication:
  desactiva el registro público de usuarios.
- Los usuarios del personal se crean por invitación o manualmente desde el panel.
- Roles: se asignan en `user_roles` con el procedimiento seguro documentado en
  `docs/seguridad.md`.

### Primer administrador (procedimiento seguro)

1. Crear el usuario en Authentication (email del responsable).
2. Insertar su fila en `user_profiles` (mismo `id` que `auth.users`).
3. Insertar su rol `admin` en `user_roles` mediante una función controlada o
   desde el SQL editor con la cuenta propietaria.
4. Nunca reutilizar contraseñas ni compartir cuentas.

### Usuario de demostración (solo proyecto de PRUEBAS)

En el proyecto de pruebas se creó un administrador ficticio para poder validar el
acceso de la app de administración:

| Campo | Valor |
|---|---|
| Email | `admin@demo.test` |
| Contraseña | `DemoAdmin123!` |
| Rol | `admin` |
| Institución | `DEMO Unidad Educativa de Pruebas` |

> ⚠️ Es una cuenta **ficticia** de un proyecto de **pruebas**. Antes de cualquier
> uso real: elimínala o cambia su contraseña, y desactiva el registro público en
> Supabase → Authentication. Nunca la uses con datos reales.

## 7. RLS

Las políticas se definen en las migraciones (Etapa 2). Verificación:

```powershell
# Prueba manual: con la anon key, intentar leer ballots debe devolver 0 filas o error.
```

## 8. Ejecutar las aplicaciones

```powershell
# Administración (Windows). Las variables ya tienen valores por defecto (sección 4),
# así que `flutter run` funciona sin banderas; usa --dart-define para cambiarlas.
flutter run -d windows --project-directory apps/administracion_electoral

# Votación (Windows)
flutter run -d windows --project-directory apps/votacion_estudiantil

# Votación (Android, emulador)
flutter emulators --launch Small_Tablet
flutter run -d emulator-5554 --project-directory apps/votacion_estudiantil
```

> Para apuntar a **otro** proyecto Supabase, pasa
> `--dart-define-from-file=dart_defines.json` (o `--dart-define=...`) desde la
> carpeta de la app o con `--project-directory`.

## 9. Compilar entregables

```powershell
# Ejecutable/instalador de Windows (administración)
flutter build windows --release --project-directory apps/administracion_electoral

# Ejecutable de Windows (votación, además del APK)
flutter build windows --release --project-directory apps/votacion_estudiantil

# APK de Android (votación)
flutter build apk --release --project-directory apps/votacion_estudiantil
# (o appbundle para Play Store: flutter build appbundle ...)
```

Artefactos resultantes (relativos a la carpeta de cada app):

| Salida | Ruta |
|---|---|
| Administración (Windows) | `apps/administracion_electoral/build/windows/x64/runner/Release/administracion_electoral.exe` |
| Votación (Windows) | `apps/votacion_estudiantil/build/windows/x64/runner/Release/votacion_estudiantil.exe` |
| Votación (Android) | `apps/votacion_estudiantil/build/app/outputs/flutter-apk/app-release.apk` |

> El `.exe` de Windows necesita los `.dll` y la carpeta `data/` que lo acompañan
> en la misma carpeta `Release/`; distribuye la carpeta completa, no solo el
> ejecutable.

## 10. Configuración inicial de tablets y autorización de dispositivos

1. Instalar el APK en la tablet.
2. En administración → **Dispositivos**, registrar el dispositivo y generar un
   **código de emparejamiento** de un solo uso.
3. En la tablet, canjear el código (Edge Function de enrolamiento). El
   dispositivo recibe credenciales propias y queda `authorized`.
4. Asignar el dispositivo a una elección y mesa.
5. **Revocar** un dispositivo: cambiar su estado a `revoked`; deja de aceptar
   operaciones aunque conserve el token.

## 11. Operación sin conexión, sincronización y conflictos

Ver `docs/sincronizacion_offline.md` y `docs/manual_votacion.md`. La
administración revisa, en **Sincronización**, las operaciones pendientes,
duplicados y conflictos, y resuelve cada uno con trazabilidad.

## 12. Cierre de jornada y actas

El cierre y la consolidación de resultados se realizan en administración →
**Elecciones** y **Resultados**, solo cuando se cumplen las condiciones
(dispositivos sincronizados y conflictos resueltos). La app muestra resultados y
resultados congelados del archivo en pantalla.

**Exportación de actas/resultados.** Desde **Resultados** (elección cerrada) y
desde el detalle de una elección en **Archivo** puedes generar:

- **Acta (PDF)**: encabezado institucional, escrutinio por lista, blancos,
  nulos, totales, participación y firmas de la junta receptora.
- **Resultados (Excel, `.xlsx`)**: la misma información en hoja de cálculo.

Ambos abren el diálogo nativo **Guardar como**. El acta contiene **solo
agregados**: no incluye la identidad de los votantes.

## 13. Copias de seguridad y recuperación

- El plan gratuito de Supabase tiene retención limitada; **no** asumas respaldos
  automáticos completos ni recuperación a un punto en el tiempo.
- Exporta periódicamente con `pg_dump` usando la cadena de conexión de la base
  (Project Settings → Database) y guarda los archivos fuera de la plataforma.
- Para resultados y actas, exporta además en PDF/Excel y consérvalos como archivo
  institucional.
- **Restaurar**: solo en un proyecto/destino controlado y con confirmación
  explícita; nunca sobre datos reales de una jornada en curso.

## 14. Límites del plan gratuito y costos

- Los límites (base de datos, ancho de banda, funciones Edge, almacenamiento,
  inactividad) **cambian**; consulta la página de precios vigente de Supabase
  antes de comprometerte.
- No existe garantía de gratuidad permanente. Documenta el plan contratado y sus
  cuotas al momento de la implementación.
- Este proyecto está diseñado para funcionar en el plan gratuito en su uso
  básico, pero eso **no** se promete a perpetuidad.
