# Manual de votación

Aplicación para tablets Android (y Windows). Interfaz sencilla, táctil y neutral.

## 1. Antes de la jornada (operador)

1. Verificar que el dispositivo fue **autorizado** por un administrador y está
   asignado a la elección y mesa correctas.
2. Con conexión, abrir la aplicación para **descargar y verificar** la
   configuración electoral y el padrón asignado a este dispositivo.
3. Comprobar en pantalla el estado: institución, elección, mesa, hora de la
   jornada, última sincronización y operaciones pendientes.
4. Confirmar que la configuración **no está vencida**. Si lo está, advertir y
   resincronizar antes de abrir.

> Un dispositivo **no** se autoriza a sí mismo: la autorización siempre procede
> de un administrador.

## 2. Estado del dispositivo

- **No autorizado**: no se puede votar; muestra el identificador del equipo y el
  campo para digitar el código de emparejamiento.
- **Autorizado, sin configurar**: debe descargar la configuración y el padrón
  (sección 2.2) antes de habilitar la votación.
- **Autorizado y configurado**: listo para votar.
- **Configuración desactualizada o elección cerrada**: la votación se bloquea y
  se avisa al operador.

### 2.1 Emparejamiento por código (sin cámara)

En Windows (y como alternativa al QR en Android) el emparejamiento se hace
digitando un código de un solo uso; la seguridad es la misma: el código lo emite
el servidor y solo lo consume el dispositivo registrado.

1. El operador abre la app de votación: esta muestra su **identificador de
   equipo** (por ejemplo `DEV-1A2B3C4D5E6F`).
2. En Administración → **Dispositivos**, el administrador registra ese
   identificador y genera un **código de emparejamiento** (12 caracteres
   hexadecimales, vence en pocos minutos y es de un solo uso).
3. El operador digita el código en la tablet y confirma. La app lo canjea contra
   la Edge Function `enroll-device`, obtiene su credencial propia y marca el
   dispositivo como **autorizado**.
4. Si el código no coincide con el identificador registrado, el servidor lo
   rechaza. El código nunca se guarda en claro ni puede reutilizarse.

### 2.2 Descarga de configuración y padrón

Después del emparejamiento, la app queda **autorizada pero sin configurar**.
Con conexión, el operador pulsa **Descargar configuración y padrón**:

1. La app llama al RPC `get_device_bundle()`; el servidor deriva el dispositivo de
   la propia sesión (el cliente nunca envía su identificador) y devuelve la
   elección, las listas y candidatos habilitados, y el padrón de la mesa
   asignada con sus verificadores.
2. La app **verifica** el paquete (coherencia de listas/candidatos, padrón de la
   mesa correcta) y lo **guarda** en SQLite local de forma **atómica**
   (transacción): la configuración anterior solo se reemplaza si el paquete es
   válido.
3. La pantalla muestra: institución, elección y estado, mesa, número de listas,
   candidatos y votantes, **versión y hash** de la configuración y la fecha/hora
   de la descarga.
4. Mientras no haya un paquete válido guardado, la votación permanece bloqueada.

> El padrón local **no** guarda nombres ni cédulas en claro: solo referencias
> opacas (`voter_ref`) y verificadores derivados (hash con sal de la institución)
> para cédula y/o PIN. Con la configuración y el padrón descargados, el equipo
> queda listo para votar **sin conexión**. Ver `docs/sincronizacion_offline.md`.

Con los datos de demostración, los estudiantes `DEMO-001`…`DEMO-009` tienen PIN
`1234`, y `DEMO-001` también responde a la cédula `1710034065`.

Con la configuración lista, la pantalla muestra además una tarjeta de
**sincronización** con las operaciones pendientes y el botón **Sincronizar
ahora**, y habilita el botón **Comenzar a votar** solo si la elección está
abierta.

## 3. Flujo de votación

