# Informe Técnico — LAB-02: Trazabilidad en MongoDB Community

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Correo institucional:** a.torres23@info.uas.edu.mx
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** III — Auditoría, trazabilidad y gobierno práctico de datos
- **Temas:** 3.1 Auditoría de bases de datos · 3.2 Bitácoras y trazabilidad
- **Motor:** MongoDB 7.0.48 Community Edition (`mongosh 2.14.2` en Ubuntu 24.04 LTS)

---

## 1. Despliegue, Edición y Limitación

El servidor se desplegó en **Ubuntu 24.04 LTS (WSL2)** mediante los paquetes oficiales `mongodb-org-server` (`7.0.48`) y `mongodb-mongosh` (`2.14.2`), configurando `/etc/mongod.conf` con `security.authorization: enabled`. Desde `mongosh`, se verificó la edición y configuración real de arranque (Actividad 1, [evidencias/01-edicion-y-limitacion.md](./evidencias/01-edicion-y-limitacion.md)):
- **`db.version()`:** `7.0.48`
- **`db.adminCommand({ buildInfo: 1 }).modules`:** `[]` (arreglo vacío). En MongoDB Enterprise este campo contiene `"enterprise"`.
- **Qué no existe en Community Edition:** MongoDB Community **no incluye el subsistema de auditoría nativa (`auditLog` / `--auditDestination`)**, el cual es exclusivo de MongoDB Enterprise Advanced y MongoDB Atlas (clústeres M10 o superiores). Por ello, en Community no existen registros nativos de seguridad para cambios de privilegios (`grantRolesToUser`, `revokeRolesFromUser`), eventos DDL de auditoría ni flujos dedicados de auditoría CRUD hacia `syslog`/JSON/BSON.

---

## 2. Perfilador (*Database Profiler*)

### 2.1 Configuración e interpretación
El perfilador es una herramienta diseñada para **diagnóstico de desempeño**, no para auditoría de seguridad. En la **Actividad 2** se comprobó que por defecto viene apagado (`was: 0`), por lo que el primer cambio del RFC de María García (`_id: 3` a `"GAMA780912XXX"`) no dejó ningún documento en `comercial.system.profile` (`countDocuments() = 0`) ni rastro del comando en la bitácora del servidor ([evidencias/02-incidente-sin-perfilado.md](./evidencias/02-incidente-sin-perfilado.md)).

En la **Actividad 3** ([evidencias/03-perfilador.md](./evidencias/03-perfilador.md)), al activar `db.setProfilingLevel(2)` sobre la base `comercial`, `system.profile` registró las tres operaciones ejecutadas por `app_ventas@comercial` desde `127.0.0.1` (`appName: "app-ventas-web"`):
1. `op: "query"` (`2026-11-18T06:34:36.505Z`): `find` sobre `clientes` con filtro `{ ciudad: "Culiacán" }` (`docsExamined: 5, nreturned: 3`).
2. `op: "update"` (`2026-11-18T06:34:36.509Z`): actualización de `_id: 3` con `$set: { rfc: "GAMA780912XYZ" }` (`nModified: 1`).
3. `op: "remove"` (`2026-11-18T06:34:36.518Z`): eliminación de `_id: 2` (`ndeleted: 1`).

### 2.2 Costo y reducción con filtro (Actividad 4)
El nivel 2 registra absolutamente todas las lecturas, degradando el rendimiento y llenando rápidamente la colección `system.profile` (1 MB por defecto). Además, `system.profile` **nunca guarda el valor anterior del documento (`OLD`)** ni los datos de un documento eliminado. En la **Actividad 4** ([evidencias/04-filtro.md](./evidencias/04-filtro.md)) se aplicó el filtro:
```javascript
db.setProfilingLevel(1, { filter: { op: { $in: ["insert", "update", "remove"] } } })
```
con lo cual se dejaron de registrar las consultas `find` (perdiendo visibilidad de lecturas y el umbral `slowms`), pero se conservó la trazabilidad de modificaciones (`update` del teléfono de `_id: 1` a `"6670000000"`) con mucho menor volumen.

