# Informe Técnico — LABORATORIO 01: Protección y Privacidad de Datos (LAB-01)

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** II — Seguridad, privacidad y control de acceso
- **Tema:** 2.3 — Datos sensibles, privacidad y protección de la información
- **Motor:** PostgreSQL 16
- **Modalidad:** Práctica individual
- **Escenario:** Comercializadora Norte S.A. de C.V.

---

## Actividad 1 — Clasificación de los datos (`sql/01-clasificacion.sql`)

### Matriz de Clasificación de la tabla `public.clientes`

| Campo | ¿Identifica directamente? | ¿Puede contribuir a identificar? | ¿Requiere protección? | Justificación |
| :--- | :---: | :---: | :---: | :--- |
| `id` | No (identificador interno) | Sí | Sí | Es una clave primaria sustituta interna. Aunque no revela por sí sola el nombre en el mundo físico, permite vincular de forma única al registro del titular dentro del sistema o cruzar tablas operativas. |
| `nombre` | **Sí** | Sí | **Sí** | Identificador directo nominal de la persona física titular de los datos. Expone directamente la identidad civil del cliente. |
| `correo` | **Sí** | Sí | **Sí** | Identificador directo único en el ámbito digital y medio de contacto directo; suele contener el nombre y apellido del titular y su divulgación facilita ataques de *phishing* o suplantación. |
| `telefono` | **Sí** | Sí | **Sí** | Identificador directo de contacto personal asociado a una línea única del titular; requiere protección contra exposición, fraude telefónico (*vishing*) o contacto no autorizado. |
| `rfc` | **Sí** | Sí | **Sí** | Identificador oficial fiscal único en México (Registro Federal de Contribuyentes). Además de identificar legal y fiscalmente a la persona, revela las iniciales de su nombre y su fecha exacta de nacimiento (`AAMMDD`). |
| `edad` | No | **Sí** (Cuasi-identificador) | **Sí** | Por sí sola no identifica a una persona, pero al combinarse con código postal y ciudad reduce significativamente el grupo de individuos posibles (riesgo de singularización). |
| `ciudad` | No | **Sí** (Cuasi-identificador) | **Sí** | Atributo geográfico que acota la ubicación del titular. En localidades con pocos clientes o combinado con edad y fecha de alta, facilita la reidentificación. |
| `codigo_postal` | No | **Sí** (Cuasi-identificador) | **Sí** | Cuasi-identificador geográfico de alta precisión (delimita una colonia o zona postal reducida). Junto con `edad` es una de las combinaciones clásicas más críticas de reidentificación. |
| `fecha_alta` | No | **Sí** (Cuasi-identificador) | **Sí** | Atributo temporal operativo utilizado para retención; actúa como cuasi-identificador si se cruza con eventos conocidos de registro o si existen pocos clientes dados de alta en una fecha específica. |

### Respuestas a las preguntas de la Actividad 1

1. **¿Qué campos identifican directamente a una persona?**
   Los campos `nombre`, `correo`, `telefono` y `rfc` (y de manera relacional interna dentro de la base de datos, el `id` del cliente). Cualquiera de ellos permite señalar de forma individual y directa a un titular sin necesidad de combinar otros atributos demográficos.

2. **¿Qué campos no identifican por sí mismos pero podrían contribuir a hacerlo?**
   Los campos `edad`, `ciudad`, `codigo_postal` y `fecha_alta`. Funcionan como **cuasi-identificadores**: aisladamente muchos individuos comparten una misma ciudad o una misma edad, pero combinados acotan el universo hasta individualizar un registro.

3. **¿Qué combinación de campos podría incrementar el riesgo de reidentificación?**
   La combinación **`(edad, codigo_postal, ciudad)`**, o bien **`(edad, codigo_postal, fecha_alta)`**. En el conjunto de datos de prueba, incluso dentro de una misma ciudad (`Culiacán`), cada cliente tiene una combinación única de `edad` y `codigo_postal` (`41 y 80000`, `35 y 80100`, `38 y 80200`), lo que permite reidentificar al 100 % de los registros aunque se eliminen `nombre`, `correo`, `telefono` y `rfc`.

