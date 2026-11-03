# Informe Técnico — LAB-04: Hardening y Configuración Segura de PostgreSQL

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** II — Seguridad, privacidad y control de acceso
- **Tema:** 2.6 Hardening de bases de datos
- **Motor:** PostgreSQL 18.6 (`x86_64-windows`)

---

## Desarrollo de Actividades (Actividades 1 a 19)

### Actividad 1 — Identificar la superficie de ataque (`sql/01-inspeccion.sql`)
- **Versión detectada:** `PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit`
- **Parámetros iniciales:** `port = 5432`, `listen_addresses = '*'`, `ssl = off`, `password_encryption = scram-sha-256`.
- **Pregunta — ¿Por qué conocer la superficie de ataque debe preceder al hardening?**
  Porque no es posible proteger ni restringir lo que no se conoce. Si el DBA intenta aplicar cambios sin antes inventariar en qué interfaces escucha el servidor, qué puertos están abiertos, qué reglas tiene `pg_hba.conf`, qué usuarios son `SUPERUSER` y qué extensiones están activas, corre el riesgo de dejar vectores críticos abiertos o interrumpir servicios legítimos por desconocimiento.

### Actividad 2 — Identificar los archivos de configuración
- **Rutas obtenidas en el servidor:**
  - `config_file`: `C:/Program Files/PostgreSQL/18/data/postgresql.conf` *(Configuración general del motor)*
  - `hba_file`: `C:/Program Files/PostgreSQL/18/data/pg_hba.conf` *(Autenticación basada en host)*
  - `ident_file`: `C:/Program Files/PostgreSQL/18/data/pg_ident.conf` *(Mapeo de usuarios externos a roles)*
  - `data_directory`: `C:/Program Files/PostgreSQL/18/data` *(Datos físicos de tablas e índices)*
  - `log_directory`: `log` *(Bitácoras dentro de `data_directory/log`)*
  - `log_connections`: vacío / predeterminado; `log_disconnections`: `off`.
- **Pregunta — ¿Por qué es importante conocer la ubicación física de estos archivos?**
  Porque la seguridad de PostgreSQL depende directamente de la protección de estos archivos en el sistema operativo: si un usuario no autorizado en el servidor puede leer o modificar `pg_hba.conf`, `postgresql.conf` o el directorio `data`, puede alterar las reglas de autenticación (por ejemplo, cambiar `scram-sha-256` por `trust`), leer certificados privados o copiar los archivos binarios de las tablas saltándose todos los permisos SQL.

### Actividad 3 — Revisar `listen_addresses`
- **Configuración encontrada:** `*` (todas las interfaces IPv4 e IPv6 del servidor).
- **Interfaces necesarias:** `localhost` (`127.0.0.1` / `::1`) en entorno local, o únicamente la interfaz de la **red privada interna** (`10.10.10.20`) en un entorno corporativo.
- **Interfaces innecesarias:** Cualquier interfaz pública, Wi-Fi o adaptador expuesto hacia redes de usuarios generales o Internet (`0.0.0.0` / `::`).
- **Análisis de arquitectura (`Internet -> Firewall -> Servidor PostgreSQL` vs. `Internet -X-> Firewall -> Red privada -> Servidor PostgreSQL`):**
  La **segunda arquitectura (`Internet -X-> Firewall -> Red privada -> Servidor PostgreSQL`)** reduce drásticamente la exposición porque un servidor de base de datos **jamás debe ser alcanzable directamente desde Internet**. Al aislar PostgreSQL dentro de una subred privada interna sin ruta directa desde el exterior y permitir conexiones únicamente desde el segmento de servidores de aplicación o red de administración (DBA), se elimina el riesgo de ataques directos desde Internet incluso si existiera una vulnerabilidad de día cero en el motor.