---

## 3. Bitácora de `mongod`

### 3.1 Dónde se escribe
Según `db.serverCmdLineOpts().parsed.systemLog`, la bitácora en formato JSON se escribe en **`/var/log/mongodb/mongod.log`** (`destination: "file"`, `logAppend: true`), mientras que `db.adminCommand({ getLog: "global" })` consulta únicamente el búfer en memoria de los últimos 1024 eventos.

### 3.2 Accesos exitosos y fallidos (Actividad 5)
En la **Actividad 5** ([evidencias/05-accesos-mongod.md](./evidencias/05-accesos-mongod.md)), al filtrar el componente `c === "ACCESS"`:
- Los accesos fallidos se registran con `id: 5286307` y `msg: "Failed to authenticate"`, distinguiendo internamente entre contraseña incorrecta (`user: "app_ventas"`, `result: 18`, `AuthenticationFailed: SCRAM authentication failed, storedKey mismatch` en `conn53`) y usuario inexistente (`user: "usuario_inexistente"`, `result: 11`, `UserNotFound` en `conn55`), aunque el cliente externo recibe en ambos casos `MongoServerError: Authentication failed.` para evitar enumeración de usuarios.
- Los accesos exitosos se registran con `id: 5286306`, `msg: "Successfully authenticated"` y `result: 0` (`conn47`, `app: "app-ventas-web"`).

### 3.3 Correlación de cambios de configuración (Actividad 6)
En la **Actividad 6** ([evidencias/06-correlacion.md](./evidencias/06-correlacion.md)), el evento `msg: "Profiler settings changed"` (`2026-11-18T00:34:38.190-06:00`) no incluye el campo `user`, pero sí el contexto de conexión **`ctx: "conn42"`**. Al buscar el evento `"Successfully authenticated"` con `ctx === "conn42"` (`2026-11-18T00:34:38.176-06:00`), se demostró que el cambio fue realizado por **`user: "admin"`** (`db: "admin"`) desde `127.0.0.1:54880`. Esta correlación solo es válida dentro del mismo ciclo de arranque del servidor, pues al reiniciar `mongod` los identificadores `connN` se reinician.

---

## 4. Privilegios: Evidencia Disponible, Control Compensatorio y su Límite

En la **Actividad 7** ([evidencias/07-privilegios-control-compensatorio.md](./evidencias/07-privilegios-control-compensatorio.md)), incluso con el perfilador en nivel 2 (`db.setProfilingLevel(2)`), al ejecutar `db.grantRolesToUser("app_ventas", [{ role: "dbAdmin", db: "comercial" }])`, tanto `db.system.profile` como la bitácora de `mongod` registraron **`0` eventos**. En MongoDB Community **no existe auditoría de cambios de privilegios**.

Se implementó como **control compensatorio** la toma de instantáneas periódicas de `db.getUsers()` en `auditoria.instantaneas_privilegios`:
- **Qué sí responde la instantánea:** Permite **detectar** que entre el corte `2026-11-18T06:34:43.335Z` y el corte `2026-11-18T06:34:43.378Z` los privilegios de `app_ventas` cambiaron y que se le agregó el rol `dbAdmin`.
- **Su límite (por qué NO equivale a auditoría):** No registra **quién** ejecutó `grantRolesToUser`, ni desde qué IP/aplicación lo hizo, ni el instante exacto del cambio; además, si alguien otorga un rol y lo revoca antes de la siguiente instantánea, el cambio pasa totalmente inadvertido.

---

## 5. Conservación y Exportación de Evidencias

En la **Actividad 8** ([evidencias/08-conservacion.md](./evidencias/08-conservacion.md)) se comprobaron tres riesgos críticos de conservación:
1. `system.profile` es una *capped collection* de **1 MB** por defecto que se sobrescribe sola al llenarse.
2. El nivel configurado con `db.setProfilingLevel()` **no sobrevive al reinicio** de `mongod` (tras `sudo systemctl restart mongod`, `db.getProfilingStatus()` regresó a `was: 0`).
3. El búfer en memoria de `getLog` se vacía al reiniciar (pasó de `582` a `76` eventos) y solo retiene 1024 líneas.