4. **¿Todos los datos que deben protegerse son necesariamente datos personales sensibles desde el punto de vista jurídico?**
   **No.** Desde el punto de vista jurídico (por ejemplo, en la LFPDPPP en México o el RGPD europeo), los *datos personales sensibles* son una categoría especial (origen racial o étnico, estado de salud, creencias religiosas, opiniones políticas, preferencia sexual, biométricos). Datos identificativos, de contacto o fiscales como `nombre`, `correo`, `telefono` o `rfc` son **datos personales** (o patrimoniales/identificativos), no estrictamente "sensibles" en el sentido jurídico estricto, pero **igualmente requieren protección técnica y administrativa** porque su divulgación vulnera la privacidad del titular y puede ocasionar fraude, robo de identidad o incumplimiento legal.

---

## Actividad 2 — Enmascaramiento (`sql/02-enmascaramiento.sql`)

### Evidencia de Ejecución y Permisos

- **Permisos aplicados:**
  ```sql
  CREATE ROLE soporte NOLOGIN;
  GRANT USAGE ON SCHEMA public TO soporte;
  GRANT SELECT ON v_clientes_soporte TO soporte;
  REVOKE ALL ON clientes FROM soporte;
  ```
- **Resultado de la consulta a la vista (`SET ROLE soporte; SELECT * FROM v_clientes_soporte;`):**
  ```text
   id |    nombre     |         correo          |  telefono  |      rfc      
  ----+---------------+-------------------------+------------+---------------
    1 | Ana López     | an*****@example.test    | ******4567 | *********5ABC
    2 | Carlos Pérez  | ca*****@example.test    | ******5678 | *********0DEF
    3 | María García  | ma*****@example.test    | ******6789 | *********2GHI
    4 | Luis Torres   | lu*****@example.test    | ******7890 | *********1JKL
    5 | Laura Sánchez | la*****@example.test    | ******8901 | *********5MNO
  (5 filas)
  ```
- **Resultado del intento de consultar la tabla base (`SET ROLE soporte; SELECT * FROM clientes;`):**
  ```text
  ERROR:  permiso denegado para la tabla clientes
  SQLSTATE: 42501
  ```

### Respuestas a las preguntas de la Actividad 2

1. **¿Qué información continúa existiendo en la tabla original?**
   En la tabla física `public.clientes` continúan almacenados intactos todos los datos originales completos (`nombre`, `correo`, `telefono`, `rfc`, `edad`, `ciudad`, `codigo_postal` y `fecha_alta`). El enmascaramiento mediante vista no altera ni destruye el dato almacenado en disco; únicamente transforma su presentación al momento de la consulta.

2. **¿Qué información puede visualizar el usuario `soporte`?**
   Únicamente las columnas proyectadas por la vista `v_clientes_soporte`: el `id`, el `nombre` completo, los primeros 2 caracteres y el dominio del `correo` (`an*****@example.test`), los últimos 4 dígitos del `telefono` (`******4567`) y los últimos 4 caracteres del `rfc` (`*********5ABC`). Además, no visualiza `edad`, `ciudad`, `codigo_postal` ni `fecha_alta`.

3. **¿Por qué no es suficiente ocultar los datos únicamente en la aplicación?**
   Porque si el control solo reside en la capa de presentación (interfaz web o aplicación cliente), pero la cuenta de base de datos o el rol utilizado tiene `SELECT` directo sobre la tabla `clientes`, cualquier usuario con acceso a un cliente SQL, reporteador, API mal configurada o vulnerabilidad de inyección SQL podrá consultar la tabla original sin restricciones. La seguridad debe aplicarse en el motor de base de datos (*defensa en profundidad*).

4. **¿Qué ocurriría si `soporte` tuviera acceso directo a `clientes`?**
   La vista `v_clientes_soporte` sería completamente inútil como control de seguridad, ya que el rol `soporte` podría evadirla ejecutando `SELECT * FROM public.clientes;` y obtener en texto claro todos los correos, teléfonos y RFC completos de los clientes.

---

## Actividades 3 y 4 — Seudonimización y Separación de Funciones (`sql/03-seudonimizacion.sql`)

### Evidencia de Ejecución

