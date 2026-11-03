# Línea Base de Seguridad (Security Baseline) — PostgreSQL

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-04 — Hardening y configuración segura de PostgreSQL
- **Motor:** PostgreSQL 18 / 16

---

## 1. Red y Exposición Perimetral

- **Interfaces autorizadas (`listen_addresses`):**
  - En servidores donde la aplicación reside localmente o en entorno de laboratorio local: `listen_addresses = 'localhost'` (`127.0.0.1`, `::1`).
  - En servidores de producción dedicados: escuchar **únicamente en la dirección IP de la interfaz de red privada interna** asignada al segmento de base de datos (ej. `listen_addresses = '10.10.10.20'`), prohibiendo el comodín `'*'` que expone todas las tarjetas de red.
- **Puerto de servicio (`port`):**
  - `TCP 5432` documentado formalmente en el inventario de servicios; cerrado hacia Internet y hacia segmentos de usuarios finales.
- **Firewall de red y de host:**
  - Política por defecto de **denegación implícita (*Default Deny*)**.
  - Regla de lista blanca (*Allowlist*) permitiendo tráfico hacia `TCP 5432` únicamente desde las IPs específicas de los servidores de aplicación autorizados y desde la subred de administración DBA (`10.10.10.0/24`).
- **Redes permitidas en `pg_hba.conf`:**
  - Prohibición estricta de rangos abiertos como `0.0.0.0/0` o `::/0`.
  - Cada entrada `host` o `hostssl` debe especificar el CIDR exacto (`/32` o `/24`), la base de datos específica y el usuario específico.

---

## 2. Autenticación

- **Método de autenticación obligatorio:**
  - **`scram-sha-256`** tanto en el parámetro `password_encryption = 'scram-sha-256'` de `postgresql.conf` como en todas las reglas de `pg_hba.conf`.
  - Queda prohibido el uso de métodos inseguros u obsoletos como `trust`, `password` (texto claro) o `md5`.
- **Políticas de credenciales:**
  - Longitud mínima de 16 caracteres para cuentas de usuario y 24 caracteres aleatorios para cuentas de servicio, almacenadas en un gestor de secretos (KMS / Vault) y con rotación periódica.
- **Cuentas administrativas (`SUPERUSER`):**
  - El rol `postgres` se reserva exclusivamente para tareas de emergencia local o mantenimiento mayor.
  - La administración cotidiana se realiza mediante un rol administrativo nominativo (`dba_admin`) sin privilegios de `SUPERUSER` cuando no sean requeridos, y nunca desde aplicaciones.

---

## 3. Autorización ySeparación de Cuentas

- **Cuentas de aplicación (`app_user`):**
  - Configuradas con `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION`.
  - Permisos acotados exclusivamente a `SELECT, INSERT, UPDATE` sobre las tablas o vistas operativas requeridas (sin `DROP`, `TRUNCATE` ni `ALTER`).
- **Cuentas de consulta / analítica (`consulta_user`, `analista`, `soporte`):**
  - Acceso de **solo lectura (`SELECT`)** exclusivamente sobre vistas minimizadas, enmascaradas o esquemas analíticos seudonimizados (`v_clientes_soporte`, `v_analitica_clientes`, `analitica.clientes`).
- **Esquema `public` endurecido:**
  - Revocación de permisos de creación y lectura por defecto para el rol implícito `PUBLIC` (`REVOKE ALL ON SCHEMA public FROM PUBLIC;`).

---

## 4. Configuración del Motor y Recursos

- **Límites de conexión y disponibilidad:**
  - `max_connections = 100` (ajustado a la capacidad real del servidor y al *pool* de conexiones).
  - `superuser_reserved_connections = 3` para garantizar que el DBA pueda conectarse incluso ante agotamiento de conexiones de la aplicación.
- **Timeouts contra bloqueo y agotamiento de recursos:**
  - `statement_timeout = '30s'` para abortar consultas descontroladas o intentos de denegación de servicio.
  - `idle_in_transaction_session_timeout = '60s'` para cerrar transacciones abandonadas que retienen bloqueos (*locks*) e impiden el trabajo de `VACUUM`.
- **Bitácoras y auditoría:**
  - `logging_collector = on`, `log_directory = 'log'`, `log_connections = on`, `log_disconnections = on`, `log_line_prefix = '%m [%p] %q%u@%d %r '`.
- **Extensiones (`pg_extension`):**
  - Mantener instaladas únicamente las extensiones requeridas y aprobadas para el propósito del servidor (`plpgsql`, `pgcrypto`), deshabilitando extensiones innecesarias.

---

## 5. Sistema Operativo y Archivos Sensibles

- **Propietario de archivos:**
  - El directorio de datos (`data_directory`) y los archivos de configuración (`postgresql.conf`, `pg_hba.conf`, `pg_ident.conf`, claves privadas TLS) deben pertenecer exclusivamente a la cuenta de servicio del sistema operativo (`postgres` en Linux o la cuenta de servicio restringida en Windows).
- **Permisos en sistema de archivos:**
  - En Linux/Unix: `chmod 0700` sobre `PGDATA` y `chmod 0600` sobre `postgresql.conf`, `pg_hba.conf` y `server.key`.
  - En Windows: ACLs restringidas únicamente a `SYSTEM`, `Administradores` y la cuenta del servicio PostgreSQL, sin lectura para usuarios estándar del equipo.

---

## 6. Cifrado y Protección Criptográfica

- **En tránsito (TLS):**
  - `ssl = on` y `ssl_min_protocol_version = 'TLSv1.2'` (preferentemente `TLSv1.3`), exigiendo conexiones `hostssl` en `pg_hba.conf` y validación `sslmode=verify-full` en los clientes.
- **En reposo:**
  - Contraseñas de aplicación protegidas con derivación irreversible (`bcrypt` / `Argon2id`) y columnas sensibles (`rfc`) cifradas con `pgp_sym_encrypt` / AES-256, más respaldos cifrados fuera del servidor.

---

## 7. Mantenimiento y Gobierno Continuo

- **Actualizaciones (Patch Management):**
  - Aplicar actualizaciones menores de seguridad de PostgreSQL (ej. 16.x / 18.x) dentro de una ventana mensual programada tras validación en preproducción.
- **Revisión periódica:**
  - Auditoría trimestral de roles (`\du`), reglas de `pg_hba.conf`, certificados TLS, permisos de archivos y pruebas de restauración de respaldos.
- **Control de cambios:**
  - Todo cambio a `postgresql.conf` o `pg_hba.conf` debe quedar registrado en `configuracion/cambios.md` con fecha, justificación técnica y validación posterior.