Desde la pantalla del dispositivo configurado, el operador pulsa **Comenzar a
votar** (habilitado solo si la elección está **abierta**). El flujo tiene cuatro
pantallas:

1. **Identificación** (`/identificacion`): el estudiante elige cómo acreditarse,
   **cédula ecuatoriana** o **código estudiantil + PIN** (según lo habilitado por
   la institución). La app comprueba los verificadores contra el padrón local y
   avisa si el estudiante no pertenece a este equipo o **ya participó** aquí.
2. **Papeleta** (`/papeleta`): se muestran las listas habilitadas (número, nombre,
   distintivo, integrantes). Las opciones son: **votar por una lista**, **voto en
   blanco** o **voto nulo**.
3. **Confirmación** (`/confirmacion`): resume la opción elegida y pide una
   confirmación explícita. La selección no se revela a terceros innecesariamente.
4. **Comprobante** (`/recibo`): confirmación **neutra** de que el voto fue
   recibido localmente (no muestra la opción ni resultados parciales). Al pulsar
   **Listo** el equipo queda listo para el siguiente votante.

En cada paso, al confirmar:

- El voto se **registra** en una transacción atómica local (participación +
  operación encolada).
- La **participación** se marca por separado del contenido del voto.
- El registro queda **preparado para sincronización** cuando haya conexión.

Después de confirmar, el estudiante **no puede cambiar** su voto, salvo un
procedimiento institucional documentado aplicado antes de cerrar la urna.

> Durante la jornada **no** se muestran resultados parciales.

### 3.1 Modo kiosco (bloqueo del equipo)

Al pulsar **Comenzar a votar**, la app entra en **modo kiosco**: el equipo queda
"atado" al flujo de votación hasta que el personal lo libere.

- Se ocultan las barras del sistema (Android) para una pantalla limpia.
- El botón/gesto de **atrás** queda bloqueado: el votante no puede abandonar el
  flujo por accidente y la barra superior de la app no ofrece flecha de regreso.
- La navegación **interna** del flujo sigue disponible (por ejemplo, **Volver a la
  papeleta** desde la confirmación).

Para que el personal **salga** del modo kiosco: **mantener pulsado el encabezado**
(nombre de la institución o mesa) —o, en las demás pantallas, el título superior—
y **confirmar** la salida. El equipo se desbloquea y vuelve a la pantalla de
configuración, donde puede sincronizar o retirar el equipo.

> El modo kiosco es un bloqueo **dentro de la aplicación**: no impide que alguien
> use los botones físicos de inicio/ajustes del sistema operativo. El bloqueo a
> nivel de dispositivo (pantalla fijada en Android / Assigned Access en Windows)
> se configura al preparar el equipo, fuera de la aplicación. Ver
> `docs/instalacion.md`.

## 4. Funcionamiento sin Internet

- Los votos se guardan localmente (SQLite) con transacción atómica.
- Una **cola persistente** reenvía las operaciones al recuperar conexión, al
  abrir la app o por acción manual autorizada.
- Estados visibles: pendiente, sincronizando, sincronizado, error, conflicto.
- Reiniciar o cerrar la app **no** pierde operaciones pendientes.
- Un error de red **no** se interpreta como voto perdido: se consulta el estado
  por el identificador de la operación.

## 5. Límites del modo offline

Con varios dispositivos desconectados cuyos padrones se solapan, **no hay
garantía global** de un solo voto por estudiante en el momento. Por eso cada
dispositivo usa una mesa o conjunto exclusivo de estudiantes. Los duplicados se
detectan al sincronizar y **no se aceptan en silencio**; una elección no se
considera consolidada mientras queden dispositivos pendientes. Ver
`docs/sincronizacion_offline.md`.

## 6. Cierre del dispositivo

Al terminar la jornada, salir del modo kiosco (mantener pulsado el encabezado y
confirmar), mantener la app abierta con conexión hasta que la cola quede
sincronizada, o seguir el procedimiento de cierre indicado por el administrador.