- **Generación de tokens (`SELECT * FROM pii.mapa_cliente;` como administrador):**
  ```text
                  token                 | cliente_id 
  --------------------------------------+------------
   a4f8d2c1-7b3e-4c9a-8f12-3e5b9a1d7c01 |          1
   b9e1c4a2-5d8f-4e1b-9a34-7c2d6f8e3b02 |          2
   c7d3b6e4-2a1c-4f8d-b567-9e1a4c5d2f03 |          3
   d2a5f8c6-9e4b-4a2e-8c89-1b3f7e9a4d04 |          4
   e8c1a3f9-6b7d-4d5c-a123-5f8e2b6c9a05 |          5
  (5 filas)
  ```
- **Consulta permitida para `analista` (`SET ROLE analista; SELECT * FROM analitica.clientes;`):**
  ```text
              cliente_token             | edad |   ciudad   | codigo_postal | fecha_alta 
  --------------------------------------+------+------------+---------------+------------
   a4f8d2c1-7b3e-4c9a-8f12-3e5b9a1d7c01 |   41 | Culiacán   | 80000         | 2026-10-23
   b9e1c4a2-5d8f-4e1b-9a34-7c2d6f8e3b02 |   35 | Culiacán   | 80100         | 2026-10-23
   c7d3b6e4-2a1c-4f8d-b567-9e1a4c5d2f03 |   47 | Mazatlán   | 82000         | 2026-10-23
   d2a5f8c6-9e4b-4a2e-8c89-1b3f7e9a4d04 |   34 | Los Mochis | 81200         | 2026-10-23
   e8c1a3f9-6b7d-4d5c-a123-5f8e2b6c9a05 |   38 | Culiacán   | 80200         | 2026-10-23
  (5 filas)
  ```
- **Consulta rechazada sobre `pii.mapa_cliente` (`SET ROLE analista; SELECT * FROM pii.mapa_cliente;`):**
  ```text
  ERROR:  permiso denegado para el esquema pii
  SQLSTATE: 42501
  ```
- **Consulta rechazada sobre `public.clientes` (`SET ROLE analista; SELECT * FROM public.clientes;`):**
  ```text
  ERROR:  permiso denegado para la tabla clientes
  SQLSTATE: 42501
  ```

### Respuestas a las preguntas de la Actividad 4

1. **¿Qué ocurriría si `analista` pudiera consultar también `pii.mapa_cliente`?**
   Podría realizar un `JOIN` trivial entre `analitica.clientes.cliente_token` y `pii.mapa_cliente.token` (o correlacionar los identificadores) para revertir inmediatamente la seudonimización, anulando el propósito del control.

2. **¿Qué principio de seguridad se está aplicando al separar ambos accesos?**
   Se aplican conjuntamente el principio de **Separación de funciones (*Separation of Duties*)** y el principio de **Mínimo privilegio (*Least Privilege*)**, garantizando que el rol que analiza patrones estadísticos o de negocio no posea la llave de correspondencia que vincula los seudónimos con las identidades reales.

3. **¿Por qué la seudonimización no equivale a anonimización?**
   Porque en la seudonimización los registros siguen siendo individuales por persona y **existe información adicional (`pii.mapa_cliente`) que permite revertir el proceso y reidentificar al titular**, además de conservarse cuasi-identificadores individuales (`edad`, `ciudad`, `codigo_postal`, `fecha_alta`). Por tanto, los datos seudonimizados siguen siendo datos personales.

4. **¿Qué información permite volver a relacionar el token con una persona?**
   En primer lugar, la **tabla de correspondencia `pii.mapa_cliente`**, que asocia directamente `token <-> cliente_id` hacia `public.clientes`. En segundo lugar, incluso sin `pii.mapa_cliente`, la combinación de cuasi-identificadores exactos (`edad = 47`, `ciudad = 'Mazatlán'`, `codigo_postal = '82000'`) permitiría vincular el token con María García si se dispone de una fuente externa o del padrón de clientes.

---

## Actividades 5 y 6 — Anonimización y Análisis del Riesgo de Reidentificación (`sql/04-anonimizacion.sql`)

### Resultados de las consultas de la Actividad 5

1. **12.1 Generalizar la edad:**
   ```text
    rango_edad | total 
   ------------+-------
    31-45      |     4
    46+        |     1
   (2 filas)
   ```
