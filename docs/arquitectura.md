# Arquitectura

## 1. Visión general

Dos aplicaciones Flutter con responsabilidades separadas comparten un backend
Supabase (PostgreSQL) y un paquete de código común.

```
                         ┌───────────────────────────┐
                         │        Supabase           │
                         │  PostgreSQL + RLS         │
                         │  Auth (personal)          │
                         │  RPC SECURITY DEFINER     │
                         │  Edge Functions (Deno)    │
                         └─────────────┬─────────────┘
                PostgREST/RPC (HTTPS)  │  HTTPS (enrolamiento)
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
┌───────┴────────┐            ┌────────┴─────────┐          ┌─────────┴────────┐
│ Administración │            │    Votación      │          │    Votación      │
│ Windows        │            │ tablets Android  │   ...    │ Windows          │
│ (online)       │            │ (offline-first)  │          │ (offline-first)  │
└───────┬────────┘            └────────┬─────────┘          └──────────────────┘
        │                              │
        └──────────┬───────────────────┘
                   │
        ┌──────────┴──────────┐
        │  packages/          │
        │   electoral_core    │  modelos, validaciones, constantes, formatos
        │   kite_ui           │  capa de UI (template Kite, MIT)
        └─────────────────────┘
```

## 2. Organización del repositorio

```
sistema-electoral/
├── apps/
│   ├── administracion_electoral/   # Flutter Windows
│   └── votacion_estudiantil/       # Flutter Android + Windows
├── packages/
│   ├── electoral_core/             # Dart puro: dominio compartido
│   └── kite_ui/                    # UI vendorizada (MIT)
├── supabase/
│   ├── migrations/                 # migraciones SQL versionadas
│   ├── functions/                  # Edge Functions (Deno)
│   ├── seed.sql                    # datos ficticios de demostración
│   └── config.toml                 # configuración de la CLI
├── docs/
├── .env.example
├── .gitignore
└── README.md
```

La organización del código de cada app es **por funcionalidad** (feature-first)
con separación en capas:

```
lib/
├── main.dart
├── app.dart                    # raíz (ShadApp + router)
├── core/                       # infraestructura transversal
│   ├── auth/                   # sesión del personal
│   ├── config/                 # configuración y variables de entorno
│   ├── data/                   # DataProvider (PostgREST) / repositorios
│   ├── offline/                # SQLite (drift), outbox, motor de sync
│   ├── router/                 # go_router
│   └── theme/                  # tema institucional
├── features/<modulo>/          # una carpeta por módulo funcional
└── shared/                     # widgets y utilidades reutilizables
```

Regla de dependencias: `presentation → application → domain → data`. La
presentación nunca habla directamente con la red ni con la base local.

## 3. Decisiones de stack

| Área | Elección | Motivo |
|---|---|---|
| UI | `kite_ui` (template Kite, shadcn_ui) | Ya probado en esta máquina; MIT; tabla de datos y gráficos incluidos |
| Estado | `flutter_riverpod` ^3 | Usado por Kite; sin codegen; mantenible |
| Navegación | `go_router` ^18 | Guardas de sesión y navegación anidada |
| Base local | `drift` + `sqlite3_flutter_libs` | SQLite tipado, transaccional, Android y Windows |
| Secretos locales | `flutter_secure_storage` | Keystore/DPAPI para tokens de dispositivo |
| Backend | Supabase (Postgres + PostgREST + RPC + Edge Functions) | Requisito; sin servidor propio |
| Migraciones | Supabase CLI + SQL | Requisito |

## 4. Límite crítico: operaciones privilegiadas

Ninguna app Flutter contiene la `service_role`. Las operaciones que requieren
privilegios elevados se ejecutan en el servidor:

- **Voto y participación** → función PostgreSQL `SECURITY DEFINER` (`cast_ballot`)
  con `search_path` fijo y permisos de ejecución mínimos.
- **Alta de dispositivos** → Edge Function que usa `service_role` solo del lado
  servidor y entrega credenciales propias al dispositivo.

Ver `docs/seguridad.md`.

## 5. Plan por etapas

- **Etapa 1 — Inspección y diseño.** ✅ Completada (este documento).
- **Etapa 2 — Backend.** ✅ Migraciones, tablas, roles, RLS, funciones seguras,
  datos ficticios y pruebas de integridad/seguridad.
- **Etapa 3 — Administración.** ✅ Completada. Conectada la autenticación del
  personal (Supabase Auth), el panel con contadores reales según RLS y los diez
  módulos A–J (institución, cursos y mesas, padrón, listas, elecciones,
  dispositivos, sincronización, resultados y archivo). Incluye la exportación de
  resultados y del acta en PDF/Excel (Etapa 6).
- **Etapa 4 — Votación.** ✅ Cerrada. Implementados el emparejamiento del
  dispositivo con código de un solo uso (sin cámara) y la **descarga y
  verificación** de la configuración y el padrón (`get_device_bundle`) con
  persistencia local transaccional (drift/SQLite). Flujo de votación completo:
  identificación del votante contra el padrón local (cédula o código+PIN),
  papeleta neutral (lista/blanco/nulo), **registro transaccional** local y
  **outbox** con reintentos, idempotencia y pantalla de comprobante neutra.
- **Etapa 5 — Integración.** ✅ Cerrada. Añadido el **guard de cierre**
  (`transition_election` rechaza `closing`/`closed` con operaciones `pending` o
  incidencias sin resolver) y la función de conciliación
  `election_reconciliation`, con su panel en el módulo de elecciones. Verificadas
  contra el backend de pruebas la separación del voto, RLS para `anon`, el ciclo
  de cierre y el escenario de dos dispositivos (duplicados, idempotencia y
  conflictos). Se corrigió además un fallo en `applyBundle` que rehabilitaba el
  voto local al re-descargar la configuración. Queda como prueba manual el corte
  de red en vivo entre dos dispositivos físicos.
- **Etapa 6 — Entrega.** 🟡 En curso. Análisis estático limpio
  (`dart analyze`/`flutter analyze`), suites en verde (30 + 25 + 17 pruebas) y
  artefactos de Windows y Android. Añadidos la **importación del padrón**
  (CSV/Excel), el **PIN de votación** en el padrón, los **informes gráficos** de
  resultados y la **vista de tutor** (ámbito por disparador + RPC). Modo kiosco
  (bloqueo del equipo durante la votación). Documentación de cierre e informe
  final.

## 6. Identidad visual

Azul principal, rojo de acento (reservado para acciones sensibles), fondos
claros y alto contraste. La administración usa **barra superior** como
navegación principal (sin barra lateral permanente). La papeleta de votación es
neutra y con objetivos táctiles amplios.
