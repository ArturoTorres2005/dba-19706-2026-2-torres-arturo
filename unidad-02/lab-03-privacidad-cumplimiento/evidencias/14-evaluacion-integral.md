# Evidencia 14 — Evaluación Integral de Riesgos de Privacidad y Seguridad

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Evaluar un escenario empresarial con 50,000 clientes e identificar al menos 10 problemas concretos de privacidad, gobierno y seguridad de datos, relacionando cada hallazgo con el principio afectado, el riesgo resultante y el control técnico/administrativo propuesto.

---

## 2. Procedimiento

Análisis del escenario descrito en la Actividad 14 (Sección 20) y clasificación de controles técnicos vs. administrativos de la Actividad 13 (Sección 19).

---

## 3. Resultado

### A. Clasificación de Controles Técnicos y Administrativos (Actividad 13)

| Medida | Técnico | Administrativo | Justificación |
| :--- | :---: | :---: | :--- |
| **Crear roles de PostgreSQL** | **Sí** | No | Se implementa directamente en el motor de base de datos mediante comandos SQL (`CREATE ROLE`). |
| **Política de retención** | No | **Sí** | Es una norma organizacional y documental que define plazos y reglas de conservación (aunque luego se apoye en scripts técnicos). |
| **Cifrado de datos** | **Sí** | No | Mecanismo tecnológico criptográfico (`pgp_sym_encrypt`, AES, TLS) ejecutado por software/hardware. |
| **Procedimiento para solicitudes ARCO** | **Sí (apoyo)** | **Sí (principal)** | Es un proceso administrativo/jurídico de atención al titular, que requiere soporte técnico en la BD para consultar, rectificar o bloquear registros. |
| **Vista con información limitada** | **Sí** | No | Objeto técnico del SGBD (`CREATE VIEW`) que filtra columnas y filas en tiempo de consulta. |
| **Clasificación de información** | **Sí (etiquetado)** | **Sí (principal)** | Proceso administrativo/normativo de categorización de sensibilidad, que se refleja técnicamente en catálogos o esquemas (`pii`, `COMMENT ON`). |
| **Registro de auditoría** | **Sí** | No | Mecanismo técnico de bitácoras (`postgresql.log`, `pgaudit`) que captura eventos del servidor. |
| **Política de control de acceso** | No | **Sí** | Documento normativo que define qué perfiles deben acceder a qué recursos; su traducción técnica son los comandos `GRANT` y `REVOKE`. |

---

### B. Matriz de Evaluación Integral — 10 Problemas Identificados (Actividad 14)

