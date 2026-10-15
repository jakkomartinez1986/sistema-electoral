# Sincronización offline-first

## 1. Objetivo

La aplicación de votación debe permitir emitir votos aunque se caiga Internet
durante la jornada, sin perder ni duplicar operaciones, y sin presentar
garantías que no puede ofrecer.

## 2. Arquitectura local (SQLite)

Base local tipada con `drift`. Tablas principales:

| Tabla local | Contenido |
|---|---|
| `local_voters` | Padrón asignado a **este** dispositivo (identidad mínima necesaria) |
| `local_lists` / `local_candidates` | Oferta electoral descargada |
| `local_config` | Elección, mesa, versión de configuración, hash, último sync |
| `outbox` | Cola persistente de operaciones pendientes |
| `participation_local` | Marca local de participación (para evitar doble voto local) |
| `sync_log` | Resultado de cada intento (éxito, error, conflicto) |

Este esquema ya está implementado en `apps/votacion_estudiantil/lib/core/offline/`
(`app_database.dart`, drift). En la Etapa 4 (S1) se usaban `local_config`,
`local_lists`, `local_candidates` y `local_voters` (padrón descargado en la
provisión); el flujo de votación ya activa `outbox`, `participation_local` y
`sync_log`. El **cifrado en reposo** de la copia local
(`flutter_secure_storage`/SQLCipher) queda pendiente y se documenta en
`docs/decisiones_tecnicas.md`.

## 3. Registro de un voto (transacción atómica local)

Una única transacción SQLite:

1. Verifica que el votante está en el padrón local, habilitado y no marcado.
2. Inserta la marca de participación local (`participation_local`).
3. Encola la operación en `outbox` con:
   - `operation_id` (UUID aleatorio, único, clave primaria),
   - `voter_ref` (opaco), `option_type` (lista/blanco/nulo), `candidate_list_id`
     (solo para lista), `ballot_id` (aleatorio),
   - estado `pending`, `attempts = 0` y marcas `created_at` / `updated_at`.

El dispositivo, la elección, la mesa y la versión de configuración **no** se
duplican por fila: se toman de `local_config` en el momento del envío. Así el
contenido del voto no arrastra identidad y la separación se resuelve en el
backend (`cast_ballot`).

Si la transacción falla, no queda ni participación ni operación: no hay estados
intermedios.

## 4. Cola y estados

```
pending ──(red ok)──► sending ──accepted──► done
   ▲                     │
   │                     ├──rejected──► rejected   (error controlado del servidor)
   │                     ├──conflict──► conflict   (requiere revisión)
   └─────(sin red)────────┘
```

- **Estados visibles**: pendiente, sincronizando, sincronizado, error,
  conflicto.
- Los registros **no se borran** hasta que el servidor confirma la operación y
  el estado queda persistido verificablemente.

## 5. Idempotencia y recuperación de red

- El servidor deduplica por `operation_id` (ver `docs/modelo_datos.md`).
- Si se pierde la respuesta de red, **no** se asume fallo: se consulta el estado
  de la operación por su UUID (`get_operation_status`) antes de reenviar.
- Reenviar el mismo UUID no duplica nada.

## 6. Reintentos

- Backoff exponencial con jitter determinista por operación
  (`OutboxSender`: base 5 s, tope 5 min, máximo 8 intentos).
- Se reintenta al: recuperar la conexión, abrir la aplicación, **tras registrar
  cada voto** (envío oportunista sin bloquear el flujo) y por acción manual
  autorizada del operador (botón **Sincronizar ahora**, que ignora el backoff).
- El controlador de sincronización evita dos pasadas simultáneas.
- Los fallos persistentes quedan en `sync_log` y se muestran como error.

## 7. Recuperación tras reinicio

- La `outbox` y las tablas locales persisten en disco.
- Al abrir, la app restaura la cola y reintenta lo pendiente.
- La pantalla de estado muestra pendientes, último sync y errores.

## 8. Límites del modo offline (importante)

Varios dispositivos **completamente desconectados** no pueden saber en tiempo
real si otro dispositivo ya registró al mismo estudiante. Por eso:

- Cada dispositivo recibe una **mesa o conjunto exclusivo** de estudiantes.
- Se **impide** repartir el mismo padrón simultáneamente entre dispositivos
  desconectados sin un mecanismo de coordinación.
- Al sincronizar se **detectan duplicados** y conflictos; lo conflictivo no se
  acepta en silencio.
- Una elección **no** se presenta como cerrada/consolidada mientras existan
  dispositivos con operaciones pendientes. Esto lo **impone el backend**:
  `transition_election` rechaza el paso a `closing`/`closed` con
  `cannot_close_with_pending_operations` (hay operaciones `pending`) o
  `cannot_close_with_unresolved_incidents` (hay incidencias `open`/`reviewing`),
  y la elección permanece en su estado anterior. La administración refleja esta
  condición con `election_reconciliation` y bloquea el cierre en la interfaz.
- Se registran incidentes y se generan reportes de conciliación. Una incidencia
  se resuelve (o descarta) desde el módulo de sincronización; solo entonces el
  cierre deja de estar bloqueado.

**No se afirma** que exista una garantía global de un solo voto por estudiante
mientras haya varios dispositivos operando desconectados con padrones
superpuestos. Ver el marco de conciliación en `docs/pruebas.md`.

## 9. Votos locales anteriores al cierre, sincronizados después

Política (configurable por normativa institucional, ver
`docs/decisiones_tecnicas.md`):

- Votos registrados localmente **antes** de la hora de cierre pero sincronizados
  **después**: se aceptan **solo** si la política de cierre lo permite y el
  servidor puede verificar el instante local de forma razonable.
- Cuando la información disponible no permite verificarlo con seguridad, la
  operación pasa a **revisión manual** y no se consolida automáticamente.
- Nunca se acepta automáticamente cualquier voto llegado tras el cierre.
