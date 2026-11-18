# Informe Técnico — LAB-01: Bitácoras y Auditoría del Dato en PostgreSQL

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Correo institucional:** a.torres23@info.uas.edu.mx
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** III — Auditoría, trazabilidad y gobierno práctico de datos
- **Temas:** 3.1 Auditoría de bases de datos · 3.2 Bitácoras y trazabilidad
- **Motor:** PostgreSQL 16.15 (`Ubuntu 16.15-0ubuntu0.24.04.1 on x86_64-pc-linux-gnu`)

---

## 1. Despliegue y Situación Inicial

### 1.1 Forma de despliegue y localización desde el motor
El servidor se desplegó sobre **Ubuntu 24.04 LTS (WSL2)** utilizando los paquetes oficiales `postgresql-16` (`16.15`) y `postgresql-16-pgaudit` (`16.0`). Mediante consultas ejecutadas directamente desde el motor SQL (Sección 6.3, sin depender del sistema operativo), se identificó el alcance del servidor para la base de datos `comercial`:
- **`SELECT version();`** → `PostgreSQL 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, 64-bit`
- **`SHOW data_directory;`** → `/var/lib/postgresql/16/main`
- **`SHOW config_file;`** → `/etc/postgresql/16/main/postgresql.conf`
- **`SHOW hba_file;`** → `/etc/postgresql/16/main/pg_hba.conf`

Asimismo, se inspeccionó la vista `pg_hba_file_rules` (Sección 6.4) y se aseguró que las reglas `host` para `127.0.0.1/32` y `::1/128` exigieran autenticación **`scram-sha-256`** en lugar de `trust`, ya que una regla `trust` permite que cualquier cliente declare cualquier nombre de usuario sin contraseña, anulando la validez probatoria de la identidad en la bitácora.

### 1.2 Qué registraba PostgreSQL por defecto y por qué no permitía responder a Dirección
En la **Actividad 1** ([evidencias/01-configuracion-inicial.md](./evidencias/01-configuracion-inicial.md)), la consulta a `pg_settings` reveló la configuración inicial por defecto:
- `logging_collector = off` (`default`): el servidor no capturaba su propia bitácora en archivos administrados por el motor (`pg_current_logfile()` devolvía `NULL`).
- `log_connections = off` y `log_disconnections = off` (`default`): no se registraba quién abría ni cerraba sesión.
- `log_line_prefix = '%m [%p] '` (`default`): las líneas solo incluían fecha/hora y PID, omitiendo usuario (`%u`), base de datos (`%d`), aplicación (`%a`) e IP del cliente (`%h`).
- `log_statement = 'none'` (`default`): no se registraba ninguna sentencia SQL exitosa (`DDL`, `DML` ni `SELECT`).

Al simular el incidente reportado por facturación en la **Actividad 3** (`UPDATE clientes SET rfc = 'GAMA780912XXX' WHERE id = 3` ejecutado por `app_ventas`), la consulta a `dba.bitacora` devolvió **`0 rows`** ([evidencias/03-incidente-sin-bitacora.md](./evidencias/03-incidente-sin-bitacora.md)). Esto demostró dos principios fundamentales:
1. **El control de acceso no sustituye a la auditoría:** `app_ventas` tenía permiso legítimo de `UPDATE` otorgado en la Unidad II, por lo que PostgreSQL permitió la operación válidamente, pero no dejó rastro de quién, cuándo ni desde dónde la ejecutó.
2. **La auditoría no es retroactiva:** Lo que no se registró en el momento del incidente constituye un hueco irreversible de evidencia.

---

## 2. Configuración Aplicada

Mediante `ALTER SYSTEM` (que escribe en `/var/lib/postgresql/16/main/postgresql.auto.conf`, con prioridad superior a `postgresql.conf`), se aplicaron los siguientes parámetros en las Actividades 2, 4, 7, 18 y 19:

| Parámetro | Valor por defecto | Valor aplicado | ¿Recarga o Reinicio? | Justificación técnica y de auditoría |
| :--- | :--- | :--- | :---: | :--- |
| `logging_collector` | `off` | `on` | **Reinicio** | Activa el proceso *syslogger* para que PostgreSQL capture `stderr` en archivos dentro de `log_directory` y permita consultarlos con `pg_current_logfile()` y `pg_read_file()`. |
| `log_connections` | `off` | `on` | **Recarga** (`pg_reload_conf()`) | Registra cada intento de conexión recibido, autenticado, autorizado o rechazado (`FATAL`). |
| `log_disconnections` | `off` | `on` | **Recarga** (`pg_reload_conf()`) | Registra el cierre de cada sesión junto con el tiempo total de conexión (`session time`). |
| `log_line_prefix` | `'%m [%p] '` | `'%m [%p] user=%u db=%d app=%a client=%h '` | **Recarga** (`pg_reload_conf()`) | Antecede cada línea con marca de tiempo UTC (`%m`), PID (`%p`), rol de sesión (`%u`), base (`%d`), aplicación (`%a`) e IP/host del cliente (`%h`), indispensables para atribuir responsabilidades. |
| `log_statement` | `'none'` | `'ddl'` → `'mod'` | **Recarga** (`pg_reload_conf()`) | Con `'mod'` registra toda creación/modificación de estructura y permisos (`CREATE`, `ALTER`, `DROP`, `GRANT`, `REVOKE`) más todas las sentencias que modifican datos (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`). |
| `shared_preload_libraries` | `''` | `'pgaudit'` | **Reinicio** | Carga en el arranque del servidor la biblioteca compartida de la extensión `pgaudit` (Parte C). |
| `pgaudit.log` / `pgaudit.role` | `''` | `'role, ddl'` / `'auditor_datos'` | **Recarga** (`pg_reload_conf()`) | Habilita la auditoría de sesión para roles/DDL y la auditoría de objeto enfocada exclusivamente en las columnas sensibles (`rfc`, `telefono`) donde `auditor_datos` tiene permisos. |

---

## 3. Eventos Observados e Interpretados

Durante las Actividades 4 a 8 se generaron y verificaron en `dba.bitacora` los **seis tipos de eventos auditables**:

1. **Configuración (Actividad 4 y 7):**
   ```text
   2026-11-18 06:02:09.857 UTC [705] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER SYSTEM SET log_statement = 'mod';
   2026-11-18 06:02:09.863 UTC [647] user= db= app= client= LOG:  parameter "log_statement" changed to "mod"
   ```
   - *Interpretación:* Muestra tanto quién ordenó el cambio (`user=postgres` en sesión `[local]`, `PID 705`) como el instante exacto en que el proceso principal (`PID 647`) recargó la configuración tras `SIGHUP`.

2. **Acceso — Fallido y Exitoso (Actividad 5):**
   ```text
   2026-11-18 06:02:08.540 UTC [687] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 FATAL:  password authentication failed for user "app_ventas"
   2026-11-18 06:02:08.587 UTC [689] user=usuario_inexistente db=comercial app=[unknown] client=127.0.0.1 DETAIL:  Role "usuario_inexistente" does not exist.
   2026-11-18 06:02:08.634 UTC [691] user=app_ventas db=comercial app=[unknown] client=127.0.0.1 LOG:  connection authorized: user=app_ventas database=comercial application_name=app-ventas-web
   2026-11-18 06:02:08.637 UTC [691] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  disconnection: session time: 0:00:00.009 user=app_ventas database=comercial host=127.0.0.1 port=41406
   ```
   - *Interpretación:* Permite distinguir errores por contraseña incorrecta sobre un rol existente (`app_ventas`), intentos contra roles inexistentes (`DETAIL: Role "usuario_inexistente" does not exist.`, oculto al cliente externo para evitar enumeración de cuentas) y sesiones autenticadas con su duración exacta (`0:00:00.009`).

3. **Privilegio (Actividad 6):**
   ```text
   2026-11-18 06:02:09.239 UTC [699] user=postgres db=comercial app=psql client=[local] LOG:  statement: REVOKE UPDATE ON clientes FROM soporte_ana;
   2026-11-18 06:02:09.241 UTC [699] user=postgres db=comercial app=psql client=[local] LOG:  statement: GRANT UPDATE ON clientes TO app_ventas;
   ```
   - *Interpretación:* Registra toda concesión o revocación preventiva de permisos realizada por el administrador (`user=postgres`).

4. **Estructura (Actividad 6):**
   ```text
   2026-11-18 06:02:09.242 UTC [699] user=postgres db=comercial app=psql client=[local] LOG:  statement: ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);
   ```
   - *Interpretación:* Deja constancia de quién alteró el esquema de la tabla `clientes` y en qué momento.

5. **Datos (Actividad 7):**
   ```text
   2026-11-18 06:02:10.909 UTC [707] user=app_ventas db=comercial app=app-ventas-web client=127.0.0.1 LOG:  statement: UPDATE clientes SET telefono = '6679990000' WHERE id = 3
   ```
   - *Interpretación:* Gracias a `log_statement = 'mod'`, queda registrada la sentencia `UPDATE`, el rol (`app_ventas`), la aplicación (`app-ventas-web`) y la IP (`127.0.0.1`), aunque sin mostrar el teléfono anterior.

6. **Error — Operación Rechazada (Actividad 8):**
   ```text
   2026-11-18 06:02:11.529 UTC [713] user=soporte_ana db=comercial app=psql client=127.0.0.1 ERROR:  permission denied for table clientes
   2026-11-18 06:02:11.529 UTC [713] user=soporte_ana db=comercial app=psql client=127.0.0.1 STATEMENT:  DELETE FROM clientes WHERE id = 5
   ```
   - *Interpretación:* Registrado por `log_min_error_statement = error`. Aunque el control de acceso impidió el borrado, la bitácora evidencia que `soporte_ana` intentó ejecutar una operación destructiva no autorizada.

---

## 4. Auditoría del Dato (Parte B)

### 4.1 Diseño de `auditoria.cambios_clientes`
Para cumplir el requerimiento **R1** de facturación (conservar el valor anterior y el nuevo de cada fila modificada), en la **Actividad 10** (`sql/04-esquema-auditoria.sql`) se creó el esquema aislado `auditoria` (`REVOKE ALL ON SCHEMA auditoria FROM PUBLIC`) y la tabla `auditoria.cambios_clientes` con:
- Contexto temporal y de identidad: `id_evento` (`BIGSERIAL`), `momento` (`TIMESTAMPTZ NOT NULL DEFAULT now()`), `usuario_sesion` (`session_user`), `usuario_efectivo` (`current_user`), `aplicacion` (`current_setting('application_name')`) e `ip_cliente` (`inet_client_addr()`).
- Contexto del cambio: `operacion` (`TG_OP`), `id_cliente` (`BIGINT`), `valores_antes` (`JSONB` vía `to_jsonb(OLD)`) y `valores_despues` (`JSONB` vía `to_jsonb(NEW)`).

### 4.2 Papel de `SECURITY DEFINER`, `search_path`, `session_user` y `current_user`
En la **Actividad 11** (`sql/05-funcion-disparador.sql`), la función `auditoria.registrar_cambio_cliente()` se definió con:
- **`SECURITY DEFINER`:** Hace que la función se ejecute con los privilegios de su propietario (`postgres`). De este modo, cuando `app_ventas` actualiza `clientes`, el disparador puede insertar en `auditoria.cambios_clientes` sin que `app_ventas` tenga permiso directo de lectura (`SELECT`), escritura (`INSERT`) ni borrado (`DELETE`) sobre el esquema `auditoria`.
- **`SET search_path = pg_catalog, public`:** Es indispensable en toda función `SECURITY DEFINER` para evitar ataques de suplantación de objetos (*search_path hijacking*), donde un usuario malicioso crea tablas o funciones homónimas en un esquema propio para que se ejecuten con privilegios de superusuario.
- **`session_user` frente a `current_user`:** Dentro de una función `SECURITY DEFINER`, `current_user` cambia a `postgres` (`usuario_efectivo`), mientras que `session_user` conserva el rol real que inició la conexión (`usuario_sesion = app_ventas`). Si solo se registrara `current_user`, todos los cambios parecerían hechos por `postgres`.

### 4.3 Resultado del incidente auditado (Actividad 12)
Al ejecutar `UPDATE clientes SET rfc = 'GAMA780912ZZZ' WHERE id = 3` como `app_ventas`, y posteriormente comparar `valores_antes` y `valores_despues` con `CROSS JOIN LATERAL jsonb_each(a.valores_despues)` (`sql/06-campos-modificados.sql`), se obtuvo:
```text
 id_evento |            momento            | usuario_sesion | ip_cliente | campo |     antes     |    despues    
