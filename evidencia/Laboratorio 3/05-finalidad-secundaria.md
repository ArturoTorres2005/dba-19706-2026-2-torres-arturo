# Evidencia 05 — Análisis de una Finalidad Secundaria

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Evaluar desde la perspectiva de privacidad, cumplimiento (LFPDPPP) y control técnico en PostgreSQL la propuesta de utilizar los datos existentes de la tabla `clientes` para una nueva finalidad secundaria: *"Enviar promociones personalizadas basadas en la edad, ciudad y comportamiento de compra"*.

---

## 2. Procedimiento

Análisis de compatibilidad de finalidades, consentimiento del titular, minimización de datos y diseño de controles técnicos de separación en base de datos (Actividad 5 / Sección 11).

---

## 3. Resultado (Respuestas al Análisis)

### 1. ¿El hecho de que la organización ya tenga los datos significa automáticamente que puede utilizarlos para cualquier finalidad?
**No.** Conforme al principio de **limitación de la finalidad** (y a la LFPDPPP en México), los datos personales solo pueden tratarse para el cumplimiento de las finalidades establecidas en el **Aviso de Privacidad** aceptado por el titular. Utilizar datos recabados originalmente para soporte y facturación (finalidades primarias) con el fin de enviar publicidad o mercadotecnia (finalidad secundaria) sin haberlo informado ni contar con el consentimiento o mecanismo de negativa del titular constituye un tratamiento no autorizado.

### 2. ¿Qué preguntas debería realizar la organización antes de implementar este tratamiento?
1. ¿Esta finalidad promocional/mercadotécnica está contemplada explícitamente como finalidad secundaria en el Aviso de Privacidad vigente?
2. ¿Se recabó el consentimiento de los titulares para finalidades secundarias o existe un registro de quiénes manifestaron su negativa u oposición (*opt-out*)?
3. ¿Existe un mecanismo técnico en la base de datos (por ejemplo, un campo booleano `acepta_promociones` o lista de exclusión) para respetar el derecho de oposición?
4. ¿Cuáles son estrictamente los atributos mínimos indispensables para ejecutar la campaña sin exponer datos fiscales o sensibles como el `rfc`?
5. ¿Quién será el propietario responsable del tratamiento en el área de Marketing y bajo qué controles de acceso operará?

### 3. ¿Qué datos serían realmente necesarios?
Únicamente:
- Un medio de contacto autorizado para promociones (`correo`) de aquellos clientes que **sí aceptaron** finalidades secundarias.
- El segmento generalizado (`rango_edad` y `ciudad` o categoría de compra), **excluyendo por completo** `rfc`, `telefono`, `codigo_postal` exacto y datos de clientes que ejercieron oposición.

### 4. ¿Necesitaría el área de marketing acceso directo a `clientes`?
**No, bajo ninguna circunstancia.** Dar acceso `SELECT` directo sobre la tabla principal `public.clientes` al área de marketing expondría a todos los clientes (incluyendo los que se opusieron a recibir publicidad) y revelaría datos fiscales innecesarios como el `rfc`, el `telefono` y la `edad` exacta.

### 5. ¿Qué controles técnicos podrían limitar la información entregada?
1. **Atributo de consentimiento/oposición:** Incorporar una columna de control (ej. `consentimiento_marketing BOOLEAN DEFAULT FALSE`) gestionada por el proceso de privacidad.
2. **Vista filtrada y minimizada (`CREATE VIEW v_clientes_marketing`):** Proyectar únicamente las columnas autorizadas (`nombre`, `correo`, `ciudad`, `rango_edad`) y filtrar por fila únicamente a quienes dieron su consentimiento (`WHERE consentimiento_marketing = TRUE`).
3. **Control de acceso por rol (`CREATE ROLE marketing NOLOGIN`):** Otorgar `GRANT SELECT` exclusivamente sobre la vista `v_clientes_marketing` y mantener `REVOKE ALL ON public.clientes FROM marketing`.

---

## 4. Análisis

En la práctica profesional, uno de los errores más frecuentes es asumir que porque una tabla ya reside en el servidor PostgreSQL de la empresa, cualquier departamento puede consultarla para nuevos proyectos. El DBA debe actuar como guardián técnico exigiendo la validación del área jurídica/privacidad antes de exponer datos a una nueva finalidad.

---

## 5. Conclusión

El tratamiento de datos para mercadotecnia es una finalidad secundaria que requiere validación jurídica previa (Aviso de Privacidad y consentimiento) y controles técnicos de minimización y filtrado en PostgreSQL para excluir datos fiscales y titulares que se hayan opuesto al tratamiento.