Antes de reiniciar se exportaron los archivos y se calcularon sus resúmenes SHA-256 en [evidencias/hashes.sha256](./evidencias/hashes.sha256):
- `1cc6766cddbcb5374ee8c9894c7b1eb63ea1816c93dbebb9a251ad35d3c8f12e  evidencias/system-profile.json`
- `924d5a1dd0ce5065ec3f3964a96431cf8a0fc8e91942477d57bf1579add9f492  evidencias/bitacora-mongod.log`

---

## 6. Comparación de los Tres Escenarios (Resumen de la Actividad 9)

*(La matriz completa se detalla en [evidencias/09-comparacion.md](./evidencias/09-comparacion.md)).*
- **PostgreSQL 16 (bitácora + disparador + `pgaudit`):** Cubre los 8 eventos auditables observados, incluyendo cambios de privilegios (`GRANT`/`REVOKE`), valor anterior del dato (`JSONB` en tabla de auditoría) y lecturas por columna sensible (`pgaudit`).
- **MongoDB 7 Community (perfilador + bitácora):** Cubre accesos exitosos y fallidos en la bitácora JSON; cubre de forma **parcial** modificaciones, lecturas y cambios de configuración del perfilador (sujeto a que el perfilador esté activo, a la correlación por `ctx` y a la colección circular de 1 MB); y **NO cubre** cambios de privilegios ni conserva el valor anterior del dato.
- **MongoDB Enterprise / Atlas (auditoría nativa, documentado):** Añade auditoría nativa de cambios de privilegios, DDL, autenticación/autorización y operaciones CRUD hacia destinos externos (`syslog`, JSON, BSON), aunque para conservar el valor anterior de un documento sigue requiriendo mecanismos de *Change Streams* con pre-imágenes o auditoría de aplicación.

---

## 7. Recomendación Profesional para la Organización

Para una organización como **Comercializadora Norte S.A. de C.V.** que necesite auditar cambios de privilegios y proteger datos fiscales (`rfc`):
- **Hechos verificados en el laboratorio:**
  1. En MongoDB Community Edition (`modules: []`), los cambios de privilegios (`grantRolesToUser` / `revokeRolesFromUser`) no dejan rastro ni en `system.profile` ni en la bitácora de `mongod`, y el perfilador tampoco conserva el valor anterior (`OLD`) de un documento modificado o eliminado.
  2. En PostgreSQL 16 (verificado en el `LAB-01`), sí contamos sin costo adicional de licencia con auditoría completa de privilegios (`log_statement = 'ddl'`/`'mod'`), valor anterior y nuevo mediante disparadores `SECURITY DEFINER`, y auditoría de lectura de columnas sensibles mediante `pgaudit`.
- **Supuestos de negocio a validar:**
  1. Que la copia en MongoDB se utiliza únicamente para el catálogo de la tienda en línea (donde el `rfc` no es necesario para mostrar productos) y que el sistema maestro de facturación reside en PostgreSQL.
  2. Que el costo de licenciar MongoDB Enterprise Advanced o migrar a un clúster dedicado MongoDB Atlas M10+ supera el presupuesto asignado únicamente al catálogo web.
- **Recomendación:**
  1. **Opción prioritaria (Arquitectura y Minimización de Datos — costo \$0 de licencia):** Aplicar el principio de minimización de la Unidad II **eliminando el atributo `rfc` y demás datos fiscales de MongoDB Community**, manteniéndolos exclusivamente en PostgreSQL 16 bajo resguardo de `auditoria.cambios_clientes` y `pgaudit`. En MongoDB Community mantener `operationProfiling` con filtro de escrituras en `/etc/mongod.conf`, envío externo de `/var/log/mongodb/mongod.log` y exportación periódica de instantáneas de privilegios hacia un servidor externo.
  2. **Opción alternativa (si es indispensable operar datos regulados y auditar privilegios en MongoDB):** Migrar a **MongoDB Atlas (M10+)** o adquirir **MongoDB Enterprise**, donde el módulo nativo `auditLog` sí registra quién ejecuta cambios de roles y privilegios en tiempo real.