-----------+-------------------------------+----------------+------------+-------+---------------+---------------
         1 | 2026-11-18 06:02:17.859027+00 | app_ventas     | 127.0.0.1  | rfc   | GAMA780912XYZ | GAMA780912ZZZ
```
Y cuando `app_ventas` intentó leer o borrar `auditoria.cambios_clientes`, o desactivar `trg_auditoria_clientes` (Actividades 12 y 14), el motor rechazó las operaciones con `ERROR: permission denied for schema auditoria` y `ERROR: must be owner of table clientes`.

---

## 5. Limitaciones de los Mecanismos

1. **Lecturas de datos sensibles (`SELECT`):**
   Como se comprobó en la **Actividad 15**, cuando `soporte_ana` ejecutó `SELECT nombre, rfc, telefono FROM clientes WHERE id = 3`, no quedó rastro ni en `auditoria.cambios_clientes` (PostgreSQL no soporta disparadores `AFTER SELECT`) ni en `dba.bitacora` (`log_statement = 'mod'` no registra consultas). En la **Parte C (Actividades 18 y 19)** se resolvió esta limitación instalando **`pgaudit`** y configurando la auditoría de objeto con el rol `auditor_datos` (`GRANT SELECT (rfc, telefono), UPDATE (rfc, telefono) ON clientes TO auditor_datos`), logrando registrar únicamente las lecturas y escrituras que tocan las columnas sensibles `rfc` y `telefono` (`AUDIT: OBJECT,1,1,READ,SELECT,TABLE,public.clientes`).

2. **Multiplicación de volumen en cambios masivos:**
   En la **Actividad 15**, la sentencia `UPDATE clientes SET segmento = 'regular';` sin cláusula `WHERE` generó **1 sola línea** en `dba.bitacora`, pero insertó **5 filas completas** en `auditoria.cambios_clientes`. En una tabla con un millón de registros, un `UPDATE` masivo generaría un millón de inserciones `JSONB` dentro de la misma transacción.

3. **Administrador con control total:**
   En la **Actividad 14**, el superusuario `postgres` ejecutó `ALTER TABLE clientes DISABLE TRIGGER trg_auditoria_clientes;`, modificó el RFC a `'GAMA780912GHI'` y reactivó el disparador. El cambio **no apareció en `auditoria.cambios_clientes`** (`count = 3`), aunque sí quedó registrado en `dba.bitacora` (líneas `163–165`). Sin embargo, dado que quien controla el servidor también podría borrar el archivo de log local o desactivar `pgaudit`, ningún control puramente interno protege contra un administrador con privilegios totales si las bitácoras no se envían a un servidor externo independiente.

---

## 6. Riesgos de la Bitácora, Exportación e Integridad

1. **Exposición de secretos en texto claro (Actividad 6):**
   Al ejecutar `CREATE ROLE rol_temporal LOGIN PASSWORD '...'`, la contraseña quedó grabada en texto plano dentro de la bitácora y no desapareció al ejecutar `DROP ROLE rol_temporal`. Por ello, las contraseñas deben asignarse siempre con `\password` (que envía únicamente el verificador `SCRAM-SHA-256`).
2. **Acumulación de datos personales (PII):**
   Tanto `dba.bitacora` como `auditoria.cambios_clientes` almacenan RFC, correos y teléfonos, incluso de clientes ya eliminados como `Pedro Ruiz` (Actividad 13), por lo que requieren el mismo nivel de protección y políticas de retención que las tablas operativas.
3. **Exportación sanitizada y control de integridad SHA-256 (Actividad 16):**
   Se exportó el archivo `evidencias/bitacora-lab01.log` aplicando `replace(pg_read_file(pg_current_logfile()), '<CONTRASEÑA_TEMPORAL>', '<REDACTED>')` y se calculó su resumen criptográfico en `evidencias/bitacora-lab01.sha256`:
   - **SHA-256:** `cac28a45a80ed5ab20e52e9d75fafd7d70bdd22cce14bc1a1b75e700b1f68008`

---

## 7. Cronología y Conclusión

*(La tabla completa con los 14 eventos cronológicos y el desglose detallado de las 5 respuestas a Dirección se encuentran en [evidencias/15-cronologia.md](./evidencias/15-cronologia.md)).*

### Resumen de Respuestas a Dirección
1. **¿Quién hizo cada cambio de RFC?**
   - *Cambio 1 (Actividad 3, a `GAMA780912XXX`):* **No hay evidencia** (ocurrió con la configuración por defecto sin bitácora ni disparador).
   - *Cambio 2 (Actividad 7, a `GAMA780912XYZ`):* **No hay evidencia de la sentencia `UPDATE`** (solo consta que `app_ventas` se conectó desde `127.0.0.1` en las líneas `36–39` cuando `log_statement` valía `'ddl'`).
   - *Cambio 3 (Actividad 12, a `GAMA780912ZZZ`):* **`app_ventas`** desde `127.0.0.1` (`app-ventas-web`) el `2026-11-18 06:02:17.859027+00` (`id_evento = 1` y línea `131`).
   - *Cambio 4 (Actividad 14, a `GAMA780912GHI`):* **`postgres`** desde `[local]` (`psql`) el `2026-11-18 06:02:18.626 UTC` tras desactivar `trg_auditoria_clientes` (líneas `163–165`).
2. **¿Quién cambió el teléfono?**
   - **`app_ventas`** desde `127.0.0.1` (`app-ventas-web`) el `2026-11-18 06:02:10.909 UTC` (línea `49` de `bitacora-lab01.log`; sin evidencia del valor anterior por ser previo a la Parte B).
3. **¿Hubo intentos de acceso fallidos?**
   - **Sí:** un intento fallido de `app_ventas` (`06:02:08.540 UTC`, líneas `14–16`) y uno de `usuario_inexistente` (`06:02:08.587 UTC`, líneas `17–20`), ambos desde `127.0.0.1`. Antes del incidente de la Actividad 3 **no hay evidencia** porque `log_connections` estaba en `off`.
4. **¿Qué valor tenía el RFC antes de cada cambio?**
   - Antes de los cambios 1 y 2: **No hay evidencia** en bitácora ni auditoría.
   - Antes del cambio 3 (Actividad 12): **`GAMA780912XYZ`** (demostrado en `id_evento = 1`, `valores_antes ->> 'rfc'`).
   - Antes del cambio 4 (Actividad 14): **`GAMA780912ZZZ`** (último valor en `id_evento = 1` antes de la desactivación del disparador registrada en la línea `163`).

### Conclusión General
Con la combinación configurada en este laboratorio —**bitácora del servidor (`logging_collector = on`, `log_connections = on`, `log_disconnections = on`, `log_line_prefix` completo y `log_statement = 'mod'`) + tabla de auditoría con disparador `SECURITY DEFINER` (`auditoria.cambios_clientes`) + auditoría de objeto con `pgaudit` sobre columnas sensibles**—, **sí puede demostrarse con rigor técnico quién modificó o consultó un dato sensible, cuándo lo hizo, desde qué dirección IP y aplicación se conectó, y qué valor exacto tenía el registro antes y después del cambio**, siempre que los registros se externalicen y resguarden bajo separación de funciones.

---

## 8. Preguntas de Reflexión (Sección 29)

1. **¿Por qué la auditoría no puede configurarse después de un incidente para investigarlo?**
   Porque los mecanismos de auditoría (`logging_collector`, `log_statement`, disparadores y `pgaudit`) capturan los eventos en tiempo real en el instante en que se ejecutan. PostgreSQL no guarda para fines forenses el historial de usuarios, direcciones IP ni valores anteriores de transacciones pasadas si no estaba configurado para registrarlos cuando ocurrieron; cualquier evento previo a la activación de la bitácora es un hueco permanente de información.

2. **¿Por qué conviene que la bitácora la administre el propio servidor y no el mecanismo de despliegue?**
   Porque si `logging_collector = off`, el destino de `stderr` cambia radicalmente según la plataforma (`journald`/`/var/log/postgresql` en Linux, archivos de Homebrew en macOS, stdout efímero en contenedores Docker), impidiendo que el DBA consulte o verifique la bitácora de forma estándar. Con `logging_collector = on`, PostgreSQL toma control directo de la escritura y rotación de sus archivos en `log_directory` y habilita las funciones SQL nativas (`pg_current_logfile()`, `pg_read_file()`, `pg_ls_logdir()`) en cualquier sistema operativo.

3. **¿Por qué el prefijo de línea es tan importante como el nivel de `log_statement`?**
   Porque `log_statement` determina *qué sentencia* se escribe en la bitácora, pero es `log_line_prefix` (`%m [%p] user=%u db=%d app=%a client=%h `) el que aporta el **contexto de atribución**: *quién* la ejecutó (`%u`), *sobre qué base de datos* (`%d`), *con qué aplicación* (`%a`), *desde qué dirección IP* (`%h`) y *en qué sesión o proceso* (`%p`). Una sentencia `UPDATE` registrada sin `%u` ni `%h` dice qué pasó, pero no permite demostrar quién fue el responsable.

4. **¿Qué diferencia práctica hay entre registrar la sentencia y registrar el cambio en el dato?**
   Registrar la **sentencia** (`log_statement = 'mod'`) guarda una sola línea con el comando SQL enviado por el cliente (por ejemplo, `UPDATE clientes SET segmento = 'regular'`), pero no muestra qué filas resultaron afectadas ni qué valores tenían antes (`OLD`). En cambio, registrar el **cambio en el dato** (mediante el disparador `FOR EACH ROW` en `auditoria.cambios_clientes`) guarda una fila por cada registro modificado con el documento `JSONB` exacto de `valores_antes` y `valores_despues`, permitiendo revertir cambios erróneos con certeza absoluta.

5. **¿Qué evidencia ofrece `pg_stat_activity` que no ofrece la bitácora, y viceversa?**
   - **`pg_stat_activity` (fotografía del presente):** Muestra en tiempo real qué sesiones están conectadas en este instante, su estado actual (`active`, `idle`, `idle in transaction`), desde qué hora iniciaron su transacción o consulta y qué están ejecutando ahora mismo (incluso antes de que la consulta termine o si `log_statement` no la registra). Sin embargo, en cuanto la sesión se cierra, desaparece de `pg_stat_activity`.
   - **La bitácora (historia del pasado):** Conserva de forma persistente el registro cronológico de las conexiones, desconexiones, errores y sentencias que ya terminaron, permitiendo investigar incidentes horas, días o meses después.

6. **Si el administrador puede cambiar `log_statement` a `none` y desactivar el disparador, ¿quién audita al administrador?**
   Al administrador lo audita una arquitectura basada en **separación de funciones (*Segregation of Duties*) y custodia externa de bitácoras**:
   - Técnicamente, el servidor PostgreSQL debe reenviar sus registros en tiempo real (mediante `syslog`, agentes de recolección o *log shipping*) hacia un **servidor SIEM o repositorio de logs centralizado e inmutable (WORM)** administrado por un área de Seguridad de la Información independiente, donde el DBA **no tiene permisos de modificación ni borrado**.
   - Así, si el DBA ejecuta `ALTER SYSTEM SET log_statement = 'none'` o `ALTER TABLE ... DISABLE TRIGGER`, ese comando se transmite de inmediato al SIEM externo antes de que el cambio surta efecto, disparando una alerta crítica al equipo de Seguridad y Auditoría Interna.