2. **12.2 Generalizar la región (`LEFT(codigo_postal, 2)`):**
   ```text
    region | total 
   --------+-------
    80     |     3
    81     |     1
    82     |     1
   (3 filas)
   ```
3. **12.3 Combinar atributos (`rango_edad` + `region`):**
   ```text
    rango_edad | region | total 
   ------------+--------+-------
    31-45      | 80     |     3
    31-45      | 81     |     1
    46+        | 82     |     1
   (3 filas)
   ```
4. **12.4 Suprimir grupos pequeños (`HAVING COUNT(*) >= 5`):**
   ```text
    rango_edad | region | total 
   ------------+--------+-------
   (0 filas)
   ```
   *(Al existir solo 5 clientes en total distribuidos en tres grupos de tamaños 3, 1 y 1, ningún grupo individual de la combinación `(rango_edad, region_2_digitos)` alcanza los 5 registros, por lo que `HAVING COUNT(*) >= 5` suprime los grupos pequeños para evitar exponer grupos con menos de 5 individuos).*

### Respuestas a las preguntas de la Actividad 6

1. **¿Qué identificadores directos fueron eliminados?**
   Fueron eliminados de la proyección todos los identificadores directos e internos: `id`, `nombre`, `correo`, `telefono`, `rfc` y el `cliente_token`.

2. **¿Qué cuasi-identificadores permanecen?**
   Permanecen formas generalizadas de dos cuasi-identificadores: la edad transformada en `rango_edad` (`18-30`, `31-45`, `46+`) y el código postal truncado a sus dos primeros dígitos como `region` (`80`, `81`, `82`).

3. **¿Qué combinaciones de atributos podrían reducir el anonimato?**
   La combinación `(rango_edad, region)` (y más aún si se añadiera `ciudad` o `fecha_alta`). Como se observa en la consulta 12.3, al cruzar `rango_edad` con `region`, surgen grupos con `total = 1`: `('46+', '82')` y `('31-45', '81')`. Cualquier persona que sepa que un cliente vive en la región postal `82` (Mazatlán) o `81` (Los Mochis) puede singularizar su registro de inmediato.

4. **¿Qué sucede cuando un grupo contiene pocos registros?**
   Cuando un grupo (clase de equivalencia) tiene muy pocos registros (especialmente $k = 1$ o $k = 2$), el riesgo de **singularización (*singling out*)** e inferencia es crítico: permite identificar a una persona única dentro de esa categoría o deducir atributos sensibles de todos los miembros del grupo si comparten una misma característica (falta de $l$-diversidad).

5. **¿Qué atributos deberían generalizarse?**
   - `edad`: en intervalos más amplios cuando la población es pequeña (por ejemplo, `30-50` en lugar de separar `31-45` y `46+`).
   - `codigo_postal`: a nivel de macro-región estatal (`LEFT(codigo_postal, 1) || 'xxxx'`, es decir, `8xxxx`) en lugar de 2 dígitos cuando ciertas subregiones tienen un solo cliente.
   - `fecha_alta`: a nivel de año (`EXTRACT(YEAR FROM fecha_alta)`) o periodo plurianual si se incluye en reportes.

6. **¿Qué información debería suprimirse?**
   - Todos los identificadores directos (`nombre`, `correo`, `telefono`, `rfc`, `id`).
   - Atributos redundantes o de alta granularidad geográfica (`ciudad` exacta y los últimos 3 o 4 dígitos de `codigo_postal`).
   - Los **grupos o filas agregadas que no alcancen el umbral mínimo $k$** (`HAVING COUNT(*) >= 5`), para impedir la publicación de celdas con conteos de 1 a 4 individuos.

7. **¿Es correcto afirmar que el conjunto de datos es “100 % anónimo”? ¿Por qué?**
   **No, no es correcto.** En privacidad de datos no existe el "anonimato 100 % absoluto" de forma aislada del contexto:
   - Un umbral como `COUNT(*) >= 5` ($k$-anonimato con $k=5$) es un control útil contra la singularización directa en los cuasi-identificadores seleccionados, pero **es vulnerable a ataques de homogeneidad** (si los 5 registros del grupo comparten otro atributo sensible) y a **ataques de conocimiento previo o cruce con fuentes externas (*background knowledge* y ataques diferenciales)** si alguien compara reportes publicados en distintos momentos.