---

## 8. Preguntas de Reflexión (Sección 20)

1. **¿Por qué el perfilador no debe presentarse como un mecanismo de auditoría de seguridad?**
   Porque fue diseñado para analizar el rendimiento de consultas lentas y carece de las garantías esenciales de una bitácora de auditoría de seguridad: no registra eventos de gestión de privilegios ni de autenticación/autorización (`grantRolesToUser`, `createUser`), almacena sus registros dentro de la propia base de datos en una colección circular de 1 MB (`system.profile`) que se sobrescribe automáticamente cuando se llena, su configuración en caliente se pierde al reiniciar el servicio, y cualquier usuario con permisos administrativos sobre la base puede apagarlo (`db.setProfilingLevel(0)`) o borrar la colección (`db.system.profile.drop()`).

2. **¿Por qué el perfilador sí aporta trazabilidad aunque no sea auditoría?**
   Porque cuando está activo (en nivel 2 o en nivel 1 con un filtro sobre `insert`, `update`, `remove`), registra en cada documento de `system.profile` quién ejecutó la operación (`user`), desde qué IP (`client`), con qué aplicación (`appName`), en qué instante (`ts`) y cuál fue el comando exacto (`command.q`, `command.u`). Si esos registros se exportan oportunamente hacia un repositorio externo antes de que la colección circular de 1 MB se sobrescriba, permiten reconstruir qué operaciones CRUD ocurrieron sobre una colección.

3. **¿Qué riesgo introduce el nivel 2 al registrar filtros de consultas que pueden contener datos personales?**
   Al registrar todas las consultas `find` y `aggregate` completas (incluyendo el objeto `command.filter`), cualquier búsqueda por `rfc`, `correo`, `telefono`, token o credencial queda copiada en texto claro dentro de `system.profile` (y en `mongod.log` si supera `slowms`). Esto convierte a `system.profile` en un nuevo depósito concentrado de datos personales (PII) accesible para cualquier rol con permiso de lectura sobre las colecciones del sistema o de diagnóstico.

4. **¿Qué diferencia hay entre detectar un cambio y atribuirlo a alguien?**
   **Detectar un cambio** significa comprobar que el estado de un dato o permiso en el tiempo $t_2$ es distinto de como estaba en el tiempo $t_1$ (por ejemplo, ver en la tabla `clientes` que el RFC cambió, o ver entre dos instantáneas que `app_ventas` ahora tiene el rol `dbAdmin`). En cambio, **atribuirlo a alguien** significa demostrar con evidencia técnica inmutable *qué identidad autenticada* ejecutó la acción que produjo ese cambio, *en qué instante exacto*, *desde qué dirección IP* y *mediante qué comando*. Los controles de estado (como las instantáneas) detectan cambios; solo las bitácoras de auditoría permiten atribuirlos.

5. **¿Por qué reconocer una limitación técnica es parte del trabajo profesional del DBA?**
   Porque la seguridad y el gobierno de datos se basan en la **gestión honesta de riesgos reales**, no en una falsa sensación de seguridad. Si un DBA afirma ante Dirección o ante una auditoría interna que MongoDB Community "está auditado" ocultando que `system.profile` se sobrescribe al llegar a 1 MB, que no guarda valores anteriores o que los cambios de privilegios no dejan rastro, impide que la organización tome decisiones informadas (como aplicar controles compensatorios externos, minimizar datos sensibles o presupuestar una edición con auditoría nativa). Documentar con rigor qué prueba y qué no prueba cada herramienta es lo que da validez técnica y ética al trabajo del administrador.
