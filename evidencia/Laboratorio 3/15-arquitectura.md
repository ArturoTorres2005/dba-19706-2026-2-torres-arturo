# Evidencia 15 — Propuesta de Arquitectura de Datos Protegidos por Finalidad

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-03 — Privacidad, cumplimiento y gobierno de los datos
- **Motor:** PostgreSQL 18 / 16

---

## 1. Objetivo

Diseñar una arquitectura conceptual e integral en PostgreSQL que separe físicamente y lógicamente la información de Comercializadora Norte S.A. de C.V. de acuerdo con su finalidad (Operación, Analítica y Auditoría/Cumplimiento), integrando controles de acceso, minimización, protección de datos sensibles, retención, trazabilidad, eliminación y atención de solicitudes ARCO.

---

## 2. Procedimiento

Diseño de arquitectura por esquemas y capas de acceso en PostgreSQL 18 / 16 conforme a los requerimientos de la Actividad 15 (Sección 21).

---

## 3. Resultado (Arquitectura Propuesta)

### Diagrama Conceptual de la Arquitectura en PostgreSQL

```text
                           SERVIDOR POSTGRESQL (TLS 1.3 + pg_hba.conf estricto)
                                                    │
        ┌───────────────────────────────────────────┼───────────────────────────────────────────┐
        │                                           │                                           │
        ▼                                           ▼                                           ▼
┌───────────────────────────────┐     ┌───────────────────────────────┐     ┌───────────────────────────────┐
│   1. CAPA DE OPERACIÓN        │     │   2. CAPA DE ANALÍTICA        │     │ 3. CAPA DE AUDITORÍA Y        │
│   (Esquemas: public / pii)    │     │   (Esquema: analitica)        │     │    GOBIERNO (Esquema: audit)  │
├───────────────────────────────┤     ├───────────────────────────────┤     ├───────────────────────────────┤
│ • Tabla: pii.clientes_base    │     │ • Tabla: analitica.clientes   │     │ • Tabla: audit.solicitudes_   │
│   (id, nombre, correo, tel,   │     │   (cliente_token UUID,        │     │   arco (folio, id_cliente,    │
│    ciudad, edad, fecha_alta,  │     │    rango_edad, prefijo_cp,    │     │   tipo_derecho, fecha, autor) │
│    consentimiento_mkt,        │     │    ciudad, anio_alta)         │     │ • Tabla: audit.bitacora_      │
│    estado_ciclo_vida)         │     │                               │     │   cambios (usuario, accion,   │
│ • Tabla: pii.datos_fiscales   │     │ • Vista: analitica.v_resumen  │     │   tabla, timestamp, motivo)   │
│   (cliente_id, rfc_cifrado,   │     │   (conteos agregados con      │     │ • Tabla: audit.historial_     │
│    codigo_postal)             │     │    HAVING COUNT(*) >= 5)      │     │   depuracion_retencion        │
│ • Tabla: pii.mapa_cliente     │     └──────────────┬────────────────┘     └──────────────┬────────────────┘
│   (token UUID <-> cliente_id) │                    │                                     │
└──────────────┬────────────────┘                    ▼                                     ▼
               │                             Roles autorizados:                    Roles autorizados:
               ▼                             • rol_analista (seudonimizado)        • rol_auditor / DPO
     Vistas minimizadas por rol:             • rol_direccion (solo agregados)      • rol_dba (custodia técnica)
     • v_clientes_soporte (Rol: soporte)
     • v_clientes_facturacion (Rol: facturacion)
     • v_clientes_marketing (Rol: marketing, solo opt-in)
```

---

### Detalle de los 7 Controles Integrados en la Arquitectura

#### 1. Control de Acceso (`ROLES`, `GRANT`, `REVOKE`)
- **Bloqueo directo a tablas base:** Ningún usuario operativo ni analítico tiene permiso `SELECT` directo sobre el esquema `pii`.
- **Separación por rol funcional:**
  - `rol_soporte`: solo consulta `v_clientes_soporte` (`id`, `nombre`, `correo` y `telefono` enmascarados).
  - `rol_facturacion`: solo consulta `v_clientes_facturacion` (`id`, `nombre`, `correo`, `rfc` descifrado bajo función controlada y `codigo_postal`).
  - `rol_marketing`: solo consulta `v_clientes_marketing` (filtrada con `WHERE consentimiento_mkt = TRUE AND estado_ciclo_vida = 'ACTIVO'`).
  - `rol_analista`: solo consulta el esquema `analitica` (sin acceso al esquema `pii` ni a `pii.mapa_cliente`).

