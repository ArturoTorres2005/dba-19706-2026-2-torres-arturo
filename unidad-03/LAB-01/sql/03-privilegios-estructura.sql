-- ============================================================================
-- LAB-01: Bitácoras y auditoría del dato en PostgreSQL
-- Archivo: sql/03-privilegios-estructura.sql
-- Actividad 6: Cambios de privilegios y de estructura (y filtro de secretos)
-- Alumno: Arturo Torres Urias | Grupo: 4-3
-- ============================================================================

-- 1. Cambios de privilegios (DCL) y de estructura (DDL)
REVOKE UPDATE ON clientes FROM soporte_ana;
GRANT UPDATE ON clientes TO app_ventas;
ALTER TABLE clientes ADD COLUMN segmento VARCHAR(20);

-- 2. Demostración de exposición de secretos en bitácora cuando se pasa PASSWORD literal
-- NOTA DE SEGURIDAD: En entornos reales debe usarse \password para enviar hash SCRAM.
CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';
DROP ROLE rol_temporal;

-- 3. Consultar las sentencias registradas en la bitácora
SELECT linea FROM dba.bitacora WHERE linea LIKE '%statement:%' ORDER BY num;
