# Manual del administrador

Aplicación de escritorio (Windows) para el personal autorizado. Requiere
conexión a Internet para las operaciones de gestión.

## 1. Inicio de sesión

1. Abrir la aplicación.
2. Introducir email y contraseña del personal autorizado.
3. La sesión se mantiene de forma segura; cerrar sesión al terminar.

> El inicio de sesión real (Supabase Auth) y los módulos A–J están disponibles
> desde la Etapa 3.

## 2. Navegación

La navegación principal es una **barra superior** con los módulos: Panel,
Institución, Cursos y mesas, Padrón, Listas, Elecciones, Dispositivos,
Sincronización, Resultados y Archivo. Cada módulo opera bajo RLS: solo se ve y
se modifica lo que el rol del personal autoriza para su institución.

## 3. Módulos

### Panel principal
Resumen: elecciones del año lectivo, estados, cursos y estudiantes habilitados,
listas registradas, participación acumulada disponible, dispositivos autorizados
y pendientes, incidencias y última sincronización. **No revela votos ni
resultados mientras la elección esté abierta.**

### Institución y períodos electorales
Configura nombre de la institución, año lectivo, período, nombre y descripción de
la elección, normativa, fechas/horas de inicio y cierre, zona horaria
institucional, estado, responsables autorizados, observaciones y actas.

### Cursos y mesas
Crea grados/cursos, paralelos y tutores; crea mesas; asigna estudiantes y
dispositivos a cada mesa; valida duplicados y datos incompletos. Al asignar un
**tutor** a un curso, el sistema registra su ámbito y le otorga el rol `tutor`
automáticamente (ver §«Rol de tutor»). Un padrón incompatible entre mesas requiere
advertencia y autorización documentadas.

### Padrón estudiantil
Registra y edita estudiantes (datos permitidos), **importa desde CSV/Excel**,
filtra por año/grado/curso/paralelo, activa o desactiva la habilitación electoral,
valida identificadores duplicados y genera un informe de inconsistencias
**antes** de abrir. Nunca muestra el voto del estudiante. Permite además fijar o
limpiar el **PIN de votación** del estudiante (se guarda solo su hash; ver
`docs/backend_rpc.md`, `set_student_pin`).

**Importar padrón.** El botón **Importar** abre un asistente: se elige un archivo
`.csv` o `.xlsx`, la aplicación detecta las columnas (código, apellidos, nombres,
cédula, mesa, PIN, fecha de nacimiento, estado, habilitado) y muestra una
**previsualización** con las filas válidas y los problemas detectados (código o
nombre faltantes, PIN fuera de rango, mesa inexistente, etc.). Al confirmar, el
lote se envía al backend (`import_election_padron`), que da de alta o actualiza a
cada estudiante, lo inscribe en el padrón de la elección y fija su PIN si viene.
El resumen indica cuántos se crearon, actualizaron e inscribieron, y el detalle de
los errores por fila. **Solo se puede importar mientras la elección está en
borrador o lista**; una vez abierta, el padrón queda bloqueado (`padron_locked`).

**PIN de votación.** En la ficha del estudiante, la sección «PIN de votación»
permite **fijar** un PIN de 4–8 dígitos o **quitar** el existente; muestra si ya
hay un PIN definido. El PIN nunca se guarda en claro: solo su hash.

### Listas y candidatos
Cantidad de listas **variable**. Crea/edita listas (número, nombre, lema,
distintivo), candidatos (nombre, cargo, orden), integrantes; valida datos
requeridos; activa/desactiva una lista antes de abrir; vista previa de la
papeleta. Al abrir la elección, la oferta queda **congelada**.

### Gestión de elecciones
Crea una elección, copia una configuración anterior (**sin** votos ni
participación), selecciona año/padrón/cursos/mesas/listas, valida requisitos
antes de abrir, genera vista previa, autoriza dispositivos y abre/cierra la
jornada con confirmación y auditoría. La modificación del reloj de una tablet no
reabre una elección cerrada.

### Dispositivos
Registra y autoriza dispositivos, los asigna a elección y mesa, revoca su
autorización, muestra identificador/estado/última sincronización, consulta
versión y configuración descargada, revisa pendientes y errores, registra
incidentes y solicita resincronización. Un dispositivo revocado no acepta nuevas
operaciones.

### Sincronización y conciliación
Muestra votos recibidos por dispositivo (sin identidades), participación por
curso/mesa, operaciones pendientes/aceptadas/rechazadas, duplicados, errores de
configuración, dispositivos sin sincronizar e incidencias. Cada conflicto tiene
explicación, estado y procedimiento de resolución auditado.

### Resultados
Solo con la elección **cerrada** y dispositivos sincronizados/conciliados:
totales por lista, blancos, nulos, válidos según normativa, porcentajes,
**informe gráfico** (dona del reparto y barras de votos por lista), participación
por curso/mesa, acta de resultados y exportación a PDF y Excel. El botón
**Exportar acta (PDF)** genera el acta con el escrutinio, los totales, un
**gráfico de barras** y las firmas de la junta receptora; **Exportar resultados
(Excel)** genera la hoja de cálculo equivalente. En ambos casos se abre el
diálogo nativo de **Guardar como**. Los informes distinguen participación, votos
emitidos, válidos, blancos y nulos, y se concilian con las operaciones aceptadas.
La misma exportación está disponible desde el detalle de una elección archivada
(módulo Archivo).

### Archivo anual
Gestiona elecciones por año lectivo: nueva elección por ciclo, anteriores en
modo histórico (resultados, actas, auditoría), copia opcional de configuración
sin duplicar votos, exportación de un archivo completo de la elección y política
de conservación/eliminación de datos personales con confirmación y autorización.

### Rol de tutor (acceso restringido)
Un usuario con rol **`tutor`** y **sin** rol de administración u operador no ve el
panel: al entrar va directo a **Mi área como tutor**, una vista de **solo
lectura** con sus cursos asignados y los estudiantes de las mesas de esos cursos
(nombre, código, cédula, mesa, elección y habilitación). No puede crear ni editar.

El ámbito se gobierna en el backend: al asignar el tutor de un curso (módulo
Cursos y mesas) se registra su ámbito y se le concede el rol; la vista solo
recibe los cursos y estudiantes que le corresponden. Un usuario **admin** u
**operator** que además sea tutor de un curso sigue viendo el panel completo.

> **Aprovisionamiento.** Crear la cuenta de un tutor (usuario de Auth y su perfil
> de personal) se hace fuera de la aplicación, con la CLI o el panel de Supabase
> (ver `docs/instalacion.md`). Después, asígnale el curso desde Cursos y mesas:
> el resto es automático.

> **Estado (Etapa 6).** Los diez módulos operan contra el backend: alta y
> edición de institución, años lectivos, cursos, mesas, padrón, listas y
> candidatos; ciclo de vida de la elección con transiciones auditadas y
> generación de configuración; autorización de dispositivos con código de
> emparejamiento; conciliación de sincronización con resolución de incidencias;
> resultados agregados al cerrar con **informe gráfico**; archivo histórico con
> auditoría; **exportación de resultados y acta en PDF/Excel** desde Resultados y
> Archivo; **importación del padrón (CSV/Excel)** y **PIN de votación**; y
> **vista de solo lectura para tutores**. Quedan pendientes la exportación de
> listados del padrón y la copia de configuración entre años.

## 4. Operaciones sensibles

Apertura/cierre, cancelación, revocación de dispositivos, resolución de
conflictos, publicación de resultados y eliminación de datos requieren
**diálogo de confirmación** y quedan **auditadas**.