#### 2. Minimización de Datos
- Separación de `pii.datos_fiscales` respecto a los datos generales de contacto: el RFC y código postal fiscal solo se almacenan para los clientes que solicitan facturación.
- En la capa de `analitica`, se eliminan de origen `nombre`, `correo`, `telefono` y `rfc`, y se almacenan únicamente atributos generalizados (`rango_edad` y prefijo postal).
- Para ambientes de **Desarrollo y Pruebas (QA)**, se prohíbe copiar el esquema `pii`; se genera un script de datos sintéticos (`faker` / `pgcrypto`).

#### 3. Protección de Información Sensible y Credenciales
- **En reposo:** El `rfc` se almacena cifrado en formato `BYTEA` (`pgp_sym_encrypt`) con claves gestionadas fuera de la base de datos (KMS/Vault), y las contraseñas de aplicación utilizan derivación irreversible con sal (`bcrypt` / `Argon2id`). Los respaldos (`pg_dump`) se cifran con AES-256.
- **En tránsito:** Conexiones obligatorias mediante **TLS 1.3 / 1.2** con validación de certificado (`sslmode=verify-full`).

#### 4. Retención de Datos
- La columna `fecha_alta` (junto con `fecha_ultima_operacion` y `estado_ciclo_vida`) permite ejecutar un trabajo programado mensual que identifica registros inactivos por más de **5 años** (`WHERE fecha_alta < CURRENT_DATE - INTERVAL '5 years'`).
- Los registros que cumplen su periodo pasan primero a estado `'BLOQUEADO'` (cuarentena previa) y, tras la aprobación de Jurídico/DPO y Negocio, pasan a eliminación segura.

#### 5. Trazabilidad
- El esquema `audit` registra mediante *triggers* o `pgaudit` toda operación de lectura privilegiada, rectificación (`UPDATE`), bloqueo o cancelación (`DELETE`), almacenando el identificador del ticket de autorización, el rol ejecutor y la marca de tiempo (`TIMESTAMP WITH TIME ZONE`).

#### 6. Eliminación Segura
- Cuando se aprueba la depuración por retención o por cancelación ARCO (vencido el plazo legal de bloqueo), una transacción controlada elimina el registro en `pii.datos_fiscales`, `pii.mapa_cliente` y `pii.clientes_base`, dejando únicamente el conteo estadístico anónimo en la capa `analitica` y el acta sin datos personales en `audit.historial_depuracion_retencion`.

#### 7. Atención de Solicitudes de Derechos ARCO
- **Acceso:** Procedimiento almacenado que extrae de `pii.clientes_base` y `pii.datos_fiscales` la ficha completa del titular validado y registra la entrega en `audit.solicitudes_arco`.
- **Rectificación:** `UPDATE` acotado exclusivamente al campo solicitado, vinculado al folio del ticket ARCO en la bitácora de auditoría.
- **Cancelación:** Cambio de `estado_ciclo_vida = 'BLOQUEADO'` (que lo excluye inmediatamente de todas las vistas de soporte, marketing y facturación) seguido de su borrado definitivo al cumplirse el plazo fiscal.
- **Oposición:** Cambio inmediato de `consentimiento_mkt = FALSE`, excluyendo automáticamente al cliente de la vista `v_clientes_marketing` sin afectar su operación primaria.

---

## 4. Análisis

Esta arquitectura demuestra cómo los principios jurídicos de la LFPDPPP (finalidad, minimización, proporcionalidad, calidad, retención y derechos ARCO) se traducen directamente en objetos nativos de PostgreSQL (esquemas separados, vistas filtradas, funciones criptográficas, estados de bloqueo y tablas de trazabilidad).

---

## 5. Conclusión

Separar la base de datos en tres dominios claros (**Operación**, **Analítica** y **Auditoría/Gobierno**) impide que las necesidades de un área comprometan la privacidad de los titulares en otra, garantizando tanto la seguridad técnica como el cumplimiento normativo.
