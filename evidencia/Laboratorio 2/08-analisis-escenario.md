# Evidencia 08 — Análisis de un Escenario de Seguridad

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-02 — Cifrado, credenciales y comunicaciones seguras
- **Motor:** PostgreSQL 16

---

## 1. Objetivo

Evaluar los riesgos de seguridad de una organización que, pese a contar con usuarios y roles bien definidos en PostgreSQL, presenta deficiencias críticas en el almacenamiento de credenciales, cifrado de datos sensibles, validación de conexiones TLS, resguardo de claves criptográficas y protección de respaldos.

---

## 2. Comando o procedimiento

Evaluación técnica del escenario planteado en la Actividad 8 (Sección 15):
- **Activos almacenados:** `nombre`, `correo electrónico`, `contraseña`, `RFC`, `información financiera`, `claves criptográficas`.
- **Controles existentes:** Usuarios y roles de base de datos correctamente configurados.
- **Debilidades detectadas:**
  1. Contraseñas almacenadas en texto claro.
  2. RFC almacenado en texto claro.
  3. Conexiones sin validación adecuada de la identidad del servidor.
  4. Claves criptográficas escritas dentro de archivos SQL.
  5. Respaldos almacenados sin protección adicional.

---

## 3. Resultado obtenido (Respuestas al Escenario)

### Pregunta 1: ¿Cuáles son los principales riesgos?
1. **Compromiso masivo de cuentas (*Account Takeover*):** Al estar las contraseñas en texto claro, cualquier filtración de tabla, respaldo o registro permite tomar control inmediato de las cuentas de los usuarios y reutilizar esas credenciales en otros sistemas.
2. **Exposición total mediante respaldos no cifrados:** Aunque la base de datos en producción tenga roles y permisos estrictos, un atacante o administrador de sistemas que acceda al archivo de respaldo (`pg_dump` o copia física sin cifrar) puede leer todas las tablas (`contraseñas`, `RFC`, `información financiera`) saltándose por completo el control de acceso de PostgreSQL.
3. **Inutilización del cifrado por exposición de claves en scripts SQL:** Tener las claves criptográficas escritas dentro de archivos `.sql` permite que cualquier persona con acceso al repositorio Git, servidor de aplicaciones o bitácoras descifre la información financiera o fiscal protegida.
4. **Ataques de intermediario (*Man-in-the-Middle* / suplantación de servidor):** Al no validar adecuadamente el certificado y el nombre del servidor (`sslmode` débil en lugar de `verify-full`), un atacante en la red puede interceptar conexiones o suplantar al servidor PostgreSQL para capturar credenciales, consultas e información financiera en tránsito.
5. **Robo de identidad y fraude fiscal/financiero:** La exposición conjunta de `nombre`, `correo`, `RFC` e `información financiera` en texto claro facilita fraudes bancarios, suplantación fiscal e incumplimiento grave de normativas de protección de datos.

---

### Pregunta 2: ¿Qué mecanismo utilizarías para cada elemento?

| Elemento | Mecanismo de protección recomendado |
| :--- | :--- |
| **Nombre y correo electrónico** | Control de acceso por mínimo privilegio (`GRANT`/`REVOKE`), enmascaramiento en vistas para áreas operativas (soporte) y seudonimización para analítica. |
| **Contraseña** | Derivación de claves para contraseñas con sal aleatoria única (`Argon2id` o `bcrypt` mediante `crypt(..., gen_salt('bf'))`), eliminando cualquier almacenamiento en texto claro. |
| **RFC** | Cifrado simétrico en reposo (`pgp_sym_encrypt` / AES) para almacenamiento y enmascaramiento parcial cuando solo se requiera validación visual. |
| **Información financiera** | Cifrado fuerte en reposo (AES-256), tokenización para procesamiento de pagos, auditoría estricta de acceso y cifrado de respaldos. |
| **Claves criptográficas** | Almacenamiento externo en un gestor de secretos o servicio KMS/HSM (fuera de archivos SQL y fuera de Git), con inyección segura en memoria y rotación periódica. |
| **Conexiones al servidor** | TLS 1.2 / 1.3 obligatorio en el servidor (`ssl = on`) y validación estricta en los clientes mediante `sslmode=verify-full` con certificados emitidos por una CA confiable. |
| **Respaldos de base de datos** | Cifrado completo de los archivos de respaldo en reposo (AES-256 / GPG) con claves custodiadas por separado y control de acceso al almacenamiento de backups. |

---

### Pregunta 3: ¿Cuál de los problemas consideras más crítico y por qué?
El problema más crítico es la combinación de **respaldos almacenados sin protección junto con contraseñas en texto claro y claves criptográficas incrustadas en scripts SQL**:
- Un respaldo sin cifrar contiene una fotografía completa de toda la base de datos fuera del motor PostgreSQL, donde los roles y permisos (`GRANT`/`REVOKE`) no tienen ningún efecto.
- Si además ese respaldo o el repositorio incluye las contraseñas en texto claro y las claves criptográficas en archivos SQL, un solo incidente de lectura sobre el almacenamiento de respaldos o el repositorio compromete simultáneamente el 100 % de las identidades de los usuarios, sus datos fiscales (RFC) y su información financiera.

---

### Pregunta 4: ¿Tener correctamente configurados los usuarios y permisos elimina estos riesgos? Justifica tu respuesta.
**No.** Los usuarios, roles y permisos (`GRANT`/`REVOKE`) únicamente controlan qué puede hacer una sesión autenticada **dentro del motor de PostgreSQL**, pero **no protegen contra amenazas que ocurren fuera de la capa de autorización SQL**, tales como:
1. Un atacante que intercepta el tráfico de red cuando no se usa TLS con verificación del servidor (`verify-full`).
2. Alguien que obtiene acceso a los archivos físicos en disco o a los **respaldos sin cifrar** en un servidor de almacenamiento.
3. Un usuario autorizado (o una vulnerabilidad de inyección SQL) que consulta una tabla permitida donde las contraseñas están en texto claro.
4. La filtración de claves criptográficas almacenadas dentro de scripts en un repositorio Git.

---

## 4. Análisis

Este escenario demuestra el principio de **defensa en profundidad**: el control de acceso (LAB-01) es indispensable pero insuficiente si no se complementa con protección criptográfica de credenciales, cifrado en reposo de datos críticos y respaldos, TLS para las comunicaciones y una gestión segura de claves (LAB-02).

---

## 5. Conclusión

La seguridad de una base de datos debe evaluarse de extremo a extremo. Configurar roles correctamente no evita la exposición si las contraseñas están en texto claro, las claves residen en archivos SQL, los respaldos carecen de cifrado o las conexiones de red no validan al servidor mediante TLS.