### Actividad 4 y 5 — Revisar `pg_hba.conf` y analizar una regla permisiva
- **Reglas encontradas en `pg_hba_file_rules`:** 6 reglas restringidas a conexiones locales (`127.0.0.1/32` y `::1/128`) utilizando `scram-sha-256`, pero aplicadas a `{all}` bases de datos y `{all}` usuarios.
- **Análisis de la regla permisiva `host all all 0.0.0.0/0 scram-sha-256`:**
  - **¿Qué bases de datos permite?** Todas (`all`) las bases de datos del clúster.
  - **¿Qué usuarios permite?** Todos (`all`) los roles con capacidad de `LOGIN`, incluyendo superusuarios (`postgres`).
  - **¿Qué direcciones de origen permite?** Cualquier dirección IPv4 del mundo (`0.0.0.0/0`).
  - **¿Qué método de autenticación utiliza?** `scram-sha-256`.
  - **¿Por qué representa una exposición innecesaria?** Porque permite que cualquier máquina en cualquier red intente autenticarse contra cualquier base de datos y con cualquier cuenta (incluyendo `postgres`), habilitando ataques de fuerza bruta, diccionario o uso de credenciales robadas desde fuera del segmento autorizado.
  - **Documentación para restringirla (Actividades 5 y 6):**
    - **Regla actual:** `host all all 0.0.0.0/0 scram-sha-256`
    - **Problema:** Exposición total de origen (`0.0.0.0/0`), de bases de datos (`all`) y de usuarios (`all`).
    - **Origen que realmente necesita acceso:** Subred interna de aplicación/DBA (`10.10.10.0/24` o `127.0.0.1/32`).
    - **Base de datos:** `comercializadora_norte`
    - **Usuario:** `app_user` (para la aplicación) y `dba_admin` (desde la red DBA).
    - **Regla propuesta (Actividad 6):**
      `hostssl comercializadora_norte app_user 10.10.10.0/24 scram-sha-256`

### Actividad 7 — Revisar autenticación (`SHOW password_encryption;`)
- **Valor verificado:** `scram-sha-256`.
- **Preguntas:**
  1. **¿Qué diferencia existe entre autenticación y autorización?**
     La **autenticación** verifica *quién es* el usuario que intenta conectarse (mediante `pg_hba.conf` y su contraseña/certificado), mientras que la **autorización** determina *qué acciones y sobre qué objetos* puede operar ese usuario una vez dentro de la base de datos (`GRANT`/`REVOKE`).
  2. **¿Qué protege `scram-sha-256`?**
     Protege el almacenamiento del verificador de la contraseña en el catálogo `pg_authid` (usando SHA-256 con sal e iteraciones) y protege el intercambio de autenticación mediante un mecanismo de desafío-respuesta (*challenge-response*) que evita enviar la contraseña en texto claro y previene ataques de repetición (*replay attacks*) y debilidades de `md5`.
  3. **¿Por qué una contraseña almacenada mediante un mecanismo de autenticación no debe confundirse con cifrado reversible?**
     Porque el servidor no necesita descifrar la contraseña para autenticar al usuario; utiliza una derivación unidireccional (irreversible) con sal. Si fuera cifrado reversible, quien obtuviera la llave del servidor podría recuperar en texto claro las contraseñas de todos los usuarios.
  4. **¿Qué sucede si una cuenta tiene permisos excesivos aunque utilice una contraseña fuerte?**
     Si la aplicación que utiliza esa cuenta sufre una vulnerabilidad (como inyección SQL) o si la credencial se expone en un archivo de configuración, el atacante heredará todos esos permisos excesivos (pudiendo borrar tablas, leer datos sensibles o tomar control del servidor) sin importar qué tan larga o compleja fuera la contraseña.

### Actividad 8 y 9 — Revisar usuarios, privilegios y separar cuentas (`sql/02-roles.sql`)

| Rol | LOGIN | SUPERUSER | CREATEROLE | CREATEDB | Función |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `postgres` | Sí (`t`) | **Sí (`t`)** | Sí (`t`) | Sí (`t`) | Superusuario de instalación del clúster (solo emergencias/mantenimiento mayor). |
| `dba_admin` | Sí (`t`) | No (`f`) | Sí (`t`) | Sí (`t`) | Administración ordinaria de bases de datos y creación de roles sin ser superusuario total. |
| `app_user` | Sí (`t`) | No (`f`) | No (`f`) | No (`f`) | Cuenta de servicio de la aplicación (`SELECT, INSERT, UPDATE` en `clientes_soporte`). |
| `consulta_user` | Sí (`t`) | No (`f`) | No (`f`) | No (`f`) | Cuenta de solo lectura (`SELECT` sobre vistas autorizadas `v_analitica_clientes`). |
| `soporte` | No (`f`) | No (`f`) | No (`f`) | No (`f`) | Rol de grupo funcional para área de soporte (`v_clientes_soporte`). |
| `analista` | No (`f`) | No (`f`) | No (`f`) | No (`f`) | Rol de grupo funcional para área de analítica (`analitica.clientes` / `v_analitica_clientes`). |

