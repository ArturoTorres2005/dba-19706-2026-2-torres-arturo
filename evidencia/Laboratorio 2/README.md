# LAB-02 — Cifrado, Credenciales y Comunicaciones Seguras

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Materia:** Gestión de Seguridad y Desempeño de Bases de Datos
- **Unidad:** II. Seguridad, privacidad y control de acceso
- **Tema:** 2.4 Cifrado, credenciales y protección de las comunicaciones
- **Motor principal:** PostgreSQL 16
- **Modalidad:** Individual

---

## Estructura del Laboratorio

```text
lab-02-cifrado-credenciales/
├── README.md
├── sql/
│   ├── 01-credenciales.sql
│   ├── 02-cifrado-datos.sql
│   └── 03-verificacion-tls.sql
└── evidencias/
    ├── 01-credenciales.md
    ├── 02-cifrado-datos.md
    ├── 03-gestion-claves.md
    ├── 04-tls.md
    ├── 07-comparacion.md
    ├── 08-analisis-escenario.md
    └── 10-politica-claves.md
```

---

## 1. Introducción

La seguridad de una base de datos no termina al definir roles y permisos de acceso (`GRANT` y `REVOKE`). Incluso con un control de acceso bien estructurado, la información crítica de una organización (**Comercializadora Norte S.A. de C.V.**) queda expuesta si las contraseñas se almacenan en texto claro, los atributos sensibles se guardan sin cifrar en disco, las comunicaciones entre clientes y el servidor PostgreSQL viajan sin cifrado en la red, los respaldos carecen de protección o las claves criptográficas se incrustan directamente dentro de archivos SQL o repositorios Git. En este laboratorio se implementaron y verificaron en **PostgreSQL 16** los controles correspondientes para proteger credenciales, datos sensibles en reposo, comunicaciones en tránsito mediante TLS y gestión segura de claves.

---

## 2. Protección de credenciales

Existe una diferencia fundamental entre almacenar en texto claro, aplicar un hash/derivación de contraseñas y cifrar:
- **Texto claro (`usuarios_insegura`):** almacena la contraseña legible directamente en la tabla (`'Password123'`). Si un atacante o administrador obtiene lectura sobre la tabla o un respaldo, compromete todas las cuentas de inmediato.
- **Hash / Derivación de contraseñas (`usuarios_segura` con `crypt` y `gen_salt('bf')`):** aplica una transformación matemática **unidireccional (no reversible)** combinada con una **sal aleatoria única** por cada registro. Durante el inicio de sesión no es necesario recuperar la contraseña original: simplemente se vuelve a calcular `crypt('PasswordIngresada', password_hash)` y se compara si el resultado coincide (`t` o `f`).
- **Cifrado:** es un proceso **reversible** mediante una clave secreta, diseñado para datos que necesitan recuperarse posteriormente, por lo que **no debe utilizarse para almacenar contraseñas de usuarios** (ya que quien obtenga la clave podría descifrar todas las contraseñas).

---

## 3. Protección de datos sensibles

En la Actividad 2 se protegió el atributo **`RFC`** de los clientes en la tabla `clientes_protegidos` almacenándolo en la columna `rfc_cifrado` de tipo `BYTEA` mediante cifrado simétrico OpenPGP (`pgp_sym_encrypt('LOPA900101ABC', 'CLAVE-DE-PRUEBA')`).
- **¿Por qué se utilizó cifrado en lugar de hash?** Porque, a diferencia de una contraseña, el RFC es un identificador fiscal que la empresa necesita recuperar en su forma original (`pgp_sym_decrypt`) cuando un proceso autorizado lo requiere (por ejemplo, facturación electrónica o declaraciones fiscales), pero no debe estar legible en texto claro ante consultas directas no autorizadas o lecturas del almacenamiento.

---

## 4. TLS (Transport Layer Security)

- **¿Qué problema resuelve TLS?** Protege la información **en tránsito** mientras viaja por la red entre el cliente (`psql` o la aplicación) y el servidor PostgreSQL, proporcionando tres propiedades:
  1. **Confidencialidad:** cifra el canal para impedir que un observador de red (*sniffing*) lea las consultas SQL o los resultados.
  2. **Integridad:** detecta cualquier modificación no autorizada de los paquetes en tránsito.
  3. **Autenticación del servidor:** mediante certificados digitales y el modo `sslmode=verify-full`, permite al cliente comprobar que el certificado fue emitido por una Autoridad Certificadora (CA) confiable y que el nombre del servidor coincide con el certificado.
- **¿Qué se verificó en PostgreSQL 16?**
  Se ejecutaron los comandos `SHOW ssl;` (`on`), `SHOW ssl_min_protocol_version;` (`TLSv1.2`), `SHOW port;` (`5432`), `SHOW listen_addresses;` y se consultó la vista `pg_stat_ssl` filtrando por el proceso actual (`WHERE pid = pg_backend_pid()`), confirmando una sesión activa con `ssl = t`, versión **`TLSv1.3`** y suite de cifrado **`TLS_AES_256_GCM_SHA384`**.

---

## 5. Gestión de claves

