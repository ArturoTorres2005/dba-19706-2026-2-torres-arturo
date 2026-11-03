# Evidencia 12 — Privacidad por Diseño y por Defecto

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Analizar críticamente un diseño de tabla propuesto bajo la premisa *"Es mejor guardar todos los datos por si posteriormente necesitamos alguno"* y rediseñarlo aplicando los principios de **Privacidad por Diseño (*Privacy by Design*)** y **Privacidad por Defecto (*Privacy by Default*)**.

---

## 2. Procedimiento

Revisión del DDL propuesto en la Actividad 12 (Sección 18):
```sql
CREATE TABLE clientes (
    id BIGSERIAL, nombre TEXT, correo TEXT, telefono TEXT, rfc TEXT,
    edad INTEGER, direccion TEXT, ciudad TEXT, codigo_postal TEXT,
    fecha_nacimiento DATE, ocupacion TEXT, salario NUMERIC, estado_civil TEXT, ...
);
```

---

## 3. Resultado (Respuestas a las Preguntas de la Actividad 12)

### 1. ¿Qué problemas identificas?
1. **Recolección excesiva e injustificada de datos personales y patrimoniales:** Se incluyen atributos altamente intrusivos como `salario`, `estado_civil` y `ocupacion` que no tienen relación alguna con el registro básico de un cliente en una comercializadora.
2. **Duplicidad e inconsistencia de atributos:** Se solicita almacenar simultáneamente `edad` (que cambia cada año y se desactualiza) y `fecha_nacimiento` (que revela un identificador exacto innecesario si solo se requieren rangos demográficos).
3. **Ausencia de restricciones de integridad y tipos de datos laxos (`TEXT` sin límites ni `NOT NULL`):** Todas las columnas están definidas como `TEXT` sin longitud máxima ni validaciones, sin clave primaria explícita (`PRIMARY KEY`) y sin columna de control de ciclo de vida (`fecha_alta`).
4. **Concentración de todos los dominios en una sola tabla monolítica:** Se mezclan datos de contacto (`correo`, `telefono`), domicilio físico (`direccion`), datos fiscales (`rfc`) y datos socioeconómicos (`salario`), provocando que cualquier consulta a `clientes` exponga toda la vida privada del titular.

### 2. ¿Qué principio de privacidad se está ignorando?
Se ignoran directamente los principios de **Minimización de datos**, **Limitación de la finalidad**, **Proporcionalidad / Necesidad** y **Privacidad por diseño y por defecto**. Recolectar datos "por si algún día se ocupan" está expresamente prohibido por los marcos de protección de datos personales.

### 3. ¿Qué preguntas realizarías antes de aprobar el diseño?
1. ¿Cuál es la **finalidad específica, actual y documentada** en el Aviso de Privacidad para cada una de las columnas propuestas?
2. ¿Qué proceso operativo o requisito legal exige conocer el `salario`, `ocupacion` o `estado_civil` del cliente? (Si no existe, se rechazan).
3. ¿El cliente requiere facturación fiscal o envío a domicilio desde el primer momento, o solo al realizar una compra específica?
4. ¿Qué roles necesitarán consultar cada subconjunto de atributos y durante cuánto tiempo se conservarán?

### 4. ¿Qué datos eliminarías?
Eliminaría de inmediato del diseño general:
- `salario` (dato patrimonial/financiero innecesario para comercializar productos normales).
- `estado_civil` (dato personal irrelevante para la relación comercial).
- `ocupacion` (innecesario para la operación).
- `fecha_nacimiento` (si solo se requiere estadística demográfica, basta con un rango de edad opcional o ni siquiera recolectarla; y si hay RFC, la fecha ya está implícita para fines fiscales).

### 5. ¿Qué datos requerirían una justificación adicional?
- `rfc` y `codigo_postal`: solo deben solicitarse si el cliente requiere **emisión de factura electrónica (CFDI)**.
- `direccion`: solo debe solicitarse si el cliente solicita **entrega física a domicilio**.
- `telefono`: solo si el canal de soporte o entrega requiere contacto telefónico.

### 6. ¿Cómo aplicarías privacidad por defecto (*Privacy by Default*)?
1. **Recolección mínima obligatoria:** En el registro inicial solo solicitar `nombre` y `correo` (los únicos con `NOT NULL`), dejando los datos fiscales o de envío en tablas separadas (`clientes_datos_fiscales`, `clientes_direcciones`) que solo se llenan cuando el cliente solicita explícitamente ese servicio.
2. **Opciones de privacidad restrictivas por omisión:** Cualquier bandera de tratamientos secundarios (como `acepta_marketing`) debe tener `DEFAULT FALSE`.
3. **Permisos cerrados por defecto en PostgreSQL:** Revocar privilegios de `PUBLIC` (`REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;`), cifrar datos fiscales (`rfc_cifrado`) y exponer a cada rol únicamente vistas minimizadas.

---

## 4. Análisis

Un error de diseño en el `CREATE TABLE` inicial se multiplica durante años en respaldos, réplicas, bitácoras y aplicaciones. Aplicar *Privacidad por Diseño* significa cuestionar y depurar el modelo entidad-relación **antes** de crear la tabla en producción.

---

## 5. Conclusión

Almacenar más columnas "por si acaso" no aporta valor técnico y sí multiplica el riesgo legal y de seguridad. El DBA y el arquitecto de datos deben rechazar atributos sin finalidad comprobada y separar los datos opcionales o sensibles desde el diseño del esquema.