- **Preguntas (Actividades 8 y 9) — ¿Por qué no debería utilizarse una cuenta `SUPERUSER` o administrativa como cuenta normal de una aplicación?**
  Porque un `SUPERUSER` evade absolutamente todas las verificaciones de permisos (`GRANT`/`REVOKE`) y políticas de seguridad de filas (RLS), puede eliminar bases de datos enteras (`DROP DATABASE`), leer archivos del sistema operativo (`pg_read_file`) o ejecutar comandos en el servidor (`COPY ... PROGRAM`). Si la aplicación web se conecta con una cuenta administrativa, cualquier falla o inyección SQL en la aplicación se convierte automáticamente en un compromiso total del servidor de base de datos.

### Actividad 10 — Revisar extensiones (`pg_extension`)
- **Extensiones instaladas:** `plpgsql` (`1.0`, lenguaje procedimental base) y `pgcrypto` (`1.4`, funciones criptográficas utilizadas en LAB-01 y LAB-02).
- **Análisis:** Ambas extensiones están justificadas para este entorno. En un servidor productivo deben desinstalarse o no habilitarse extensiones no utilizadas (especialmente aquellas que permiten conexiones externas como `dblink` o acceso al sistema de archivos como `adminpack` si no son estrictamente requeridas).

### Actividad 11 — Revisar configuración relacionada con conexiones (`sql/03-configuracion.sql`)
- **Valores iniciales:**
  - `max_connections = 100`: número máximo de conexiones simultáneas permitidas al servidor.
  - `superuser_reserved_connections = 3`: ranuras de conexión reservadas exclusivamente para superusuarios cuando se alcanza `max_connections`.
  - `statement_timeout = 0` (cambiado a `'30s'`): tiempo máximo que puede ejecutarse una sentencia antes de ser cancelada automáticamente.
  - `idle_in_transaction_session_timeout = 0` (cambiado a `'60s'`): tiempo máximo que una sesión puede permanecer inactiva dentro de un bloque `BEGIN ...` abierto antes de abortarse.
- **Pregunta — ¿Por qué mantener conexiones indefinidamente abiertas puede representar un problema de disponibilidad o consumo de recursos?**
  Porque cada conexión en PostgreSQL consume un proceso de backend e importante memoria RAM, además de ocupar una de las `max_connections` disponibles. Peor aún, una conexión en estado `idle in transaction` retiene bloqueos (*locks*) sobre tablas y filas e impide que `AUTOVACUUM` limpie tuplas muertas (*table bloat*), pudiendo causar una denegación de servicio (DoS) a toda la aplicación.

### Actividad 12 — Revisar permisos del sistema operativo
- **Archivos críticos verificados en `C:/Program Files/PostgreSQL/18/data`:** `postgresql.conf`, `pg_hba.conf` y el directorio `data`.
- **Pregunta — ¿Por qué no es suficiente proteger PostgreSQL mediante `GRANT` y `REVOKE` si cualquier usuario del sistema operativo puede leer archivos sensibles?**
  Porque `GRANT` y `REVOKE` solo operan cuando se consulta a través del motor SQL de PostgreSQL. Si los permisos del sistema operativo (ACLs en Windows o `chmod`/`chown` en Linux) permiten que un usuario local lea directamente la carpeta `data/base/`, podrá copiar los archivos binarios crudos de las tablas y extraer toda la información en texto claro, o bien leer `postgresql.conf` y `server.key` sin pasar jamás por la autenticación de PostgreSQL.

### Actividad 13 y 14 — Revisar exposición de red y diseñar política de firewall
- **Exposición verificada:**
  - **Dirección de escucha:** `0.0.0.0:5432` y `[::]:5432` (debido a `listen_addresses = '*'`).
  - **Puerto:** `5432`.
  - **¿Está expuesto fuera de la interfaz necesaria?** Sí, al escuchar en `*` enlaza todas las interfaces de red del host en lugar de solo loopback o la interfaz privada.
