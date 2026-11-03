# Evidencia 08 — Derecho de Cancelación y Ciclo de Vida de los Datos

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Analizar las implicaciones técnicas de atender una solicitud procedente de **Cancelación** (Derechos ARCO) en el ecosistema de una base de datos empresarial, identificando todas las ubicaciones y copias derivadas donde persiste la información del titular más allá de la tabla principal `public.clientes`.

---

## 2. Procedimiento

Identificación de dependencias relacionales, copias operativas, vistas, esquemas analíticos, respaldos, réplicas y sistemas externos asociados al registro de un cliente en PostgreSQL (Actividad 8 / Sección 14).

---

## 3. Resultado (Mapa de Propagación y Análisis de Persistencia)

### Mapa de ubicaciones de datos derivados de `clientes`

```text
clientes (Tabla operativa principal: public.clientes)
   │
   ├── Tablas operativas derivadas (ej. public.clientes_soporte, facturación, pedidos)
   ├── Tablas de seudonimización y analítica (pii.mapa_cliente, analitica.clientes)
   ├── Respaldos (pg_dump, respaldos físicos base, archivos WAL / PITR)
   ├── Réplicas (servidores standby de lectura o alta disponibilidad)
   ├── Registros de auditoría y bitácoras (postgresql.log, pgaudit, tablas de historial)
   ├── Reportes y exportaciones (archivos CSV, Excel o PDFs generados previamente)
   └── Sistemas externos y ambientes no productivos (CRM, facturación SAT, copias de desarrollo/QA)
```

### Análisis de los elementos del ecosistema
1. **¿Existen otras tablas relacionadas?** Sí: `clientes_soporte` (Actividad 2), `pii.mapa_cliente`, `analitica.clientes` (LAB-01) y `clientes_protegidos` (LAB-02), además de posibles tablas de ventas o facturas con llaves foráneas (`FOREIGN KEY`).
2. **¿Existen respaldos?** Sí: los respaldos completos (`pg_dump` / `pg_basebackup`) y los segmentos WAL conservan las filas históricas hasta que expira el ciclo de retención del propio backup.
3. **¿Existen réplicas?** Sí: en arquitecturas con replicación en flujo (*streaming replication*), un cambio en el primario se replica, pero copias retrasadas (*delayed standbys*) o desconectadas pueden retener el dato temporalmente.
4. **¿Existen registros de auditoría?** Sí: si en `postgresql.log` se registraron sentencias `INSERT` o `UPDATE` con literales, el correo o RFC del titular puede figurar en archivos de log del servidor.
5. **¿Existen copias utilizadas para analítica?** Sí: `analitica.clientes` y tablas de *data warehouse*.
6. **¿Existen archivos exportados y sistemas externos?** Sí: hojas de cálculo descargadas por usuarios, sistemas de correo transaccional, timbrado fiscal (PAC/SAT) y bases de datos clonadas en entornos de desarrollo o pruebas.

---

### Respuesta a la pregunta central
**¿Por qué eliminar un registro de una tabla no necesariamente significa que toda la información relacionada con esa persona haya desaparecido de la organización?**
Porque un comando `DELETE FROM public.clientes WHERE id = ...;` únicamente marca como eliminada la tupla dentro de esa tabla específica en la base de datos activa. Sin embargo, los datos personales del titular ya se propagaron a lo largo de su ciclo de vida hacia **tablas secundarias (`clientes_soporte`, `pii.mapa_cliente`), copias de respaldo (`backups`) inmutables, archivos de bitácora (`logs`), exportaciones locales (CSV/Excel), entornos de pruebas y sistemas externos**. Además, jurídicamente la cancelación suele implicar un **periodo de bloqueo** previo a la supresión definitiva cuando aún existen plazos legales de conservación (por ejemplo, conservar datos fiscales durante 5 años aunque el cliente cancele su cuenta comercial).

---

## 4. Análisis

Para que una organización pueda cumplir de verdad con el derecho de Cancelación y con las políticas de eliminación, el DBA debe mantener un inventario claro de dónde se copia o replica cada tabla, evitar la proliferación de tablas duplicadas sin control, enmascarar/anonimizar los entornos de pruebas y establecer ciclos de expiración automática para los respaldos y logs.

---

## 5. Conclusión

Eliminar una fila con `DELETE` en la tabla principal es solo una parte del proceso técnico de cancelación. El gobierno de datos exige rastrear todo el flujo de la información (tablas satélite, mapeos de seudonimización, respaldos, logs y exportaciones) para garantizar el bloqueo y la supresión efectiva conforme a la ley.
