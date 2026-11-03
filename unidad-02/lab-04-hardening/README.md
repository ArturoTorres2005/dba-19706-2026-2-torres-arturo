# LAB-04 — Hardening y configuración segura de PostgreSQL

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** II — Seguridad, privacidad y control de acceso
- **Tema:** 2.6 Hardening de bases de datos
- **Motor:** PostgreSQL 18.6 / 16
- **Modalidad:** Individual

---

## Objetivo

Aplicar un proceso sistemático de **hardening** sobre un servidor PostgreSQL, identificando su superficie de ataque inicial, inspeccionando configuraciones de red (`listen_addresses`), reglas de autenticación por host (`pg_hba.conf`), cuentas administrativas y de aplicación, extensiones, límites de sesión, permisos del sistema operativo y TLS, comparando el estado inicial contra el estado endurecido y documentando una línea base (*baseline*) y lista de verificación (*checklist*) de seguridad.

---

## Entorno

- **Motor de Base de Datos:** `PostgreSQL 18.6 on x86_64-windows, compiled by msvc-19.44.35229, 64-bit`
- **Base de datos de laboratorio:** `comercializadora_norte`
- **Directorio de datos (`data_directory`):** `C:/Program Files/PostgreSQL/18/data`
- **Archivo principal de configuración (`config_file`):** `C:/Program Files/PostgreSQL/18/data/postgresql.conf`
- **Archivo de autenticación (`hba_file`):** `C:/Program Files/PostgreSQL/18/data/pg_hba.conf`
- **Archivo de mapeo de identidades (`ident_file`):** `C:/Program Files/PostgreSQL/18/data/pg_ident.conf`

---

## Superficie de ataque inicial

| Elemento | Estado actual (Inicial) | ¿Es necesario? | Riesgo identificado |
| :--- | :--- | :---: | :--- |
| **Puerto PostgreSQL** | `5432` (TCP) | Sí (solo para orígenes autorizados) | Si no está filtrado por firewall, queda expuesto a escaneos de puertos y ataques de fuerza bruta en red. |
| **Interfaces de escucha (`listen_addresses`)** | `'*'` (todas las interfaces IPv4/IPv6 del host) | **No** (solo requiere `localhost` o IP privada interna) | Expone el servicio en tarjetas de red innecesarias (Wi-Fi, redes públicas o segmentos no administrativos). |
| **Conexiones remotas** | Permitidas a nivel de socket por `listen_addresses = '*'` (restringidas en `pg_hba.conf` a `127.0.0.1/32` y `::1/128`) | Solo desde subred de aplicación / DBA (`10.10.10.0/24`) | Si se combina `listen_addresses = '*'` con una regla permisiva (`0.0.0.0/0`), cualquier host puede intentar autenticarse. |
| **Usuarios administrativos** | Uso de la cuenta superusuario `postgres` (`rolsuper = true`) para conexiones generales | Solo para administración crítica/emergencia | Si una aplicación o sesión cotidiana usa `SUPERUSER`, cualquier inyección SQL o error compromete todo el servidor. |
| **SSL/TLS (`ssl`)** | `off` en la instalación base de Windows (`ssl_min_protocol_version = TLSv1.2`) | **Sí** (en conexiones de red) | Sin TLS activo, las consultas y datos transmitidos por red viajan sin cifrado en tránsito. |
| **Métodos de autenticación** | `scram-sha-256` en `password_encryption` y `pg_hba.conf` (con `{all}` en base de datos y usuario) | Sí (`scram-sha-256`), pero acotando base y usuario | Aunque el algoritmo `scram-sha-256` es seguro, permitir `{all}` bases y `{all}` usuarios incumple el mínimo privilegio de conexión. |

---

## Hallazgos

1. **Exposición de interfaz de escucha:** El parámetro `listen_addresses` viene configurado por defecto en `'*'`, haciendo que el servicio escuche en todas las direcciones IP de la máquina (`0.0.0.0:5432` y `[::]:5432`).
2. **Ausencia de separación entre cuentas administrativas y de aplicación:** No existían roles específicos de aplicación (`app_user`) ni de consulta (`consulta_user`) separados del superusuario `postgres`.
3. **Timeouts de consulta y transacción deshabilitados:** Tanto `statement_timeout` como `idle_in_transaction_session_timeout` estaban en `0` (sin límite), permitiendo que consultas colgadas o transacciones abandonadas bloqueen recursos indefinidamente.
4. **Reglas de `pg_hba.conf` genéricas:** Las reglas predeterminadas permiten `{all}` bases de datos y `{all}` usuarios en lugar de acotar explícitamente la base `comercializadora_norte` y los roles operativos.
5. **Auditoría de conexiones desactivada:** `log_disconnections` se encontraba en `off` y `log_connections` sin activar explícitamente para trazabilidad de sesiones.

---

## Cambios realizados

1. **Separación de roles (Actividad 9 — `sql/02-roles.sql`):**
   - Creación de `dba_admin` (`LOGIN CREATEDB CREATEROLE NOSUPERUSER`).
   - Creación de `app_user` (`LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE`) con permisos exclusivos `SELECT, INSERT, UPDATE` sobre `public.clientes_soporte`.
   - Creación de `consulta_user` (`LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE`) con permiso exclusivo `SELECT` sobre `public.v_analitica_clientes`.
