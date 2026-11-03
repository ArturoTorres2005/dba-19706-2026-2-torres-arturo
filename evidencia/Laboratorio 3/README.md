# LAB-03 — Privacidad, Cumplimiento y Gobierno de los Datos

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** II. Seguridad, privacidad y control de acceso
- **Tema:** 2.5 Privacidad, cumplimiento y gobierno de los datos
- **Motor principal:** PostgreSQL 18 / 16
- **Modalidad:** Individual

---

## Estructura del Laboratorio

```text
lab-03-privacidad-cumplimiento/
├── README.md
├── sql/
│   ├── 01-minimizacion.sql
│   ├── 02-finalidad.sql
│   └── 03-control-acceso.sql
└── evidencias/
    ├── 01-inventario-datos.md
    ├── 05-finalidad-secundaria.md
    ├── 08-ciclo-vida.md
    ├── 10-retencion.md
    ├── 11-gobierno-datos.md
    ├── 12-privacidad-diseno.md
    ├── 14-evaluacion-integral.md
    └── 15-arquitectura.md
```

---

## 1. Introducción

La protección técnica de una base de datos mediante permisos y cifrado no garantiza por sí sola el cumplimiento en materia de **privacidad y gobierno de datos**. Antes de proteger un atributo, la organización (**Comercializadora Norte S.A. de C.V.**) debe cuestionar si realmente necesita recolectarlo, para qué finalidad legítima lo trata, quién es el responsable de autorizar su uso, durante cuánto tiempo debe conservarse y cómo responder técnicamente ante el ejercicio de los **derechos ARCO** (Acceso, Rectificación, Cancelación y Oposición) bajo el marco de la **LFPDPPP**. En este laboratorio se tradujeron dichos principios de privacidad en decisiones y controles concretos dentro de PostgreSQL.

---

## 2. Inventario de datos

Se analizaron los 9 atributos de la tabla `public.clientes`:
- **Identificadores directos y de contacto (`nombre`, `correo`, `telefono`):** Datos personales necesarios para la atención operativa y comunicación con el cliente.
- **Identificador fiscal oficial (`rfc`):** Dato personal de carácter fiscal/patrimonial que requiere protección reforzada y acceso exclusivo para el proceso de facturación.
- **Identificador interno (`id`) y cuasi-identificadores (`edad`, `ciudad`, `codigo_postal`, `fecha_alta`):** Datos que vinculados al titular son datos personales y cuyo uso debe acotarse según la finalidad (por ejemplo, `codigo_postal` exacto para facturación CFDI 4.0, pero generalizado por rangos o regiones para estadística, y `fecha_alta` como eje rector de retención).

*(El detalle completo se documenta en [evidencias/01-inventario-datos.md](./01-inventario-datos.md)).*

---

## 3. Finalidades

Se establecieron cuatro finalidades diferenciadas dentro de la organización:
1. **Atención al cliente (Soporte):** Identificar y contactar al cliente para resolver solicitudes (`id`, `nombre`, `correo`, `telefono`).
2. **Facturación:** Cumplimiento fiscal y emisión de comprobantes CFDI (`id`, `nombre`, `rfc`, `codigo_postal`, `correo`).
3. **Analítica:** Generación de estadísticas demográficas y geográficas agregadas (`ciudad`, `rango_edad`) sin identificar individualmente a ningún titular.
4. **Administración de Base de Datos (DBA):** Custodia técnica de estructuras, respaldos y controles de acceso, sin autorización para explotar los datos con fines distintos.

Asimismo, se analizó en [evidencias/05-finalidad-secundaria.md](./05-finalidad-secundaria.md) que el envío de promociones personalizadas constituye una **finalidad secundaria** que no puede ejecutarse automáticamente solo porque la empresa ya posee los datos; requiere estar contemplada en el Aviso de Privacidad, respetar el consentimiento/oposición del titular y limitar técnicamente las columnas expuestas.

---

## 4. Minimización

En la Actividad 2 (`sql/01-minimizacion.sql`), ante la solicitud de Atención al cliente de crear una tabla `clientes_soporte` con las 9 columnas completas de `clientes`, se aplicó el **principio de minimización de datos**:
- **¿Por qué soporte no necesita `rfc`, `edad`, `ciudad`, `codigo_postal` ni `fecha_alta`?** Porque ninguno de esos atributos es necesario para atender una solicitud de soporte; incluirlos incrementaría innecesariamente la superficie de exposición de datos fiscales y demográficos.
- Se implementó la estructura mínima estrictamente necesaria:
  ```sql
  CREATE TABLE clientes_soporte (
      id BIGINT PRIMARY KEY,
      nombre VARCHAR(120) NOT NULL,
      correo VARCHAR(150) NOT NULL,
      telefono VARCHAR(20)
  );
  ```