### Documentación del Reto (Actividad 6)

- **Cambio realizado:**
  ```sql
  SELECT
      CASE
          WHEN edad < 30 THEN 'Menor de 30'
          WHEN edad BETWEEN 30 AND 50 THEN '30-50'
          ELSE 'Mayor de 50'
      END AS macro_rango_edad,
      CONCAT(LEFT(codigo_postal, 1), 'xxxx') AS macro_region_postal,
      EXTRACT(YEAR FROM fecha_alta)::INTEGER AS anio_alta,
      COUNT(*) AS total_clientes
  FROM clientes
  GROUP BY 1, 2, 3
  HAVING COUNT(*) >= 5;
  ```
- **Motivo:**
  En la consulta 12.3, la división por prefijo postal de 2 dígitos (`80`, `81`, `82`) y el corte de edad en `45` aislaban a María García (`47 años, CP 82000`) y a Luis Torres (`34 años, CP 81200`) en grupos de 1 sola persona (`total = 1`), provocando además que la consulta 12.4 con `HAVING COUNT(*) >= 5` devolviera `0 filas`. Al ampliar la jerarquía de generalización de edad al rango `30-50` y la región al primer dígito postal (`8xxxx`, nivel estatal), se reduce la granularidad de los cuasi-identificadores sin perder la métrica agregada para Dirección.
- **Resultado obtenido:**
  ```text
    macro_rango_edad | macro_region_postal | anio_alta | total_clientes 
   ------------------+---------------------+-----------+----------------
    30-50            | 8xxxx               |      2026 |              5
   (1 fila)
  ```
- **Riesgo que se pretende reducir:**
  Se elimina la presencia de grupos unitarios ($k=1$) en Mazatlán (`82`) y Los Mochis (`81`), reduciendo el riesgo de **singularización geográfica y etaria**, al tiempo que se preserva el filtro `HAVING COUNT(*) >= 5` para impedir la exposición de cualquier subgrupo con menos de 5 titulares.

---

## Actividad 7 — Retención de Datos (`sql/05-retencion.sql`)

### Consulta ejecutada

```sql
SELECT *
FROM clientes
WHERE fecha_alta < CURRENT_DATE - INTERVAL '5 years';
```

### Documentación de Retención

1. **¿Qué registros serían afectados?**
   - En el estado inicial de la práctica, como los 5 clientes de prueba se crearon con `fecha_alta DEFAULT CURRENT_DATE` (`2026-10-23`), la consulta devuelve `0 filas` porque ningún registro supera los 5 años de antigüedad.
   - Serían afectados todos los registros cuya `fecha_alta` sea estrictamente menor a `CURRENT_DATE - INTERVAL '5 years'` (es decir, anteriores al `2021-10-23`) y que ya no mantengan una relación activa o bloqueo legal.
2. **¿Cuál sería la justificación del periodo?**
   - Atiende al principio de **limitación del plazo de conservación** y **minimización de datos**: los datos personales solo deben conservarse durante el tiempo necesario para cumplir la finalidad para la que fueron recabados y las obligaciones legales aplicables (por ejemplo, el plazo de 5 años establecido en el artículo 30 del Código Fiscal de la Federación para conservar documentación fiscal y contable). Conservarlos más allá de ese plazo incrementa innecesariamente el impacto ante una brecha de seguridad.
3. **¿Qué aprobación debería existir antes de eliminar información?**
   - Debe existir una solicitud formal de cambio (*Change Request*) aprobada de manera mancomunada por:
     1. **Área Jurídica / Oficial de Protección de Datos (DPO):** verifica que no existan auditorías, requerimientos de autoridad o litigios vigentes (*legal hold*).
     2. **Dueño del Proceso / Dirección Comercial:** confirma que las cuentas están inactivas y sin obligaciones contractuales pendientes.
     3. **Administración de Base de Datos (DBA):** valida el alcance técnico de la sentencia y la ventana de ejecución.
4. **¿Qué respaldo debería existir?**
   - Antes de cualquier depuración definitiva debe verificarse la existencia e integridad de un **respaldo completo y/o lógico cifrado** (`pg_dump` cifrado con AES-256 o snapshot del volumen de base de datos) sujeto a su propia política de retención y acceso restringido exclusivamente a recuperación ante desastres.