2. **Endurecimiento de parámetros de conexión y disponibilidad (Actividad 11 — `sql/03-configuracion.sql`):**
   - Aplicación de `ALTER DATABASE comercializadora_norte SET statement_timeout = '30s';`.
   - Aplicación de `ALTER DATABASE comercializadora_norte SET idle_in_transaction_session_timeout = '60s';`.
3. **Diseño de reglas específicas de red, firewall y `pg_hba.conf` (Actividades 3, 5, 6 y 14):**
   - Restricción de `listen_addresses` a `'localhost'` (o IP privada `10.10.10.20`).
   - Sustitución de reglas permisivas (`0.0.0.0/0`) por reglas específicas:
     `hostssl comercializadora_norte app_user 10.10.10.0/24 scram-sha-256`
   - Definición de política de firewall tipo *Allowlist* permitiendo `TCP 5432` únicamente desde `10.10.10.0/24` y denegando cualquier otro origen.

---

## Justificación de los cambios

- **Restringir `listen_addresses` y el firewall** reduce la superficie de ataque en la capa de red antes de que un paquete llegue siquiera al motor de autenticación de PostgreSQL.
- **Acotar `pg_hba.conf` por base de datos, usuario, IP de origen y `scram-sha-256`** impide que credenciales filtradas o cuentas de otros sistemas puedan autenticarse desde segmentos no autorizados.
- **Separar `dba_admin`, `app_user` y `consulta_user`** garantiza que la aplicación web nunca opere como `SUPERUSER`, conteniendo el impacto de cualquier vulnerabilidad en la capa de aplicación.
- **Configurar `statement_timeout = 30s` e `idle_in_transaction_session_timeout = 60s`** protege la disponibilidad del servidor contra el agotamiento de `max_connections` (100) y contra bloqueos prolongados de tablas.

---

## Verificación

Mediante `sql/04-verificacion.sql` (`evidencias/06-verificacion.png`) se comprobó en el catálogo `pg_db_role_setting` que la base `comercializadora_norte` tiene activos `{statement_timeout=30s, idle_in_transaction_session_timeout=60s}`, que `pg_roles` refleja los 6 roles con separación estricta de privilegios (`postgres`, `dba_admin`, `app_user`, `consulta_user`, `soporte`, `analista`) y que `information_schema.role_table_grants` otorga únicamente los privilegios mínimos asignados.

---

## Checklist de hardening

*(Disponible completa con los 15 controles en [configuracion/cambios.md](./configuracion/cambios.md)).*

| # | Control | Verificado | Evidencia |
| :-: | :--- | :---: | :--- |
| 1 | Puerto documentado (`5432`) | Sí | `evidencias/01-superficie-ataque.png` |
| 2 | Interfaces de escucha justificadas (`listen_addresses`) | Sí | `evidencias/02-listen-addresses.png` |
| 3 | `pg_hba.conf` revisado | Sí | `evidencias/03-pg-hba.png` |
| 4 | Redes autorizadas restringidas | Sí | `configuracion/baseline.md` y `cambios.md` |
| 5 | Autenticación segura (`scram-sha-256`) | Sí | `evidencias/03-pg-hba.png` |
| 6 | Superusuarios identificados | Sí | `evidencias/04-roles.png` |
| 7 | Cuentas de aplicación separadas (`app_user`, `consulta_user`) | Sí | `evidencias/04-roles.png` |
| 8 | Privilegios mínimos aplicados | Sí | `evidencias/06-verificacion.png` |
| 9 | Extensiones revisadas (`plpgsql`, `pgcrypto`) | Sí | `evidencias/03-pg-hba.png` |
| 10 | TLS verificado (`pg_stat_ssl`) | Sí | `evidencias/05-tls.png` |
| 11 | Configuración protegida (`postgresql.conf`, `pg_hba.conf`) | Sí | `evidencias/01-superficie-ataque.png` |
| 12 | Directorio de datos protegido (`data_directory`) | Sí | `informe.md` (Actividad 12) |
| 13 | Firewall documentado (Allowlist `10.10.10.0/24`) | Sí | `informe.md` (Actividad 14) |
| 14 | Actualizaciones y mantenimiento documentados | Sí | `configuracion/baseline.md` |
| 15 | Configuración y timeouts registrados (`30s` / `60s`) | Sí | `evidencias/06-verificacion.png` |

---

## Conclusiones

El hardening de PostgreSQL no consiste en un único comando ni en ocultar el puerto `5432`, sino en aplicar **defensa en profundidad** a través de todas las capas: sistema operativo (permisos sobre `PGDATA` y archivos `.conf`), red (firewall por lista blanca e interfaz `listen_addresses` acotada), autenticación (`pg_hba.conf` específico con `scram-sha-256` y TLS), autorización (cuentas de aplicación sin `SUPERUSER` y con mínimo privilegio) y disponibilidad (timeouts de sesión y consulta). Documentar la línea base y verificar cada cambio asegura que la configuración sea auditable, reproducible y resistente ante incidentes.
