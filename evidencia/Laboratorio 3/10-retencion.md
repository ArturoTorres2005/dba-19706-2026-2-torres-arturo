# Evidencia 10 — Análisis de Política de Retención de Datos

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Evaluar críticamente la propuesta organizacional de *"Conservar todos los datos de clientes indefinidamente porque podrían ser útiles en el futuro"*, contrastándola con los principios de privacidad, minimización, limitación del plazo de conservación y gestión de riesgos en bases de datos.

---

## 2. Procedimiento

Análisis normativo y técnico de la política propuesta en la Actividad 10 (Sección 16) respondiendo las cuatro preguntas de evaluación.

---

## 3. Resultado (Respuestas a las Preguntas de la Actividad 10)

### Pregunta 1: ¿Es compatible con el principio de minimización?
**No, es frontalmente incompatible.** El principio de minimización y limitación del plazo de conservación establece que los datos personales solo deben recabarse y conservarse mientras sean **adecuados, relevantes y estrictamente necesarios** para cumplir la finalidad determinada para la que fueron obtenidos. Conservar datos personales "por si acaso resultan útiles en el futuro" carece de finalidad legítima determinada y viola directamente la normativa de protección de datos (como la LFPDPPP y el RGPD).

### Pregunta 2: ¿Qué riesgos genera conservar información innecesaria?
1. **Mayor impacto ante una brecha de seguridad:** Si ocurre un incidente o filtración en PostgreSQL o en sus respaldos, en lugar de exponerse únicamente los clientes activos vigentes, se comprometen décadas de registros históricos de exclientes que ni siquiera debían seguir almacenados.
2. **Incumplimiento legal y sanciones regulatorias:** Conservar datos personales una vez agotada su finalidad y vencidos los plazos legales constituye una infracción sancionable y vulnera el derecho de cancelación de los titulares.
3. **Desactualización y pérdida de calidad de los datos:** Los datos antiguos (`correo`, `telefono`, `ciudad`) pierden exactitud con el tiempo, incumpliendo el principio de calidad de los datos.
4. **Degradación de desempeño y costos operativos:** Incrementa innecesariamente el tamaño de las tablas, índices, tiempos de respaldo (`pg_dump`), tiempos de restauración ante desastres y costos de almacenamiento seguro.

### Pregunta 3: ¿Qué debería determinar la organización antes de establecer un periodo de retención?
La organización (en conjunto entre las áreas Jurídica, Fiscal, Negocio, Privacidad y TI/DBA) debe determinar:
1. **La finalidad primaria de cada conjunto de datos** (operación comercial, soporte, facturación).
2. **El momento en que concluye la relación activa** con el titular (última compra, cierre de cuenta o término de contrato).
3. **Los plazos obligatorios de conservación legal, fiscal o contractual** (por ejemplo, los **5 años** que exige el artículo 30 del Código Fiscal de la Federación para conservar documentación fiscal y contable).
4. **Los plazos de prescripción legal** para atender posibles reclamaciones o auditorías.
5. **Qué datos pueden anonimizarse de forma irreversible** al concluir el plazo (para conservar únicamente métricas históricas agregadas sin datos personales).

### Pregunta 4: ¿Qué información debería documentarse para justificar el periodo seleccionado?
En la política y catálogo de retención debe documentarse formalmente para cada categoría de datos:
- **Nombre de la entidad/tabla y atributos incluidos** (ej. `public.clientes`).
- **Finalidad del tratamiento** asociada.
- **Fundamento o base de conservación** (operativa, contractual o artículo legal específico como art. 30 CFF).
- **Duración exacta del periodo de retención activa y de bloqueo** (ej. vigencia de la cuenta + 5 años fiscales).
- **Evento disparador del plazo** (ej. `fecha_alta` o `fecha_baja` / última transacción).
- **Acción al finalizar el periodo** (eliminación segura, borrado en cascada de mapas PII o agregación estadística irreversible) y **rol responsable de autorizar y auditar la depuración**.

---

## 4. Análisis

Una política de retención bien diseñada distingue entre conservar **identidades individuales** y conservar **conocimiento estadístico del negocio**: la empresa puede eliminar o anonimizar los datos personales de clientes inactivos tras cumplir los 5 años legales y conservar únicamente tablas resumidas con conteos anuales por ciudad o rango de edad, las cuales ya no contienen datos personales ni representan riesgo de privacidad.

---

## 5. Conclusión

La conservación indefinida de datos personales es una práctica insegura e ilegal. Todo dato personal en PostgreSQL debe tener una fecha de caducidad definida por su finalidad operativa y sus obligaciones legales, culminando en su supresión segura o anonimización irreversible.