- **Política conceptual de Firewall (Actividad 14):**

| Origen | Destino | Puerto | Acción |
| :--- | :--- | :---: | :---: |
| `10.10.10.0/24` (Red DBA / Servidores autorizados) | `10.10.10.20` (Servidor PostgreSQL) | `TCP 5432` | **Permitir** |
| Cualquier otro origen (`0.0.0.0/0`, `::/0`) | `10.10.10.20` (Servidor PostgreSQL) | `TCP 5432` | **Denegar** |

- **Pregunta — ¿Por qué `pg_hba.conf` y el firewall no son controles equivalentes?**
  Porque operan en capas distintas: el **firewall** actúa en la **capa de red/transporte (L3/L4)** del sistema operativo o de la infraestructura, descartando los paquetes TCP de orígenes no autorizados **antes** de que establezcan una conexión con el proceso de PostgreSQL (protegiendo contra escaneos, exploits de red y agotamiento de sockets). En cambio, **`pg_hba.conf`** actúa en la **capa de aplicación (L7)** dentro de PostgreSQL *después* de que la conexión TCP ya llegó al servidor, permitiendo decidir qué usuario puede autenticarse a qué base de datos específica y con qué método (`scram-sha-256`). Ambos controles se complementan.

---

### Actividad 18 — Caso Integral (10 Problemas Identificados)

| # | Problema identificado en el escenario | Riesgo concreto | Control propuesto |
| :-: | :--- | :--- | :--- |
| **1** | PostgreSQL acepta conexiones desde cualquier dirección IPv4 (`0.0.0.0/0`). | Cualquier equipo en la red o Internet puede intentar conectarse y lanzar ataques de fuerza bruta o explotar vulnerabilidades. | Restringir `pg_hba.conf` únicamente a los rangos o IPs exactas de los servidores de aplicación y red DBA (`10.10.10.0/24`). |
| **2** | La aplicación web se conecta utilizando un usuario con privilegios administrativos (`SUPERUSER`). | Si la aplicación web sufre una inyección SQL o filtración de configuración, el atacante obtiene control total del servidor PostgreSQL. | Crear una cuenta dedicada `app_user` con `NOSUPERUSER NOCREATEDB NOCREATEROLE` y permisos mínimos (`SELECT, INSERT, UPDATE`) solo en las tablas requeridas. |
| **3** | El servidor escucha en todas las interfaces (`listen_addresses = '*'`). | El puerto `5432` queda abierto en tarjetas de red innecesarias (públicas, gestión o Wi-Fi), ampliando la superficie de ataque. | Configurar `listen_addresses = 'localhost'` o únicamente la IP privada interna dedicada (`10.10.10.20`). |
| **4** | El firewall permite el puerto `5432` desde cualquier origen. | Ausencia de filtrado perimetral; expone al proceso PostgreSQL a inundación de conexiones (DoS) y escaneos masivos. | Configurar el firewall bajo principio de *Allowlist* (permitir solo `10.10.10.0/24` hacia `TCP 5432` y denegar todo lo demás). |
| **5** | El archivo `pg_hba.conf` permite `all` (bases de datos) y `all` (usuarios) en la misma regla abierta. | Una cuenta de prueba o el superusuario `postgres` pueden intentar autenticarse remotamente a cualquier base del servidor. | Definir reglas granulares en `pg_hba.conf` especificando base de datos exacta y rol exacto, prohibiendo el login remoto de `postgres`. |
| **6** | Falsa sensación de seguridad al asumir que *"contraseñas fuertes son suficientes"*. | Ignora vulnerabilidades de red, inyección SQL en la aplicación, intercepción de tráfico sin TLS y abuso de privilegios. | Implementar defensa en profundidad: red segmentada + firewall + TLS + `pg_hba.conf` + mínimo privilegio + monitoreo. |
| **7** | Ausencia de exigencia de TLS (`hostssl`) en las conexiones remotas de la aplicación. | Las consultas y datos sensibles transmitidos entre la aplicación web y PostgreSQL pueden ser interceptados o alterados en la red. | Habilitar `ssl = on` con `TLSv1.2`/`TLSv1.3`, usar reglas `hostssl` en `pg_hba.conf` y `sslmode=verify-full` en la aplicación. |
| **8** | Falta de límites de tiempo y conexiones por cuenta de aplicación (`statement_timeout` / `connection limit`). | Una consulta defectuosa o un ataque desde la aplicación web puede agotar el 100 % de las conexiones y colapsar el servidor. | Configurar `statement_timeout = '30s'`, `idle_in_transaction_session_timeout = '60s'` y `CONNECTION LIMIT` en `app_user`. |
| **9** | Ausencia de monitoreo y bitácora de conexiones/intentos fallidos (`log_connections`). | Si ocurre un intento de intrusión o abuso desde la cuenta de la aplicación, no existirá evidencia ni alerta temprana. | Habilitar `log_connections = on`, `log_disconnections = on` y monitoreo de intentos de autenticación fallidos. |
| **10** | Falta de verificación de permisos de sistema operativo y línea base documentada. | Cambios improvisados sin trazabilidad y riesgo de lectura local de archivos `.conf` o del directorio `PGDATA`. | Restringir permisos de SO (`0700`/`0600`) sobre `PGDATA` y mantener actualizados `baseline.md` y el checklist de hardening. |

