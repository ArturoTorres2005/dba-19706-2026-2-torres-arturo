-- ============================================================================
-- LAB-01: Bitácoras y auditoría del dato en PostgreSQL
-- Archivo: sql/01-colector-y-vista.sql
-- Actividad 2: Que el servidor administre su propia bitácora
-- Alumno: Arturo Torres Urias | Grupo: 4-3
-- ============================================================================

-- 1. Activar el colector de bitácora (requiere reinicio del servicio PostgreSQL)
ALTER SYSTEM SET logging_collector = on;

SELECT name, setting, pending_restart
FROM pg_settings
WHERE name = 'logging_collector';

-- (Después de reiniciar el servicio: sudo systemctl restart postgresql)

-- 2. Verificar que el colector está activo y consultar el archivo vigente
SELECT name, setting, source
FROM pg_settings
WHERE name = 'logging_collector';

SELECT pg_current_logfile();

-- 3. Leer el archivo de bitácora vigente desde el propio motor
SELECT linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n') AS linea;

-- 4. Crear esquema exclusivo del administrador y vista dba.bitacora
CREATE SCHEMA IF NOT EXISTS dba;
REVOKE ALL ON SCHEMA dba FROM PUBLIC;

CREATE OR REPLACE VIEW dba.bitacora AS
SELECT t.n AS num, t.linea
FROM regexp_split_to_table(pg_read_file(pg_current_logfile()), E'\n')
     WITH ORDINALITY AS t(linea, n)
WHERE t.linea <> '';

-- 5. Consultas de verificación sobre la vista dba.bitacora
-- Últimas 10 líneas
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 10;

-- Líneas que contienen 'update' (sin distinguir mayúsculas)
SELECT linea FROM dba.bitacora WHERE linea ILIKE '%update%';

-- Líneas que cumplen una expresión regular de severidad
SELECT linea FROM dba.bitacora WHERE linea ~ '(FATAL|ERROR)';

-- Listar todos los archivos del directorio de bitácoras
SELECT * FROM pg_ls_logdir();
