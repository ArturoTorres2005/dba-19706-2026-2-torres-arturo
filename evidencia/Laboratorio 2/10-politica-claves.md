# Evidencia 10 — Política Mínima de Protección de Claves Criptográficas

- **Alumno:** Arturo Torres Urias
- **Grupo:** 4-3
- **Laboratorio:** LAB-02 — Cifrado, credenciales y comunicaciones seguras
- **Motor:** PostgreSQL 16

---

## 1. Objetivo

Establecer una política formal y verificable de gestión de claves criptográficas (de 8 reglas operativas) para Comercializadora Norte S.A. de C.V. que cubra todo el ciclo de vida de las claves utilizadas para proteger datos sensibles y respaldos de PostgreSQL.

---

## 2. Comando o procedimiento

Diseño normativo de controles para las ocho fases del ciclo de vida de una clave criptográfica requeridas en la Actividad 10 (Sección 17): generación, almacenamiento, acceso, rotación, respaldo, revocación, exposición accidental y eliminación.

---

## 3. Resultado obtenido (Política de Gestión de Claves — 8 Reglas)

### Regla 1 — Generación criptográficamente segura (*Generación*)
Todas las claves criptográficas utilizadas para cifrar columnas de base de datos, respaldos o certificados TLS deberán generarse exclusivamente mediante generadores de números pseudoaleatorios criptográficamente seguros (CSPRNG) con una longitud mínima de **256 bits para cifrado simétrico (AES-256)** y al menos **2048/3072 bits (RSA) o 256 bits (ECDSA)** para claves asimétricas. Queda prohibido utilizar frases predecibles, fechas o contraseñas humanas simples como llaves de cifrado en producción.

### Regla 2 — Separación estricta entre claves, código y datos (*Almacenamiento*)
Las claves criptográficas **jamás deberán almacenarse en texto claro dentro de scripts SQL, código fuente, repositorios de GitLab, ni dentro de las mismas tablas o servidores donde residen los datos cifrados**. En entornos productivos deberán resguardarse en un sistema dedicado de gestión de claves (KMS, HSM o bóveda de secretos como HashiCorp Vault / Secret Manager) e inyectarse únicamente en tiempo de ejecución.

### Regla 3 — Mínimo privilegio y separación de funciones en el uso de claves (*Acceso*)
El acceso a las claves criptográficas estará restringido bajo el principio de mínimo privilegio y separación de funciones: el administrador que custodia el gestor de claves (KMS) no deberá tener acceso irrestricto a los datos de negocio, y los usuarios o servicios de base de datos solo podrán invocar la clave para las operaciones estrictamente autorizadas, registrando cada uso en una bitácora de auditoría inmutable.

### Regla 4 — Rotación periódica programada (*Rotación*)
Las claves simétricas de cifrado de datos y respaldos deberán rotarse de manera programada al menos **cada 12 meses** (y los certificados TLS antes de su vencimiento anual), ejecutando un procedimiento controlado de recifrado de datos con la nueva versión de la clave y desactivando la versión anterior para nuevas operaciones de cifrado.

### Regla 5 — Respaldo cifrado y custodiado de claves (*Respaldo*)
Toda clave empleada para cifrar información almacenada o respaldos de PostgreSQL deberá contar con un respaldo de recuperación seguro, cifrado mediante una clave maestra (*Key Encryption Key* — KEK) y resguardado bajo control dual (*split knowledge* / custodia mancomunada) en una ubicación físicamente o lógicamente separada de los respaldos de datos, garantizando que la organización no pierda el acceso a su propia información.

### Regla 6 — Revocación inmediata ante cambio de funciones o cese de confianza (*Revocación*)
Cuando un certificado de servidor deje de utilizarse, un sistema sea dado de baja o personal con acceso administrativo a secretos cambie de rol o cause baja de la organización, las credenciales de acceso a la bóveda y las claves expuestas deberán **revocarse de inmediato** antes de que concluya la ventana de baja.

### Regla 7 — Respuesta de emergencia ante compromiso o filtración (*Exposición accidental*)
Si una clave criptográfica aparece accidentalmente en un archivo SQL, captura de pantalla, bitácora de errores o commit de GitLab, se considerará **irreversiblemente comprometida** (incluso si el repositorio es privado o el commit se borra). Deberá activarse de inmediato el protocolo de incidente: revocar la clave expuesta, generar una nueva clave, recifrar los datos protegidos y auditar los accesos ocurridos durante la ventana de exposición.

### Regla 8 — Destrucción segura al término de su vida útil (*Eliminación*)
Una vez que todos los datos e históricos legales cifrados con una clave antigua hayan sido recifrados con una clave nueva o hayan cumplido su periodo de retención y depuración definitiva, la clave obsoleta deberá ser **eliminada de forma segura e irrecuperable** (borrado criptográfico / purga en KMS/HSM), dejando constancia en un acta de destrucción.

---

## 4. Análisis

Un algoritmo robusto como AES-256 o OpenPGP (`pgp_sym_encrypt`) carece de valor si la clave se elige débilmente, se incrusta en GitLab o se pierde sin contar con un respaldo custodiado:
- **Si la clave se expone:** se pierde la **confidencialidad** de todos los datos cifrados con ella.
- **Si la clave se pierde sin respaldo:** se pierde la **disponibilidad** de la información de forma permanente (un "ransomware autoinfligido").

---

## 5. Conclusión

La seguridad del cifrado reside en la seguridad y disponibilidad de sus claves. Implementar estas 8 reglas garantiza que las claves criptográficas se generen con entropía suficiente, permanezcan fuera del código y de las tablas, puedan recuperarse ante contingencias y se roten o revoquen oportunamente ante cualquier incidente.