#### ¿Es suficiente tener contraseñas fuertes?
**No, de ninguna manera.** Las contraseñas fuertes únicamente fortalecen un eslabón de la **Autenticación**, pero no protegen las demás capas:
- **Autorización:** Si la aplicación ya se autenticó con esa contraseña fuerte pero usa una cuenta `SUPERUSER`, cualquier inyección SQL en la aplicación web no necesita adivinar la contraseña: ya está adentro con poder absoluto.
- **Red:** Sin firewall ni restricción de `listen_addresses`, cualquier atacante puede saturar el puerto `5432` provocando una denegación de servicio (DoS) sin necesidad de conocer la contraseña.
- **Configuración y Sistema Operativo:** Si los archivos `pg_hba.conf` o `PGDATA` tienen permisos laxos en el sistema operativo, o si la conexión viaja sin TLS, un atacante puede extraer datos o interceptar tráfico sin romper la contraseña.
- **Monitoreo:** Sin registros de auditoría, el administrador ni siquiera detectará cuándo una credencial legítima está siendo utilizada para extraer información masivamente.

---

## 30. Respuestas a las 10 Preguntas del Informe

1. **¿Cuál era la principal superficie de ataque?**
   La escucha del servicio en todas las interfaces de red (`listen_addresses = '*'`) en el puerto `5432`, combinada con el uso de la cuenta superusuario `postgres`, la ausencia de timeouts de consulta/transacción (`0`) y la falta de separación de cuentas de aplicación.

2. **¿Qué configuración representaba el mayor riesgo?**
   En el escenario empresarial, la combinación de **utilizar una cuenta administrativa (`SUPERUSER`) para la aplicación** junto con permitir conexiones desde cualquier origen (`0.0.0.0/0` y `listen_addresses = '*'`), ya que expone el control total del motor ante cualquier fallo en la aplicación o en la red.

3. **¿Qué cambio produjo la mayor reducción de exposición?**
   En la capa de red, restringir `listen_addresses` y el firewall únicamente a orígenes autorizados (cerrando la exposición universal del puerto `5432`); y en la capa de base de datos, **reemplazar el uso de `SUPERUSER` en la aplicación por el rol restringido `app_user`** con privilegios mínimos.

4. **¿Qué diferencia existe entre firewall y `pg_hba.conf`?**
   El **firewall** filtra paquetes a nivel de red/sistema operativo (L3/L4) impidiendo que IPs no autorizadas alcancen el puerto `5432`, mientras que **`pg_hba.conf`** opera dentro de PostgreSQL (L7) determinando qué combinación de usuario, base de datos, IP de origen y método de autenticación tiene permitido iniciar sesión en el motor.

5. **¿Qué diferencia existe entre autenticación y autorización?**
   La **autenticación** comprueba la identidad de quien se conecta (ej. validar usuario y contraseña mediante `scram-sha-256`), mientras que la **autorización** define qué permisos tiene esa identidad sobre las tablas, esquemas y vistas (`GRANT` y `REVOKE`).