| # | Problema identificado en el escenario | Principio afectado | Riesgo concreto | Control propuesto |
| :-: | :--- | :--- | :--- | :--- |
| **1** | Todos los empleados de analítica consultan directamente la tabla `clientes`. | **Mínimo privilegio** y **Limitación de acceso por finalidad** | Exposición masiva de los datos personales de 50,000 clientes ante personal que no requiere conocer su identidad. | Aplicar `REVOKE ALL ON clientes FROM analista;` y otorgar acceso únicamente a vistas o tablas agregadas/seudonimizadas. |
| **2** | Analítica recibe `nombre`, `correo`, `telefono` y `RFC` cuando solo genera estadísticas mensuales. | **Minimización de datos** y **Proporcionalidad** | Filtración de identificadores directos y fiscales (RFC), robo de identidad o extracción no autorizada del padrón de clientes. | Crear una vista estadística (`v_analitica_clientes`) o tabla agregada que solo contenga `ciudad`, `rango_edad` y conteos (`COUNT`). |
| **3** | Los datos de los 50,000 clientes se conservan desde hace 12 años sin depuración. | **Limitación del plazo de conservación (Retención)** y **Calidad** | En caso de brecha de seguridad, se comprometen 12 años de registros históricos de exclientes inactivos; incumplimiento legal. | Implementar un proceso de retención que identifique registros vencidos (`fecha_alta < CURRENT_DATE - INTERVAL '5 years'`) para su bloqueo y supresión/anonimización. |
| **4** | No existe una política documentada de retención de datos. | **Responsabilidad (*Accountability*)** y **Gobierno de datos** | Imposibilidad de justificar legalmente por qué se conservan los datos y falta de criterios para eliminar información obsoleta. | Redactar y aprobar formalmente la Política de Retención vinculada a plazos operativos y fiscales (5 años), asignando responsables de ejecución. |
| **5** | Los desarrolladores reciben copias completas de la base de datos para realizar pruebas. | **Mínimo privilegio**, **Confidencialidad** y **Separación de ambientes** | Los ambientes de desarrollo suelen tener menores controles de seguridad; exponer ahí los 50,000 registros reales multiplica el riesgo de fuga. | Prohibir el uso de respaldos productivos crudos en desarrollo; aprovisionar ambientes de prueba únicamente con **datos sintéticos o enmascarados estáticamente**. |
| **6** | Las copias de desarrollo contienen información real de los clientes (nombre, RFC, correo). | **Privacidad por diseño y por defecto** y **Seguridad de datos** | Cualquier desarrollador, becario o herramienta externa conectada al entorno de pruebas puede leer y copiar datos personales reales. | Implementar un pipeline automatizado de sanitización/enmascaramiento estático y truncado antes de restaurar cualquier copia hacia QA/Desarrollo. |
| **7** | El área de marketing utiliza los correos electrónicos para campañas promocionales sin validación de finalidad. | **Limitación de finalidad** y **Consentimiento / Oposición** | Tratamiento ilícito de datos personales para mercadotecnia no autorizada, quejas de titulares y sanciones bajo la LFPDPPP. | Verificar el Aviso de Privacidad, agregar columna `consentimiento_marketing` y restringir a marketing mediante una vista que solo incluya clientes con *opt-in* activo. |
| **8** | No existe documentación clara sobre qué finalidad corresponde a cada dato almacenado. | **Finalidad**, **Transparencia** y **Gobierno de datos** | Recolección y uso arbitrario de atributos, incapacidad para responder solicitudes ARCO y desconocimiento de qué datos son prescindibles. | Crear y mantener actualizado el **Inventario y Catálogo de Datos** (como en la Evidencia 01 y 11) documentando finalidad, propietario y retención por columna. |
| **9** | El `RFC` de los 50,000 clientes se almacena en la misma tabla general accesible por múltiples áreas y copias. | **Confidencialidad** y **Separación por sensibilidad** | Exposición de información fiscal oficial de todos los clientes a áreas operativas, analíticas y de desarrollo que no facturan. | Separar los datos fiscales en un esquema/tabla protegida, aplicar cifrado simétrico (`pgp_sym_encrypt`) y autorizar únicamente al rol `facturacion`. |
| **10** | Ausencia de trazabilidad y controles para atender derechos ARCO (Cancelación/Oposición) en copias y áreas. | **Trazabilidad** y **Cumplimiento de Derechos ARCO** | Si un cliente solicita la cancelación u oposición, sus datos seguirán usándose en marketing y seguirán existiendo en las copias de los desarrolladores. | Centralizar el control del ciclo de vida, auditar accesos/cambios, eliminar copias no autorizadas en desarrollo y automatizar la baja en vistas de marketing. |

---

## 4. Análisis

Los 10 problemas del escenario muestran cómo una falla de **gobierno de datos** (falta de inventario de finalidades, ausencia de política de retención y entrega de copias reales a desarrollo) convierte una base de datos de 50,000 clientes en un pasivo crítico de seguridad y cumplimiento, incluso antes de que ocurra un ataque externo.

---

## 5. Conclusión

Corregir este escenario exige combinar controles administrativos (inventario de finalidades, política de retención de 5 años, prohibición de datos reales en desarrollo) con controles técnicos en PostgreSQL (vistas minimizadas por rol, revocación de permisos sobre `clientes`, cifrado del RFC y datos sintéticos para pruebas).