5. **¿Qué evidencia debería conservarse?**
   - Un **acta y bitácora de depuración (log de auditoría)** que registre: identificador del ticket de autorización, fecha y hora exacta de ejecución, usuario/rol ejecutor, criterio de filtrado aplicado (`WHERE fecha_alta < ...`), cantidad total de filas procesadas y confirmación de integridad referencial (incluyendo la limpieza correspondiente en `pii.mapa_cliente` y `analitica.clientes`), **sin almacenar en texto plano los datos personales eliminados**.
6. **¿Qué procedimiento permitiría recuperar información eliminada accidentalmente?**
   - **Prevención operativa:** Ejecutar toda depuración dentro de un bloque transaccional (`BEGIN; ... COMMIT;`), validando previamente el número de registros afectados y aplicando primero un periodo de *bloqueo o cuarentena lógica* antes del borrado físico.
   - **Recuperación reactiva:** Si se confirma una eliminación accidental, utilizar **Point-in-Time Recovery (PITR)** mediante los archivos WAL de PostgreSQL 16 o restaurar el respaldo previo en una instancia temporal aislada para extraer y reinsertar únicamente los registros afectados en `public.clientes` y `pii.mapa_cliente`.

---

## 19. Informe Consolidado por Sección

### 19.1 Clasificación
En la tabla `public.clientes` se identificaron dos grandes grupos de atributos que requieren protección:
- **Identificadores directos (`nombre`, `correo`, `telefono`, `rfc`) e identificador interno (`id`):** requieren el nivel más alto de protección (control de acceso estricto, enmascaramiento o supresión según el rol) porque señalan de forma unívoca a una persona física, y en el caso del `rfc` revelan además su fecha de nacimiento y situación fiscal.
- **Cuasi-identificadores (`edad`, `ciudad`, `codigo_postal`, `fecha_alta`):** requieren protección mediante generalización y agregación cuando se comparten con áreas de dirección o terceros, ya que su combinación permite reidentificar a un individuo dentro de grupos pequeños.

### 19.2 Enmascaramiento
- **¿Qué se ocultó?** Se ocultaron parcialmente el `correo` (mostrando solo los 2 primeros caracteres y el dominio), el `telefono` (mostrando solo los últimos 4 dígitos) y el `rfc` (mostrando solo los últimos 4 caracteres), y se omitieron las columnas `edad`, `ciudad`, `codigo_postal` y `fecha_alta`.
- **¿Para quién?** Para el rol `soporte` (Área de Soporte).
- **¿Por qué?** Porque el área de soporte necesita identificar al cliente por su nombre y validar los últimos dígitos de su teléfono, RFC o dominio de correo para atender solicitudes, pero bajo el principio de mínimo privilegio no necesita ver los identificadores completos en texto claro.
- **¿Qué mecanismo se utilizó?** Enmascaramiento dinámico basado en una vista de PostgreSQL (`CREATE VIEW v_clientes_soporte`) combinando funciones de cadena (`CONCAT`, `LEFT`, `RIGHT`, `SUBSTRING`, `POSITION`) junto con control de acceso (`GRANT SELECT ON v_clientes_soporte TO soporte` y `REVOKE ALL ON clientes FROM soporte`).

### 19.3 Seudonimización
- **¿Cómo se generaron los tokens?** Mediante la función criptográfica `gen_random_uuid()` de la extensión `pgcrypto` de PostgreSQL 16, generando un identificador `UUID` v4 aleatorio e impredecible por cada cliente.
- **¿Dónde se encuentra el mapa de correspondencia?** En una tabla dedicada `pii.mapa_cliente(token, cliente_id)` alojada dentro del esquema aislado `pii`.
- **¿Quién debería poder acceder a él?** Únicamente el Administrador de la Base de Datos (DBA) o procesos automatizados de ingesta/integración expresamente autorizados y auditados; nunca el rol `analista` ni el rol `soporte`.
- **¿Por qué se separaron los permisos?** Aplicando el principio de **separación de funciones**: si el analista que consulta `analitica.clientes` también pudiera leer `pii.mapa_cliente` o `public.clientes`, podría cruzar los tokens y reconstruir la identidad real de todos los clientes.

