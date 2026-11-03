# Registro de Cambios y Comparativa de Hardening (Antes vs. Después)

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-04 — Hardening y configuración segura de PostgreSQL
- **Motor:** PostgreSQL 18.6 (`C:/Program Files/PostgreSQL/18/data`)

---

## 1. Tabla Comparativa de Configuración: Antes y Después (Actividad 16)

| Control | Estado Antes (Inicial) | Estado Después (Hardening Aplicado / Propuesto) | Justificación Técnica |
| :--- | :--- | :--- | :--- |
| **`listen_addresses`** | `'*'` (escuchando en todas las interfaces de red disponibles del equipo) | `'localhost'` (o únicamente la IP privada dedicada `10.10.10.20`) | Evita exponer el puerto `5432` en interfaces públicas, Wi-Fi o segmentos de red que no necesitan conectarse al motor PostgreSQL. |
| **`pg_hba.conf`** | Reglas genéricas para `{all}` bases de datos y `{all}` usuarios (o en el escenario vulnerable: `host all all 0.0.0.0/0`) | Reglas específicas por base de datos, usuario y subred autorizada: `hostssl comercializadora_norte app_user 10.10.10.0/24 scram-sha-256` | Aplica el principio de mínimo privilegio a nivel de autenticación por host, bloqueando intentos de conexión desde orígenes, usuarios o bases no autorizados. |
| **Método de autenticación** | `scram-sha-256` (verificado activo; en sistemas heredados suele encontrarse `md5` o `trust`) | `scram-sha-256` obligatorio en `password_encryption` y en todas las entradas de `pg_hba.conf` | Previene ataques de repetición, diccionario y exposición de hashes débiles (`md5`) durante el proceso de autenticación. |
| **Usuarios administrativos** | Uso directo de la cuenta superusuario `postgres` para operaciones generales y pruebas | Creación de `dba_admin` (`CREATEDB CREATEROLE NOSUPERUSER`) y reserva de `postgres` solo para emergencias locales | Reduce el riesgo de ejecución accidental o maliciosa de comandos destructivos con privilegios totales de `SUPERUSER`. |
| **Cuentas de aplicación** | Sin separación clara (en el escenario la aplicación se conectaba con cuenta administrativa) | Roles separados: `app_user` (`LOGIN NOSUPERUSER`, solo `SELECT/INSERT/UPDATE` en `clientes_soporte`) y `consulta_user` (solo `SELECT` en vistas) | Si la aplicación web sufre una vulnerabilidad (ej. SQL Injection), el atacante no obtiene control administrativo ni acceso a tablas restringidas. |
| **Puerto (`port`)** | `5432` accesible sin documentación formal de filtrado perimetral | `5432` protegido mediante regla de Firewall (Allowlist exclusiva para `10.10.10.0/24` y denegación para cualquier otro origen) | El firewall bloquea paquetes de red antes de que lleguen siquiera al proceso de PostgreSQL, reduciendo escaneos y ataques DoS. |
| **TLS (`ssl`)** | `ssl = off` en la instalación inicial de Windows (`ssl_min_protocol_version = TLSv1.2`) | `ssl = on`, `ssl_min_protocol_version = 'TLSv1.2'` (negociando `TLSv1.3`) y exigencia de `hostssl` / `sslmode=verify-full` | Protege la confidencialidad e integridad de credenciales, consultas y resultados en tránsito, validando la identidad del servidor. |
| **Permisos de Sistema Operativo** | Archivos `postgresql.conf`, `pg_hba.conf` y directorio `data` sin auditoría previa de ACLs | Verificación de permisos restringidos exclusivamente a la cuenta de servicio de PostgreSQL y Administradores (`0700` / `0600`) | Impide que otros usuarios locales del sistema operativo lean configuraciones, certificados, llaves privadas o archivos crudos de tablas. |
| **Extensiones (`pg_extension`)** | `plpgsql` (`1.0`) y `pgcrypto` (`1.4`) instaladas sin inventario documentado | Inventario validado conservando únicamente `plpgsql` y `pgcrypto` (necesarias para procedimientos y cifrado) | Cumple el principio de habilitar únicamente los componentes estrictamente necesarios para la función del servidor. |
| **Parámetros de Conexión y Timeouts** | `max_connections = 100`, `superuser_reserved_connections = 3`, `statement_timeout = 0` (deshabilitado), `idle_in_transaction_session_timeout = 0` (deshabilitado) | `statement_timeout = '30s'` y `idle_in_transaction_session_timeout = '60s'` aplicados sobre `comercializadora_norte` (`ALTER DATABASE`) | Impide que consultas mal diseñadas o transacciones abandonadas acaparen memoria, bloqueen filas indefinidamente o agoten las 100 conexiones disponibles. |

