-- ============================================================================
-- LAB-01: Bitácoras y auditoría del dato en PostgreSQL
-- Archivo: sql/02-configuracion-bitacora.sql
-- Actividad 4: Configurar la bitácora (conexiones, desconexiones, prefijo y DDL)
-- Alumno: Arturo Torres Urias | Grupo: 4-3
-- ============================================================================

-- 1. Configurar parámetros de registro mediante ALTER SYSTEM
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_line_prefix = '%m [%p] user=%u db=%d app=%a client=%h ';
ALTER SYSTEM SET log_statement = 'ddl';

-- 2. Recargar la configuración sin cortar sesiones activas
SELECT pg_reload_conf();

-- 3. Verificar en un bloque/consulta posterior el origen de los valores
SELECT name, setting, source, sourcefile
FROM pg_settings
WHERE name IN ('log_connections', 'log_disconnections', 'log_line_prefix', 'log_statement')
ORDER BY name;

-- 4. Revisar las últimas líneas registradas en la bitácora
SELECT num, linea FROM dba.bitacora ORDER BY num DESC LIMIT 6;