6. **¿Por qué una cuenta de aplicación no debe ser `SUPERUSER`?**
   Porque el atributo `SUPERUSER` ignora todos los controles de acceso de PostgreSQL y permite destruir datos, alterar configuraciones o interactuar con el sistema operativo. Si la aplicación es vulnerada, el atacante obtiene privilegios totales sobre todo el servidor.

7. **¿Por qué cambiar el puerto de PostgreSQL no constituye hardening suficiente?**
   Porque cambiar `5432` por `5433` es simplemente *seguridad por oscuridad*: cualquier escáner de puertos (`nmap -sV`) identifica en segundos en qué puerto responde el protocolo de PostgreSQL. No sustituye el firewall, ni `pg_hba.conf`, ni la autenticación fuerte ni el mínimo privilegio.

8. **¿Por qué `listen_addresses='*'` puede ser innecesario?**
   Porque hace que PostgreSQL escuche conexiones en absolutamente todas las tarjetas de red del servidor (incluyendo interfaces públicas, de gestión o inalámbricas), cuando en realidad solo necesita escuchar en `localhost` o en la IP privada del segmento de base de datos.

9. **¿Qué papel tiene el sistema operativo en la seguridad de PostgreSQL?**
   Es la base sobre la que descansa el motor: protege físicamente los archivos de datos (`data_directory`), los archivos de configuración (`postgresql.conf`, `pg_hba.conf`), las llaves privadas TLS y los procesos en memoria. Si el sistema operativo está comprometido o tiene permisos de archivos abiertos, todos los controles internos de PostgreSQL pueden ser evadidos.

10. **¿Qué controles deberían revisarse periódicamente?**
    Deben auditarse periódicamente: (1) la lista de roles y superusuarios (`\du`), (2) los privilegios otorgados sobre tablas y esquemas, (3) las reglas de `pg_hba.conf` y del firewall, (4) la vigencia de certificados TLS, (5) los permisos de sistema operativo sobre `PGDATA`, (6) las extensiones instaladas y (7) la aplicación de parches menores de seguridad de PostgreSQL.

---

## 31. Reflexión Individual

### ¿Qué cambiarías primero si recibieras la responsabilidad de asegurar un servidor PostgreSQL que ya se encuentra funcionando en producción?

Si recibiera un servidor PostgreSQL que ya está operando en producción, **no apagaría ni bloquearía conexiones a ciegas en el primer minuto** porque en un entorno productivo la **disponibilidad y continuidad del negocio** son críticas. Aplicaría una secuencia priorizada en tres pasos inmediatos:

1. **Primero — Visibilidad y Cierre de Exposición de Red Externa (Riesgo, Exposición, Red y Continuidad):**
   Primero inspeccionaría las conexiones activas reales en `pg_stat_activity` (para identificar las direcciones IP legítimas de los servidores de aplicación que están trabajando en vivo) y de inmediato **restringiría el firewall y `pg_hba.conf`** para permitir el puerto `5432` **únicamente desde esas IPs legítimas conocidas**, eliminando cualquier acceso abierto desde `0.0.0.0/0` o Internet y bloqueando el login remoto directo del superusuario `postgres`.
   - **¿Por qué este cambio va primero?** Porque reduce de inmediato el 99 % de la superficie de exposición externa frente a atacantes en la red **sin interrumpir la disponibilidad ni la continuidad operativa** de la aplicación que ya está en producción.

2. **Segundo — Eliminación de `SUPERUSER` en la cuenta de la aplicación (Privilegios e Impacto):**
   Crear de inmediato el rol `app_user` con los permisos exactos que requiere la aplicación (`SELECT, INSERT, UPDATE` sobre sus tablas), actualizar la cadena de conexión de la aplicación en una ventana controlada y retirar el uso de la cuenta `SUPERUSER`. Esto reduce drásticamente el **impacto** en caso de que la aplicación web sufra una vulnerabilidad.

3. **Tercero — Autenticación `scram-sha-256`, TLS, Timeouts y Sistema Operativo:**
   Verificar que todas las contraseñas usen `scram-sha-256`, activar TLS (`hostssl`), aplicar `statement_timeout` e `idle_in_transaction_session_timeout` para proteger la disponibilidad y asegurar los permisos `0700`/`0600` sobre el directorio de datos en el sistema operativo.
