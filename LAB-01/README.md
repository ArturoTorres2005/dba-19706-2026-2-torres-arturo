# LAB-01 — Bitácoras y Auditoría del Dato en PostgreSQL

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Correo institucional:** a.torres23@info.uas.edu.mx
- **Usuario GitHub:** ArturoTorres2005
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** III — Auditoría, trazabilidad y gobierno práctico de datos
- **Temas:** 3.1 Auditoría de bases de datos · 3.2 Bitácoras y trazabilidad
- **Motor:** PostgreSQL 16.15 (`Ubuntu 16.15-0ubuntu0.24.04.1 on x86_64-pc-linux-gnu`) + espejo local en PostgreSQL 18.6 (`x86_64-windows`)
- **Modalidad:** Práctica individual (Partes A, B y Parte C opcional con `pgaudit`)

---

## 1. Despliegue del Servidor y Versión (Anexo A)

De acuerdo con el **Anexo A (Tabla A.1 — Linux con paquetes de la distribución / PGDG)**, el laboratorio se desplegó sobre una instancia de **PostgreSQL 16.15** en **Ubuntu 24.04 LTS (WSL2)**, complementada con el paquete oficial `postgresql-16-pgaudit` (`16.0`) para la ejecución completa de la **Parte C**, además de mantener replicada la base de datos `comercial` en el servicio nativo de Windows.

- **Versión exacta (`SELECT version();`):**
  `PostgreSQL 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1) on x86_64-pc-linux-gnu, compiled by gcc (Ubuntu 13.3.0-6ubuntu2~24.04.1) 13.3.0, 64-bit`
- **Base de datos de trabajo:** `comercial`
- **Directorio de datos (`SHOW data_directory;`):** `/var/lib/postgresql/16/main`
- **Archivo principal de configuración (`SHOW config_file;`):** `/etc/postgresql/16/main/postgresql.conf`
- **Archivo de reglas de autenticación (`SHOW hba_file;`):** `/etc/postgresql/16/main/pg_hba.conf`
- **Apertura de sesión de administrador:** `sudo -u postgres psql -d comercial`
- **Sesión por red (aplicación y usuarios):** `psql "postgresql://<usuario>:<REDACTED>@127.0.0.1/comercial?application_name=<aplicacion>"`
- **Reinicio del servicio:** `sudo systemctl restart postgresql`

---

## 2. Estructura del Directorio `LAB-01/`

```text
LAB-01/
├── README.md
├── sql/
│   ├── 01-colector-y-vista.sql
│   ├── 02-configuracion-bitacora.sql
│   ├── 03-privilegios-estructura.sql
│   ├── 04-esquema-auditoria.sql
│   ├── 05-funcion-disparador.sql
│   └── 06-campos-modificados.sql
├── evidencias/
│   ├── 01-configuracion-inicial.md
│   ├── 02-colector.md
│   ├── 03-incidente-sin-bitacora.md
│   ├── 04-configuracion-bitacora.md
│   ├── 05-accesos.md
│   ├── 06-privilegios-estructura.md
│   ├── 07-modificaciones.md
│   ├── 08-errores.md
│   ├── 09-pg-stat-activity.md
│   ├── 10-diseno-auditoria.md
│   ├── 11-incidente-auditado.md
│   ├── 12-altas-bajas.md
│   ├── 13-manipulacion.md
│   ├── 14-limites.md
│   ├── 15-cronologia.md
│   ├── 16-pgaudit.md
│   ├── bitacora-lab01.log
│   ├── bitacora-lab01.sha256
│   └── capturas/
│       └── 01-configuracion-inicial.png ... 16-pgaudit.png
└── informe.md
```

---

## 3. Resumen de Ejecución y Verificación Final (Sección 26)

| Parte | Componente | Estado Verificado | Evidencia Principal |
| :---: | :--- | :---: | :--- |
| **Parte A** | `logging_collector = on`, `log_connections = on`, `log_disconnections = on`, `log_statement = 'mod'`, `log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h '` (`source = configuration file`) | **Cumplido** | [01-configuracion-inicial.md](./evidencias/01-configuracion-inicial.md) a [09-pg-stat-activity.md](./evidencias/09-pg-stat-activity.md) |
| **Parte B** | Esquema `auditoria` sin acceso para `PUBLIC`, tabla `auditoria.cambios_clientes`, función `SECURITY DEFINER` con `search_path` fijo y disparador `trg_auditoria_clientes` (`tgenabled = O`) | **Cumplido** | [10-diseno-auditoria.md](./evidencias/10-diseno-auditoria.md) a [14-limites.md](./evidencias/14-limites.md) |
| **Cierre A y B** | Exportación de `bitacora-lab01.log` con retiro de secretos (`<REDACTED>`), hash SHA-256 (`cac28a45a80ed5ab20e52e9d75fafd7d70bdd22cce14bc1a1b75e700b1f68008`) y reconstrucción cronológica | **Cumplido** | [15-cronologia.md](./evidencias/15-cronologia.md), [bitacora-lab01.log](./evidencias/bitacora-lab01.log), [bitacora-lab01.sha256](./evidencias/bitacora-lab01.sha256) |
| **Parte C (Opcional)** | Extensión `pgaudit 16.0` cargada vía `shared_preload_libraries`, rol `auditor_datos` y auditoría de lectura/escritura sobre columnas sensibles (`rfc`, `telefono`) | **Cumplido** | [16-pgaudit.md](./evidencias/16-pgaudit.md) |