Incrustar claves criptográficas directamente dentro de consultas o scripts SQL (`SELECT pgp_sym_decrypt(rfc_cifrado, 'CLAVE-DE-PRUEBA')`) representa una vulnerabilidad crítica (*hardcoded secret*):
- Si ese script se sube a un repositorio Git, se incluye en respaldos, queda registrado en bitácoras (`postgresql.log`) o aparece en el historial de comandos, cualquier persona con acceso a esos artefactos obtiene la clave para descifrar todos los datos protegidos.
- Además, debido a que Git conserva todo el historial de commits, eliminar una clave en un commit posterior no borra el secreto de los commits previos. Por ello, el archivo demostrativo `sql/ejemplo-mala-practica.sql` fue eliminado antes de la entrega final y se verificó con expresiones regulares la ausencia de secretos reales.

---

## 6. Resultados

1. **Credenciales:** Se comprobó que `gen_salt('bf')` genera sales aleatorias distintas en cada ejecución y que `crypt('Password123', password_hash)` valida correctamente la contraseña (`t`) y rechaza contraseñas inválidas (`f`) sin almacenar ni recuperar el texto claro.
2. **Datos sensibles:** Se almacenó el RFC cifrado en formato binario (`BYTEA`) con `pgp_sym_encrypt` y se comprobó que solo puede recuperarse con la clave correcta mediante `pgp_sym_decrypt`, arrojando `ERROR: Wrong key or corrupt data` ante claves erróneas.
3. **Comunicaciones TLS:** Se verificó la conexión activa en `pg_stat_ssl` operando con `TLSv1.3` (`TLS_AES_256_GCM_SHA384`) y se analizaron las diferencias entre `disable`, `prefer`, `require`, `verify-ca` y `verify-full`.
4. **Política y Escenario:** Se documentó la comparativa entre protección en reposo y en tránsito (`07-comparacion.md`), el análisis de riesgos integrales (`08-analisis-escenario.md`) y la política de 8 reglas para el ciclo de vida de claves criptográficas (`10-politica-claves.md`).

---

## 7. Problemas encontrados

1. **Manejo de claves en consultas SQL:** Al probar `pgp_sym_decrypt`, se observó que pasar la clave como literal dentro de la sentencia SQL la deja expuesta en el texto de la consulta. Se documentó que en entornos reales el cifrado/descifrado o la inyección de la clave debe gestionarse mediante variables de entorno seguras, bóvedas de secretos (KMS/Vault) o en la capa de aplicación autorizada.
2. **Distinción entre `sslmode=require` y `sslmode=verify-full`:** Se identificó que usar únicamente `sslmode=require` cifra el canal pero no valida que el certificado pertenezca al nombre de host esperado, por lo que para prevenir ataques de intermediario (*Man-in-the-Middle*) en producción debe configurarse `sslmode=verify-full` junto con el certificado raíz de la CA.

---

## 8. Conclusiones

- La seguridad de una base de datos requiere aplicar **defensa en profundidad** combinando control de acceso, derivación irreversible de contraseñas, cifrado en reposo de atributos sensibles y respaldos, cifrado en tránsito mediante TLS y gestión externa de claves.
- En un entorno productivo aplicaría:
  1. Hashing de contraseñas con **Argon2id** o **bcrypt** (nunca texto claro ni cifrado reversible).
  2. Cifrado simétrico fuerte (AES-256) para atributos fiscales/financieros y para la totalidad de los **respaldos de base de datos**.
  3. **TLS 1.3 / 1.2** obligatorio en PostgreSQL y conexiones cliente configuradas con `sslmode=verify-full`.
  4. Resguardo de claves criptográficas y credenciales en un **KMS / Gestor de Secretos** externo, con escaneo preventivo de secretos en Git antes de cada commit.

---

## Verificación Final (Sección 18)

- **Credenciales — ¿Una contraseña debe cifrarse o protegerse mediante un mecanismo de derivación de claves para contraseñas?**
  Debe protegerse mediante un **mecanismo de derivación de claves para contraseñas (password hashing con sal aleatoria)**, nunca mediante cifrado reversible.
- **Datos sensibles — ¿Qué diferencia existe entre enmascaramiento, seudonimización y cifrado?**
  - **Enmascaramiento:** oculta parcialmente la visualización de un dato (ej. `******4567`) al presentarlo, manteniendo el dato original en la tabla.
  - **Seudonimización:** sustituye el identificador directo por un token (`UUID`), manteniendo por separado una tabla de correspondencia protegida.
  - **Cifrado:** transforma matemáticamente el dato almacenado en texto cifrado ilegible (`BYTEA`) mediante un algoritmo y una clave criptográfica, de modo que nadie pueda leerlo sin poseer la clave de descifrado.
- **Comunicaciones — ¿Qué problema resuelve TLS?**
  Resuelve el riesgo de observación (*sniffing*), alteración en tránsito y suplantación de identidad del servidor mientras los datos viajan por la red entre el cliente y PostgreSQL.
