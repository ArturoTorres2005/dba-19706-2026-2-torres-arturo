# Evidencia 07 — Comparación entre Protección en Reposo y Protección en Tránsito

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-02 — Cifrado, credenciales y comunicaciones seguras
- **Motor:** PostgreSQL 16

---

## 1. Objetivo

Distinguir qué mecanismo criptográfico o de gestión de seguridad corresponde a cada tipo de activo de información (credenciales, datos sensibles almacenados, comunicaciones por red, respaldos y claves criptográficas) y precisar qué riesgo específico mitiga cada uno.

---

## 2. Comando o procedimiento

Análisis comparativo de los estados de la información (en reposo, en tránsito y gestión de secretos) aplicado al escenario de Comercializadora Norte S.A. de C.V. (Actividad 7 / Sección 14).

---

## 3. Resultado obtenido (Tabla Comparativa)

| Situación | Mecanismo apropiado | ¿Qué protege? |
| :--- | :--- | :--- |
| **Contraseña de usuario** | **Derivación de claves para contraseñas (*Password Hashing* con sal aleatoria, ej. `bcrypt` / `Argon2id` / `scrypt`)** | Protege el secreto de autenticación en reposo de forma **irreversible**, evitando que quien lea la tabla de usuarios o un respaldo pueda recuperar la contraseña en texto claro. |
| **RFC almacenado en una tabla** | **Cifrado simétrico en reposo (`pgp_sym_encrypt` / AES)** combinado con control de acceso | Protege la **confidencialidad del dato sensible en reposo** dentro de la tabla, permitiendo recuperar el valor original (descifrado) únicamente a procesos o usuarios autorizados que posean la clave. |
| **Consulta enviada desde un cliente al servidor** | **TLS (`Transport Layer Security` 1.2 / 1.3 con `sslmode=verify-full`)** | Protege los **datos en tránsito** a través de la red, brindando confidencialidad (contra *sniffing*), integridad (contra modificación de paquetes) y autenticación de la identidad del servidor. |
| **Respaldo de una base de datos** | **Cifrado del respaldo en reposo (ej. AES-256 / GPG / KMS sobre archivos `pg_dump` o snapshots)** | Protege la **confidencialidad de la copia histórica completa de la base de datos** frente a robo, pérdida o acceso no autorizado al medio de almacenamiento externo o en la nube. |
| **Clave criptográfica** | **Gestión segura de claves (*Key Management System* / KMS / HSM / Bóveda de secretos)** y separación de los datos cifrados | Protege el **secreto maestro de cifrado** durante todo su ciclo de vida (generación, resguardo fuera del código/BD, acceso auditado, rotación y revocación), evitando que el cifrado sea vulnerado. |

---

## 4. Análisis

- Los datos atraviesan diferentes estados: **en reposo** (tablas de PostgreSQL y archivos de respaldo) y **en tránsito** (paquetes que viajan entre el cliente y el puerto `5432` del servidor).
- Proteger el canal con **TLS** impide que un atacante en la red intercepte la consulta, pero una vez que el dato se guarda en el disco del servidor o se extrae en un respaldo, TLS deja de actuar; ahí se requiere **cifrado en reposo** (para datos que deben recuperarse como el RFC) o **derivación/hash de contraseñas** (para credenciales que nunca deben recuperarse).
- A su vez, tanto el cifrado de tablas como el cifrado de respaldos dependen de la **gestión segura de claves**: si la clave se guarda junto con la base de datos o en el repositorio Git, el cifrado en reposo pierde su efectividad.

---

## 5. Conclusión

Ningún mecanismo criptográfico cubre todos los estados del dato por sí solo. Una arquitectura de base de datos segura debe combinar derivación irreversible para contraseñas, cifrado en reposo para atributos sensibles y respaldos, TLS con verificación de certificado para las comunicaciones en red y un sistema externo de gestión de claves.
