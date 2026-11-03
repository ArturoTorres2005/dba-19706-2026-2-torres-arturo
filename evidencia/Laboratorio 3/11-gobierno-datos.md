# Evidencia 11 — Matriz de Gobierno de Datos

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Establecer una matriz formal de gobierno de datos para los atributos principales de la tabla `clientes` de Comercializadora Norte S.A. de C.V., asignando para cada dato su finalidad, responsable organizacional (*Data Owner*), usuarios autorizados según necesidad funcional, mecanismo técnico de protección, periodo de retención y disposición final.

---

## 2. Procedimiento

Asignación de responsabilidades y controles técnicos diferenciando entre Propietario del dato (áreas de negocio/finanzas), Custodio técnico (DBA) y Usuarios autorizados (Atención al cliente, Facturación, Analítica, Dirección) conforme a la Actividad 11 (Sección 17).

---

## 3. Resultado (Matriz de Gobierno de Datos)

| Dato | Finalidad | Responsable (*Data Owner*) | Usuarios autorizados | Protección técnica aplicada | Retención | Acción al finalizar |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `nombre` | Identificación del titular para atención de solicitudes y emisión de facturas fiscales. | Gerencia Comercial / Atención al Cliente | **Atención al cliente**, **Facturación**, **DBA** (solo administración técnica) | Control de acceso (`GRANT`/`REVOKE`), exclusión total en vistas y tablas de Analítica. | Vigencia de cuenta activa + 5 años fiscales. | Bloqueo y posterior **eliminación segura** del registro individual. |
| `correo` | Canal de comunicación con el cliente, soporte y envío de CFDI. | Gerencia de Atención al Cliente | **Atención al cliente** (enmascarado en nivel 1 o vista `clientes_soporte`), **Facturación**, **DBA** | Vista restringida (`v_clientes_soporte` / `clientes_soporte`), TLS en tránsito y revocación a Analítica. | Vigencia de la relación comercial + 5 años. | **Eliminación segura** (y baja inmediata de listas secundarias si aplica oposición). |
| `telefono` | Contacto telefónico para soporte y aclaraciones operativas. | Gerencia de Atención al Cliente | **Atención al cliente**, **DBA** (custodia técnica) | Enmascaramiento parcial (`******4567` en nivel básico), prohibido para Facturación, Analítica y Dirección. | Mientras la cuenta del cliente permanezca activa. | **Supresión / borrado** al concluir la relación comercial activa. |
| `rfc` | Emisión de comprobantes fiscales (CFDI) y cumplimiento tributario ante el SAT. | Dirección de Finanzas / Facturación | **Facturación** (lectura autorizada), **DBA** (custodia sin uso operativo) | **Cifrado simétrico en reposo (`pgp_sym_encrypt`)**, enmascaramiento y acceso denegado a Soporte y Analítica. | **5 años** obligatorios (art. 30 Código Fiscal de la Federación). | **Eliminación definitiva y destrucción criptográfica** tras vencer el plazo fiscal. |
| `edad` | Análisis demográfico y generación de estadísticas de segmentos de mercado. | Gerencia de Analítica e Inteligencia de Negocio | **Analítica** y **Dirección** (únicamente como `rango_edad` generalizado) | **Generalización en intervalos (`18-29`, `30-44`, `45-59`)** mediante vista `v_analitica_clientes` y agregación (`COUNT`). | Durante la vigencia del registro operativo. | **Anonimización irreversible** conservando solo conteos estadísticos históricos. |
| `ciudad` | Logística de atención regional y estadísticas de clientes por localidad. | Gerencia Comercial / Analítica | **Atención al cliente** (operación) y **Analítica / Dirección** (agregado por ciudad) | Separación por vistas (`v_analitica_clientes`) y supresión de grupos pequeños ($k$-anonimato) en reportes. | Vigencia de cuenta + 5 años. | **Conservación únicamente en resúmenes agregados**; eliminación del vínculo individual. |
| `codigo_postal` | Validación fiscal del receptor (CFDI 4.0) y análisis estadístico por zona postal. | Dirección de Finanzas / Analítica | **Facturación** (CP completo de 5 dígitos) y **Analítica / Dirección** (solo prefijo regional de 2 dígitos) | Control de acceso diferenciado: dato completo para Facturación y **truncamiento `LEFT(codigo_postal, 2)`** para Analítica. | **5 años** por requisito fiscal. | **Eliminación del dato individual** y conservación únicamente de totales regionales. |

---

## 4. Análisis

- El **Propietario de los datos (*Data Owner*)** es el responsable funcional del área de negocio o finanzas que define para qué se usa el dato y quién debe consultarlo, mientras que el **DBA actúa como Custodio de los datos (*Data Custodian*)**, traduciendo esas reglas en esquemas, vistas, cifrado y permisos `GRANT`/`REVOKE` en PostgreSQL.
- Ningún rol funcional recibe acceso a las 7 columnas completas: **Atención al cliente** no ve `rfc`, `edad` ni `codigo_postal`; **Facturación** no necesita `telefono` ni `edad`; y **Analítica / Dirección** jamás ven `nombre`, `correo`, `telefono` ni `rfc`.

---

## 5. Conclusión

El gobierno de datos evita que los permisos de base de datos se asignen de manera arbitraria. Vincular cada columna con un propietario responsable, una finalidad única, un conjunto acotado de roles autorizados y una regla de disposición final garantiza el cumplimiento continuo de privacidad y seguridad.