### 19.4 Anonimización
- **¿Qué identificadores fueron eliminados?** Se eliminaron `id`, `nombre`, `correo`, `telefono`, `rfc` y `cliente_token`.
- **¿Qué atributos fueron generalizados?** La `edad` se transformó en intervalos (`18-30`, `31-45`, `46+` y en el reto `30-50`), y el `codigo_postal` se truncó a prefijos regionales (`LEFT(codigo_postal, 2)` y en el reto `LEFT(codigo_postal, 1) || 'xxxx'`).
- **¿Qué grupos fueron suprimidos?** Mediante la cláusula `HAVING COUNT(*) >= 5` se suprimieron todos los grupos cuya combinación de atributos contenía menos de 5 registros (en la consulta 12.3 se suprimieron los grupos de tamaño 3, 1 y 1).
- **¿Qué riesgo de reidentificación permanece?** Permanece el riesgo derivado de conjuntos de datos pequeños, conocimiento previo del atacante (*background knowledge*), ataques de homogeneidad (cuando todos los miembros de un grupo de 5 comparten un mismo rasgo) y ataques por diferencia entre consultas sucesivas.

### 19.5 Retención
- **¿Qué criterio se utilizó?** Antigüedad de registro superior a 5 años evaluada sobre la columna `fecha_alta` (`WHERE fecha_alta < CURRENT_DATE - INTERVAL '5 years'`).
- **¿Qué información debería conservarse?** Los registros de clientes activos o cuya antigüedad sea menor o igual a 5 años (o que tengan obligaciones contractuales, fiscales o legales vigentes), así como estadísticas agregadas no identificables.
- **¿Qué información podría eliminarse?** Los datos personales identificables (`public.clientes`, su entrada en `pii.mapa_cliente` y registros individuales asociados) de exclientes inactivos que hayan superado el plazo legal y operativo de 5 años.
- **¿Qué controles deberían existir antes de eliminarla?** Aprobación formal (Jurídico/DPO, Negocio y DBA), validación de ausencia de bloqueos legales, respaldo cifrado previo, ejecución en transacción controlada (preferentemente con cuarentena/bloqueo lógico previo) y generación de bitácora de auditoría.

### 19.6 Conclusiones
1. **¿Qué técnica utilizarías para un área de soporte?**
   **Enmascaramiento dinámico mediante vistas restringidas (`VIEW`) + control de acceso (`GRANT`/`REVOKE`)**, porque soporte necesita tratar con un cliente específico y verificar su identidad parcial sin visualizar ni extraer el padrón completo de datos sensibles.
2. **¿Qué técnica utilizarías para un área de analítica?**
   **Seudonimización mediante tokens (`UUID`) + separación de funciones en esquemas distintos (`analitica` vs. `pii`)**, porque analítica requiere trabajar a nivel de registros individuales para detectar patrones y correlaciones, pero sin conocer quién es la persona física detrás de cada registro.
3. **¿Qué técnica utilizarías para publicar estadísticas?**
   **Anonimización mediante generalización de cuasi-identificadores, agregación (`GROUP BY`, `COUNT`) y supresión de grupos pequeños (`HAVING COUNT(*) >= k`)**, porque el consumidor de estadísticas (Dirección o publicación externa) solo requiere tendencias macro y no registros individuales.
4. **¿Por qué ninguna de estas técnicas sustituye al control de acceso?**
   Porque las técnicas de transformación (vistas enmascaradas, tablas seudonimizadas o consultas agregadas) pueden ser evadidas por completo si un usuario mantiene privilegios de lectura (`SELECT`) sobre las tablas originales (`public.clientes`) o sobre las tablas de correspondencia (`pii.mapa_cliente`). El control de acceso es la base que garantiza que cada rol solo pueda interactuar con la capa de transformación que le corresponde.

---

## 20. Preguntas de Reflexión

1. **¿Cuál es la diferencia entre enmascaramiento y seudonimización?**
   El **enmascaramiento** oculta total o parcialmente la representación visual de un atributo sensible (por ejemplo, `an*****@example.test` o `******4567`) al presentarlo a un usuario operativo como soporte, manteniendo el registro vinculado a la persona. En cambio, la **seudonimización** sustituye los identificadores directos de la persona por un identificador artificial o sustituto (`token`), separando la identidad real en una tabla de correspondencia protegida para permitir el procesamiento analítico sin atribución directa.