---

## 2. Checklist de Hardening — 15 Controles Verificados (Actividad 17)

| # | Control | Verificado | Evidencia / Ubicación |
| :-: | :--- | :---: | :--- |
| **1** | **Puerto documentado (`5432`)** | **Sí** | `sql/01-inspeccion.sql` (`SHOW port;` -> `5432`) y `evidencias/01-superficie-ataque.png` |
| **2** | **Interfaces de escucha justificadas (`listen_addresses`)** | **Sí** | `sql/01-inspeccion.sql` (`SHOW listen_addresses;`) y `evidencias/02-listen-addresses.png` |
| **3** | **Archivo `pg_hba.conf` revisado** | **Sí** | `sql/03-configuracion.sql` (`SELECT * FROM pg_hba_file_rules;`) y `evidencias/03-pg-hba.png` |
| **4** | **Redes autorizadas restringidas (sin `0.0.0.0/0`)** | **Sí** | Reglas acotadas a loopback (`127.0.0.1/32`, `::1/128`) y propuesta `10.10.10.0/24` en `informe.md` |
| **5** | **Autenticación segura (`scram-sha-256`)** | **Sí** | `SHOW password_encryption;` -> `scram-sha-256` verificado en `evidencias/03-pg-hba.png` |
| **6** | **Superusuarios identificados y acotados** | **Sí** | `sql/02-roles.sql` (`SELECT ... FROM pg_roles;`, único superusuario: `postgres`) y `evidencias/04-roles.png` |
| **7** | **Cuentas de aplicación separadas (`app_user`, `consulta_user`)** | **Sí** | Creación y verificación de `dba_admin`, `app_user` y `consulta_user` en `sql/02-roles.sql` |
| **8** | **Privilegios mínimos aplicados por rol** | **Sí** | `information_schema.role_table_grants` verificado en `sql/04-verificacion.sql` y `evidencias/06-verificacion.png` |
| **9** | **Extensiones instaladas revisadas y justificadas** | **Sí** | `SELECT extname, extversion FROM pg_extension;` (`plpgsql 1.0`, `pgcrypto 1.4`) en `sql/03-configuracion.sql` |
| **10** | **Configuración y estado de TLS verificado** | **Sí** | `SHOW ssl;`, `SHOW ssl_min_protocol_version;` y `pg_stat_ssl` en `evidencias/05-tls.png` |
| **11** | **Archivos de configuración localizados y protegidos** | **Sí** | `SHOW config_file;`, `SHOW hba_file;`, `SHOW ident_file;` documentados en Actividad 2 y 12 |
| **12** | **Directorio de datos (`data_directory`) protegido** | **Sí** | `C:/Program Files/PostgreSQL/18/data` verificado con permisos de sistema operativo restringidos |
| **13** | **Política de firewall documentada (Allowlist)** | **Sí** | Matriz de reglas de firewall (`10.10.10.0/24` -> Permitir; resto -> Denegar) en Actividad 14 de `informe.md` |
| **14** | **Timeouts de sesión y sentencias configurados** | **Sí** | `statement_timeout = 30s` e `idle_in_transaction_session_timeout = 60s` en `evidencias/06-verificacion.png` |
| **15** | **Línea base y configuración registrada** | **Sí** | Documentada en `configuracion/baseline.md` y `configuracion/cambios.md` |
