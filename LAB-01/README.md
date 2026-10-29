# LAB-01 — Protección y Privacidad de Datos

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** II — Seguridad, privacidad y control de acceso
- **Tema:** 2.3 — Datos sensibles, privacidad y protección de la información
- **Motor:** PostgreSQL 16
- **Modalidad:** Práctica individual

---

## Objetivo

Aplicar mecanismos de protección de datos en PostgreSQL 16 de acuerdo con el propósito y nivel de acceso requerido por diferentes usuarios de una organización ficticia (**Comercializadora Norte S.A. de C.V.**), implementando:

1. **Clasificación de datos** (identificadores directos, cuasi-identificadores y atributos operativos).
2. **Enmascaramiento dinámico (*masking*)** mediante vistas restringidas para el área de **Soporte**.
3. **Seudonimización (*pseudonymization*)** y **separación de funciones** mediante tokens UUID (`pgcrypto`) y esquemas aislados (`pii` y `analitica`) para el área de **Analítica**.
4. **Anonimización (*anonymization*)** mediante generalización, agregación y supresión de grupos pequeños ($k$-anonimato con `HAVING COUNT(*) >= 5`) para **Dirección**, incluyendo el análisis del riesgo de reidentificación.
5. **Retención de datos** mediante consultas de identificación de registros que superan el periodo de conservación establecido (5 años) y diseño del procedimiento seguro de depuración.

---

## Estructura del Repositorio

```text
LAB-01/
├── README.md
├── sql/
│   ├── 01-clasificacion.sql      # Preparación de tabla clientes, inserción de datos y clasificación
│   ├── 02-enmascaramiento.sql    # Rol soporte, vista v_clientes_soporte y control de acceso
│   ├── 03-seudonimizacion.sql    # Esquemas pii/analitica, mapa de tokens UUID y rol analista
│   ├── 04-anonimizacion.sql      # Consultas de generalización, agregación, umbral k>=5 y reto
│   └── 05-retencion.sql          # Identificación de registros sujetos a retención (> 5 años)
├── evidencias/
│   ├── 01-clasificacion.pdf      # Evidencia de Actividad 1 y preparación de la base de datos
│   ├── 02-enmascaramiento.pdf    # Evidencia de Actividad 2 (vista enmascarada y acceso denegado)
│   ├── 03-seudonimizacion.pdf    # Evidencia de Actividades 3 y 4 (tokens y separación de funciones)
│   ├── 04-anonimizacion.pdf      # Evidencia de Actividades 5 y 6 (agregación, k-anonimato y reto)
│   └── 05-retencion.pdf          # Evidencia de Actividad 7 (consulta y política de retención)
└── informe.md                    # Informe técnico completo, matriz, actividades y reflexión
```

---

## Orden de Ejecución de los Scripts SQL

Para reproducir el laboratorio completo en una instancia de **PostgreSQL 16**:

```bash
psql -U postgres -d comercializadora_norte -f sql/01-clasificacion.sql
psql -U postgres -d comercializadora_norte -f sql/02-enmascaramiento.sql
psql -U postgres -d comercializadora_norte -f sql/03-seudonimizacion.sql
psql -U postgres -d comercializadora_norte -f sql/04-anonimizacion.sql
psql -U postgres -d comercializadora_norte -f sql/05-retencion.sql
```

---

## Resumen de Controles Implementados por Área

| Área / Rol | Nivel de acceso requerido | Mecanismo implementado | Objetos permitidos | Objetos restringidos |
| :--- | :--- | :--- | :--- | :--- |
| **Soporte** (`soporte`) | Identificar al cliente para atender solicitudes sin ver datos sensibles completos | Enmascaramiento mediante vista (`VIEW`) + `GRANT`/`REVOKE` | `public.v_clientes_soporte` | `public.clientes`, `pii.mapa_cliente`, `analitica.clientes` |
| **Analítica** (`analista`) | Analizar tendencias y patrones sin conocer la identidad directa del cliente | Seudonimización con tokens UUID (`pgcrypto`) + Separación de funciones | `analitica.clientes` | `pii.mapa_cliente`, `public.clientes`, `public.v_clientes_soporte` |
| **Dirección** | Información estadística y agregada para toma de decisiones | Generalización (rangos de edad y región postal), agregación (`COUNT`) y supresión (`HAVING COUNT(*) >= 5`) | Consultas agregadas / vistas estadísticas | Datos individuales identificables |
| **DBA** (`postgres`) | Administrar estructuras, esquemas, políticas de retención y control de accesos | Control de acceso total y custodia del esquema `pii` | Todos los esquemas (`public`, `pii`, `analitica`) | Sujeto a auditoría y procedimientos de aprobación |