- **Claves — ¿Dónde debería almacenarse una clave criptográfica en un entorno real?**
  En un **Sistema de Gestión de Claves (KMS)**, **Módulo de Seguridad de Hardware (HSM)** o **Bóveda de Secretos** (como HashiCorp Vault, AWS KMS, GCP Cloud KMS o Azure Key Vault), estrictamente separada del código fuente y de la base de datos.
- **Repositorio — ¿Es correcto subir una contraseña o clave real a GitLab aunque el repositorio sea privado?**
  **No.** Un repositorio privado reduce la exposición pública, pero conserva el secreto en el historial de commits y lo expone a todas las cuentas, tokens de CI/CD y copias locales con acceso al repositorio.

---

## 23. Preguntas de Reflexión

1. **¿Por qué una contraseña no debe almacenarse como texto claro?**
   Porque cualquier acceso de lectura a la tabla (por parte de un administrador, una inyección SQL o una copia de respaldo expuesta) revelaría de inmediato las credenciales de todos los usuarios, permitiendo la toma de control de sus cuentas sin esfuerzo alguno.

2. **¿Por qué un hash no es equivalente a un cifrado?**
   Porque un **hash** es una función **unidireccional (irreversible)** diseñada para verificar integridad o validar secretos sin poder recuperar el valor de entrada, mientras que el **cifrado** es una transformación **bidireccional (reversible)** cuyo propósito es ocultar el contenido para luego recuperarlo íntegro mediante la clave de descifrado.

3. **¿Por qué el cifrado de una columna no sustituye al control de acceso?**
   Porque el control de acceso (`GRANT`/`REVOKE`) define quién puede consultar o modificar qué tablas, vistas y registros dentro de la operación normal de la base de datos, además de proteger la integridad y disponibilidad. Cifrar una columna protege la confidencialidad del valor almacenado, pero no impide por sí solo que un usuario con permisos excesivos borre registros (`DELETE`), altere otras columnas o ejecute funciones de descifrado si tiene acceso a ellas.

4. **¿Por qué TLS no sustituye a los mecanismos de autorización de PostgreSQL?**
   Porque **TLS únicamente protege el canal de comunicación en tránsito** entre el cliente y el servidor. Una vez que el paquete llega al servidor PostgreSQL y es descifrado, son los mecanismos de autenticación y autorización de PostgreSQL (`ROLES`, `GRANT`, `REVOKE`) los que determinan qué objetos tiene permitido consultar o modificar ese usuario.

5. **¿Qué ocurriría si una organización pierde una clave utilizada para cifrar información?**
   La información cifrada con esa clave se volvería **permanentemente irrecuperable**, provocando una pérdida total de disponibilidad de los datos equivalentes a una destrucción física de los mismos.

6. **¿Qué ocurriría si una clave criptográfica se publica accidentalmente en GitLab?**
   El cifrado queda inmediatamente vulnerado: cualquier persona o sistema con acceso al repositorio puede obtener la clave y descifrar los datos protegidos. Además, como la clave queda grabada en el historial de commits de Git, no basta con borrar la línea en un nuevo commit; es obligatorio **revocar la clave, rotarla por una nueva y volver a cifrar todos los datos expuestos**.

7. **¿Por qué un repositorio privado no debe considerarse un almacén de secretos?**
   Porque los repositorios de código están diseñados para versionar código y conservar su historial completo en cada clon local, pipeline de CI/CD y respaldo, careciendo de controles específicos de gestión de secretos como rotación automática, cifrado por hardware (HSM), inyección dinámica de credenciales de corta duración y auditoría granular por lectura de secreto.

8. **¿Qué diferencia existe entre proteger información almacenada y proteger información durante su transmisión?**
   - **Proteger información almacenada (en reposo):** resguarda los datos mientras residen en discos, tablas o respaldos mediante cifrado en reposo o hashing, mitigando el robo de medios físicos, copias de backups o lecturas no autorizadas de archivos.
   - **Proteger información durante su transmisión (en tránsito):** resguarda los datos mientras viajan como paquetes a través de la red entre cliente y servidor mediante protocolos como **TLS**, mitigando la intercepción de tráfico (*sniffing*) y ataques de intermediario (*Man-in-the-Middle*).

9. **¿Por qué la gestión de claves es tan importante como el algoritmo criptográfico?**
   Porque, conforme al principio de Kerckhoffs, la seguridad de un sistema criptográfico moderno reside en la secrecía de la clave y no en ocultar el algoritmo. El algoritmo más robusto del mundo (como AES-256) es completamente inútil si su clave es débil, se incrusta en texto claro dentro de un script SQL o se pierde por falta de respaldo seguro.

10. **¿Qué mecanismo adicional implementarías en una organización para proteger los respaldos de las bases de datos?**
    Implementaría **cifrado automático de respaldos en reposo (AES-256 / GPG)** antes de que el archivo salga del servidor hacia el almacenamiento externo, combinado con:
    - Almacenamiento inmutable (*Object Lock / WORM*) para evitar que un atacante o ransomware elimine o altere los respaldos.
    - Custodia de las claves de descifrado de respaldos en un KMS separado del servidor de base de datos.
    - Pruebas periódicas de restauración y verificación de integridad (hashes SHA-256) en un entorno aislado.
