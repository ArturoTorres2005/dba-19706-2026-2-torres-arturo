# Evidencia 01 — Inventario y Finalidad de los Datos

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Catalogar los atributos almacenados en la tabla `clientes` de Comercializadora Norte S.A. de C.V., determinando cuáles constituyen datos personales, cuál es su finalidad legítima de tratamiento, su necesidad operativa/legal, el nivel de acceso permitido por rol y su periodo de retención justificado.

---

## 2. Procedimiento

Revisión estructural de los 9 atributos de `public.clientes` frente a los procesos de negocio definidos por la organización (Atención al cliente, Facturación, Analítica y Administración de Base de Datos) bajo el marco conceptual de la LFPDPPP.

---

## 3. Resultado (Matriz de Inventario y Finalidad)

| Campo | ¿Es dato personal? | Finalidad | ¿Es necesario? | Nivel de acceso | Retención |
| :--- | :---: | :--- | :---: | :--- | :--- |
| `id` | Sí (identificador indirecto / interno asociado a persona física) | Identificación interna única del registro del cliente y relación referencial entre tablas operativas. | **Sí** | Restringido (Atención al cliente, Facturación y DBA; oculto/seudonimizado en Analítica). | Vigencia de la relación comercial + 5 años fiscales. |
| `nombre` | **Sí** (Identificador directo) | Identificación nominal del titular para atención de solicitudes y emisión de comprobantes fiscales (CFDI). | **Sí** | Restringido (Atención al cliente, Facturación, DBA). Sin acceso para Analítica. | Vigencia contractual + 5 años por obligación fiscal/mercantil. |
| `correo` | **Sí** (Identificador directo / contacto) | Comunicación transaccional con el cliente, seguimiento de soporte y envío de facturas electrónicas. | **Sí** | Restringido (Atención al cliente, Facturación). Enmascarado o excluido según subproceso; sin acceso en Analítica. | Vigencia de la cuenta activa + periodo de prescripción legal (5 años). |
| `telefono` | **Sí** (Identificador directo / contacto) | Contacto directo para soporte técnico, aclaraciones o confirmación de pedidos. | **Sí** (para soporte/contacto) | Restringido únicamente a Atención al cliente (parcial o completo según nivel) y DBA. | Mientras la cuenta esté activa; eliminación tras inactividad confirmada. |
| `rfc` | **Sí** (Identificador directo oficial / fiscal) | Cumplimiento de obligaciones fiscales y emisión de facturas electrónicas ante el SAT. | **Sí** (solo si requiere factura) | **Confidencial / Muy restringido** (exclusivo para Facturación y DBA; prohibido en Soporte y Analítica). | 5 años conforme al art. 30 del Código Fiscal de la Federación (CFF). |
| `edad` | **Sí** (Cuasi-identificador demográfico asociado al titular) | Segmentación estadística y análisis demográfico del mercado. | **Parcial** (no necesario para operación básica; útil solo como rango en analítica) | Acceso únicamente generalizado por rangos (`v_analitica_clientes`) para Analítica. | Mientras sea útil para estadística agregada; luego anonimización irreversible. |
| `ciudad` | **Sí** (Cuasi-identificador geográfico mientras esté vinculado al cliente) | Logística de atención regional y análisis estadístico de distribución geográfica de clientes. | **Sí** | Atención al cliente (operación) y Analítica (únicamente de forma agregada/estadística). | Vigencia de la relación comercial + 5 años; posteriormente solo conteos agregados. |
| `codigo_postal` | **Sí** (Cuasi-identificador geográfico y dato fiscal para CFDI 4.0) | Validación de domicilio fiscal para facturación (CFDI 4.0) y estadística regional por zonas postales. | **Sí** | Facturación (dato exacto) y Analítica (solo prefijo regional generalizado). | 5 años por requisito fiscal de comprobantes emitidos. |
| `fecha_alta` | **Sí** (Atributo temporal vinculado al titular / Cuasi-identificador) | Control administrativo del ciclo de vida del cliente, antigüedad y ejecución de la política de retención. | **Sí** | Interno / Operativo (DBA y sistemas de auditoría/retención). | Vigencia del registro hasta su depuración definitiva a los 5 años de inactividad. |

---

## 4. Análisis y Justificación por Decisión

1. **`id`, `nombre`, `correo` y `telefono`:** Son indispensables para ejecutar el contrato y atender solicitudes del titular (Atención al cliente), pero no deben exponerse al área de Analítica porque la finalidad estadística no requiere conocer la identidad ni contactar al individuo.
2. **`rfc` y `codigo_postal`:** Tienen una finalidad estrictamente **fiscal y regulatoria** (emisión de facturas CFDI). Por ello, el área de Atención al cliente no necesita consultar el RFC, mientras que Facturación sí lo requiere.
3. **`edad` y `ciudad`:** Para fines de Analítica, no se requiere la edad exacta vinculada al nombre, sino únicamente **rangos de edad** y conteos por ciudad, aplicando minimización y limitación de finalidad.
4. **`fecha_alta`:** Es el atributo rector de gobierno de datos que permite automatizar el cálculo del vencimiento del periodo de conservación (5 años).

---

## 5. Conclusión

Todo atributo almacenado en una base de datos debe contar con una finalidad legítima declarada. Si un campo no tiene una finalidad clara o se entrega a un área que no lo necesita para su función, se vulneran los principios de finalidad y minimización de datos.
