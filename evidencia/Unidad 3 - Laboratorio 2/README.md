# LAB-02 — Trazabilidad en MongoDB Community

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Correo institucional:** a.torres23@info.uas.edu.mx
- **Usuario GitHub:** ArturoTorres2005
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** III — Auditoría, trazabilidad y gobierno práctico de datos
- **Temas:** 3.1 Auditoría de bases de datos · 3.2 Bitácoras y trazabilidad
- **Motor:** MongoDB 7.0.48 Community Edition (`mongosh 2.14.2` en Ubuntu 24.04 LTS)
- **Modalidad:** Práctica individual

---

## 1. Despliegue del Servidor y Versión (Anexo A)

Conforme al **Anexo A (Tabla A.1 — Linux con paquetes oficiales)**, el servidor se desplegó sobre **Ubuntu 24.04 LTS (WSL2)** empleando los paquetes oficiales `mongodb-org-server` (`7.0.48`) y `mongodb-mongosh` (`2.14.2`).

- **Versión de `mongod` (`db.version()`):** `7.0.48`
- **Edición (`db.adminCommand({ buildInfo: 1 }).modules`):** `[]` (**Community Edition**; sin módulo `"enterprise"` ni auditoría nativa).
- **Archivo de configuración (`db.serverCmdLineOpts().parsed.config`):** `/etc/mongod.conf`
- **Control de acceso (`security.authorization`):** `"enabled"`
- **Destino de bitácora (`systemLog`):** `destination: "file"`, `logAppend: true`, `path: "/var/log/mongodb/mongod.log"`
- **Reinicio del servicio:** `sudo systemctl restart mongod`

---

## 2. Estructura del Directorio `LAB-02/`

```text
LAB-02/
├── README.md
├── evidencias/
│   ├── 01-edicion-y-limitacion.md
│   ├── 02-incidente-sin-perfilado.md
│   ├── 03-perfilador.md
│   ├── 04-filtro.md
│   ├── 05-accesos-mongod.md
│   ├── 06-correlacion.md
│   ├── 07-privilegios-control-compensatorio.md
│   ├── 08-conservacion.md
│   ├── 09-comparacion.md
│   ├── 10-respuesta-direccion.md
│   ├── system-profile.json
│   ├── bitacora-mongod.log
│   ├── hashes.sha256
│   └── capturas/
│       └── 01-edicion-y-limitacion.png ... 10-respuesta-direccion.png
├── scripts/
│   └── comandos-mongosh.js
└── informe.md
```

---

## 3. Verificación Final (Sección 17)

| # | Criterio de Verificación | Estado | Evidencia |
| :-: | :--- | :---: | :--- |
| 1 | Documentación de que la auditoría nativa no existe en Community (`modules: []`) | **Cumplido** | [01-edicion-y-limitacion.md](./evidencias/01-edicion-y-limitacion.md) |
| 2 | Identificación del destino de la bitácora (`/var/log/mongodb/mongod.log`) | **Cumplido** | [01-edicion-y-limitacion.md](./evidencias/01-edicion-y-limitacion.md) |
| 3 | `system.profile` con operaciones `query`, `update` y `remove` de `app_ventas` | **Cumplido** | [03-perfilador.md](./evidencias/03-perfilador.md) y [system-profile.json](./evidencias/system-profile.json) |
| 4 | Interpretación de usuario, cliente, aplicación y momento de cada operación | **Cumplido** | [03-perfilador.md](./evidencias/03-perfilador.md) |
| 5 | Aplicación de filtro de perfilado y explicación de qué evidencia se pierde | **Cumplido** | [04-filtro.md](./evidencias/04-filtro.md) |
| 6 | Bitácora con accesos fallidos (`id: 5286307`) y exitoso (`id: 5286306`) interpretados | **Cumplido** | [05-accesos-mongod.md](./evidencias/05-accesos-mongod.md) |
| 7 | Correlación de cambio de configuración con su autor mediante `ctx` (`conn42`) | **Cumplido** | [06-correlacion.md](./evidencias/06-correlacion.md) |
| 8 | Aplicación y explicación del control compensatorio de privilegios y su límite | **Cumplido** | [07-privilegios-control-compensatorio.md](./evidencias/07-privilegios-control-compensatorio.md) |
| 9 | Exportación de `system-profile.json`, `bitacora-mongod.log` y `hashes.sha256` | **Cumplido** | [08-conservacion.md](./evidencias/08-conservacion.md) y [hashes.sha256](./evidencias/hashes.sha256) |