2. **¿Por qué la seudonimización no significa anonimización?**
   Porque la seudonimización es **reversible** mediante información adicional (la tabla `pii.mapa_cliente`) y conserva registros individuales cuyos cuasi-identificadores pueden permitir la reidentificación. La anonimización, por el contrario, busca que la identificación del titular ya no sea razonablemente posible por ningún medio disponible.

3. **¿Por qué eliminar nombre y RFC no garantiza que un conjunto de datos sea anónimo?**
   Porque permanecen en el registro otros atributos denominados **cuasi-identificadores** (como `edad`, `ciudad`, `codigo_postal` y `fecha_alta`). La combinación de pocos cuasi-identificadores suele ser única para una persona dentro de una población o muestra (por ejemplo, una persona de 47 años en el código postal `82000` de Mazatlán), permitiendo su reidentificación al cruzar con directorios o padrones externos.

4. **¿Qué función tienen los cuasi-identificadores?**
   Son atributos demográficos, geográficos o temporales que por sí mismos no identifican a un individuo de forma directa, pero que al combinarse entre sí actúan como una "huella digital" capaz de singularizar a una persona dentro de un conjunto de datos y vincularla con su identidad real.

5. **¿Por qué es importante separar el mapa de seudonimización?**
   Porque el mapa de seudonimización (`pii.mapa_cliente`) equivale a la "llave criptográfica" que revierte los seudónimos. Si el mapa se almacena en el mismo esquema o con los mismos permisos que los datos analíticos, cualquier persona con acceso a los datos analíticos puede unir ambas tablas (`JOIN`) y deshacer la protección instantáneamente.

6. **¿Qué principio de seguridad se aplica al impedir que el analista acceda al mapa?**
   Se aplican el principio de **Separación de funciones (*Separation of Duties*)** y el principio de **Mínimo privilegio (*Least Privilege*)**: ningún rol único debe concentrar simultáneamente el acceso a los datos de análisis y a la tabla que permite reidentificar a los titulares, y cada rol recibe estrictamente los permisos indispensables para su función.

7. **¿Por qué una vista puede ser preferible a entregar acceso directo a la tabla?**
   Porque una vista (`VIEW`) actúa como una capa de control y abstracción en el motor de base de datos: permite **filtrar columnas** (ocultar atributos que el rol no necesita), **filtrar filas** y **transformar valores al vuelo** (como enmascarar correo, teléfono y RFC) sin duplicar datos físicamente y sin exponer la tabla base `public.clientes`.

8. **¿Qué diferencia existe entre proteger un dato para visualización y protegerlo contra acceso no autorizado?**
   Proteger un dato para **visualización** (por ejemplo, ocultar caracteres en la pantalla de una aplicación o en un reporte visual) solo evita la exposición casual en la interfaz de usuario, pero no impide que alguien con credenciales de base de datos consulte el dato original si tiene permisos sobre la tabla. Protegerlo **contra acceso no autorizado** implica aplicar controles reales en el motor de base de datos (`REVOKE`, `GRANT`, esquemas separados, cifrado) para garantizar que un sujeto no autorizado no pueda leer ni extraer el dato por ninguna vía técnica.

9. **¿Por qué la retención forma parte de la protección de datos?**
   Porque la privacidad y la seguridad siguen el ciclo de vida completo de la información. Cumplir con el principio de minimización y limitación del plazo de conservación obliga a no retener datos personales una vez agotada su finalidad legal u operativa; un dato que ya fue eliminado de forma segura tras cumplir su ciclo de retención ya no puede ser robado, filtrado ni utilizado indebidamente.

10. **¿Qué riesgo existe si una organización conserva información indefinidamente?**
    Aumenta drásticamente la **superficie de exposición y el impacto de una brecha de seguridad** (se comprometen millones de registros históricos innecesarios en lugar de solo los vigentes), se incurre en **incumplimiento normativo y sanciones regulatorias** por violar los principios de finalidad y conservación, se dificulta la atención de derechos ARCO/cancelación y se incrementan los costos operativos de almacenamiento, respaldo y aseguramiento.