---

## 5. Control de acceso

En las Actividades 3 y 4 (`sql/02-finalidad.sql` y `sql/03-control-acceso.sql`), se vinculó el control de acceso directamente con la finalidad de **Analítica**:
- Se diseñaron consultas agregadas por `ciudad` y por intervalos de `rango_edad` (`Menor de 18`, `18-29`, `30-44`, `45-59`, `60 o más`).
- Se creó el rol `analista` (`NOLOGIN`) y la vista `v_analitica_clientes` que proyecta únicamente `ciudad` y `rango_edad`.
- Se otorgó `GRANT SELECT ON v_analitica_clientes TO analista` y se revocó todo permiso sobre la tabla base `clientes`. De este modo, el rol `analista` cumple su finalidad estadística sin poder consultar jamás `nombre`, `correo`, `telefono` ni `rfc`.

---

## 6. Derechos ARCO

Se analizaron y probaron las implicaciones técnicas de los cuatro derechos ARCO en PostgreSQL:
- **Acceso (Actividad 6):** Localización precisa de todos los datos del titular (`SELECT ... FROM clientes WHERE correo = ...`), debiendo acompañarse administrativamente de la información sobre las finalidades, origen y transferencias realizadas.
- **Rectificación (Actividad 7):** Actualización acotada del atributo inexacto (`UPDATE clientes SET correo = 'nuevo-correo@example.com' WHERE id = 1;`), destacando la necesidad de **trazabilidad** (registrar qué ticket autorizó el cambio, quién lo ejecutó y cuándo).
- **Cancelación (Actividad 8 — [evidencias/08-ciclo-vida.md](./08-ciclo-vida.md)):** Un simple `DELETE` en `public.clientes` no borra automáticamente la información en tablas derivadas (`clientes_soporte`, `pii.mapa_cliente`), respaldos, réplicas, bitácoras (`logs`), archivos exportados ni ambientes de pruebas, además de requerirse un bloqueo previo cuando persisten obligaciones legales de conservación.
- **Oposición (Actividad 9):** Cuando un cliente se opone a una finalidad secundaria (como promociones), **no es necesario ni procedente eliminar todos sus datos de la base principal** si sigue siendo cliente activo (pues aún se requieren sus datos para facturación y soporte); en su lugar, se aplica un control técnico de separación (ej. `consentimiento_marketing = FALSE`) que lo excluye de la vista de mercadotecnia.

---

## 7. Retención

En la Actividad 10 ([evidencias/10-retencion.md](./10-retencion.md)) se rechazó la propuesta de *"conservar todos los datos indefinidamente"*:
- El periodo de conservación debe determinarse identificando la vigencia de la finalidad operativa más los plazos legales y fiscales obligatorios (como los **5 años** del art. 30 del Código Fiscal de la Federación).
- Una vez vencido dicho plazo, los identificadores personales deben eliminarse de forma segura o anonimizarse irreversiblemente, documentando la justificación legal, el evento disparador (`fecha_alta` / baja) y la bitácora de depuración.

---

## 8. Gobierno de datos

En la Actividad 11 ([evidencias/11-gobierno-datos.md](./11-gobierno-datos.md)) se construyó la matriz de responsabilidades diferenciando entre:
- **Propietario de los datos (*Data Owner*):** Gerencia de Atención al Cliente, Dirección de Finanzas/Facturación y Gerencia de Analítica, quienes definen la necesidad funcional.
- **Custodio de los datos (*Data Custodian*):** El **DBA**, quien implementa los controles técnicos (`GRANT`/`REVOKE`, vistas, cifrado y retención) sin decidir por cuenta propia las finalidades del negocio.

---

## 9. Evaluación integral

En la Actividad 14 ([evidencias/14-evaluacion-integral.md](./14-evaluacion-integral.md)) se auditó el escenario de 50,000 clientes identificando 10 riesgos críticos, entre ellos: acceso directo de analítica a `clientes`, conservación excesiva por 12 años sin política de retención, entrega de copias con **datos reales a desarrolladores** y uso de correos para marketing sin validación de finalidad ni consentimiento. Asimismo, en [evidencias/15-arquitectura.md](./15-arquitectura.md) se diseñó la arquitectura en tres capas (**Operación**, **Analítica** y **Auditoría**).

---

## 10. Conclusiones

La privacidad y la seguridad son complementarias pero distintas: una base de datos puede estar cifrada y tener contraseñas robustas (seguridad), y aun así incumplir la ley si recolecta atributos excesivos, conserva registros por 12 años sin justificación, comparte copias reales en desarrollo o utiliza los datos para finalidades no autorizadas (privacidad). El DBA debe trabajar en coordinación con las áreas jurídica, de privacidad y de negocio para traducir cada principio de privacidad en controles técnicos verificables dentro de PostgreSQL.

---

## 27. Preguntas de Reflexión

1. **¿Una base de datos técnicamente segura necesariamente cumple con todos los requisitos de privacidad?**
   **No.** Una base de datos puede contar con TLS, cifrado en reposo y contraseñas robustas, pero violar la privacidad si recolecta datos innecesarios (`salario`, `estado_civil`), si los utiliza para finalidades no consentidas (spam promocional), si los conserva indefinidamente o si no permite atender solicitudes de derechos ARCO.

2. **¿Por qué el principio de mínimo privilegio también contribuye a la privacidad?**
   Porque al garantizar que cada rol (`soporte`, `analista`, `facturacion`) acceda únicamente a las columnas y filas indispensables para su finalidad específica, se evita la exposición interna innecesaria y el tratamiento no autorizado de datos personales dentro de la propia organización.

3. **¿Por qué el DBA no debería decidir por sí solo la finalidad del tratamiento de los datos?**
   Porque la finalidad del tratamiento tiene implicaciones legales, contractuales y de negocio que competen al Responsable del tratamiento (Dirección, Propietario de los datos, Área Jurídica y Oficial de Privacidad). El rol del DBA es ser el **custodio técnico** que implementa y hace cumplir en el motor de base de datos las decisiones autorizadas.

4. **¿Por qué los desarrolladores no deberían recibir automáticamente copias completas de bases de datos productivas?**
   Porque el desarrollo y prueba de software no requiere conocer la identidad, RFC ni teléfono real de 50,000 clientes; entregar copias reales viola el principio de minimización y limitación de finalidad, y traslada datos críticos a entornos donde los controles de acceso suelen ser mucho más permisivos.

5. **¿Por qué una copia utilizada para desarrollo también puede representar un riesgo de privacidad?**
   Porque contiene exactamente los mismos datos personales reales que producción, pero suele almacenarse en equipos locales, contenedores de prueba o servidores sin monitoreo estricto, convirtiéndose en un vector frecuente de filtración de datos personales y permaneciendo fuera del alcance cuando un titular ejerce su derecho de cancelación.

6. **¿Por qué la retención debe formar parte del ciclo de vida de los datos?**
   Porque ningún dato personal debe existir eternamente en la organización; una vez cumplida la finalidad operativa y agotados los plazos legales de conservación, el dato debe cerrarse y eliminarse o anonimizarse para reducir el riesgo acumulado de exposición.

7. **¿Qué relación existe entre privacidad por diseño y diseño de bases de datos?**
   *Privacidad por diseño* significa que desde el momento en que se modela el esquema (`CREATE TABLE`), se eligen únicamente los campos estrictamente necesarios, se separan los datos sensibles/fiscales en tablas o esquemas protegidos, se establecen valores por defecto restrictivos y se diseñan las vistas y claves foráneas pensando en la minimización y el borrado futuro.

8. **¿Qué controles técnicos implementarías para reducir el riesgo de exposición de datos personales?**
   Implementaría vistas minimizadas y enmascaradas por rol (`CREATE VIEW`), revocación de acceso directo a tablas base (`REVOKE ALL`), seudonimización y agregación en esquemas separados para analítica, cifrado simétrico de columnas sensibles (`pgp_sym_encrypt`), TLS en tránsito, anonimización/datos sintéticos para entornos de desarrollo y procedimientos automatizados de retención.

9. **¿Qué información debería conocer un DBA para responder técnicamente a una solicitud ARCO?**
   Debe conocer el **inventario y mapa completo de datos** (en qué esquemas, tablas principales, tablas derivadas, vistas materializadas, respaldos y réplicas reside la información del titular), el identificador único del registro verificado, el folio de autorización emitido por el área de privacidad/jurídico y las restricciones de integridad referencial o bloqueo legal aplicables.

10. **¿Qué responsabilidades deberían corresponder al DBA, al responsable de privacidad, al área jurídica y al propietario de los datos?**
    - **Propietario de los datos (*Data Owner*):** Define qué datos requiere su proceso de negocio y qué usuarios necesitan acceso funcional.
    - **Área Jurídica:** Determina el marco legal aplicable, redacta el Aviso de Privacidad, define los plazos legales/fiscales de conservación y valida la procedencia legal de solicitudes o transferencias.
    - **Responsable / Oficial de Privacidad (DPO):** Supervisa el cumplimiento de los principios de privacidad, gestiona y autoriza la atención de solicitudes ARCO y audita las políticas de gobierno.
    - **DBA (*Data Custodian*):** Diseña e implementa los controles técnicos en PostgreSQL (roles, vistas, permisos, cifrado, respaldos, trazabilidad y ejecución segura de rectificaciones, bloqueos o depuraciones autorizadas).
