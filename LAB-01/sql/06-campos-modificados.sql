-- ============================================================================
-- LAB-01: Bitácoras y auditoría del dato en PostgreSQL
-- Archivo: sql/06-campos-modificados.sql
-- Actividad 12: Consulta de inspección de auditoría y comparación campo por campo
-- Alumno: Arturo Torres Urias | Grupo: 4-3
-- ============================================================================

-- 1. Consultar metadatos de los eventos registrados en auditoria.cambios_clientes
SELECT id_evento, momento, usuario_sesion, usuario_efectivo, aplicacion, ip_cliente, operacion, id_cliente
FROM auditoria.cambios_clientes
ORDER BY id_evento;

-- 2. Comparar valores_antes con valores_despues campo por campo en operaciones UPDATE
SELECT a.id_evento,
       a.momento,
       a.usuario_sesion,
       a.ip_cliente,
       d.key                     AS campo,
       a.valores_antes ->> d.key AS antes,
       d.value #>> '{}'          AS despues
FROM auditoria.cambios_clientes a
CROSS JOIN LATERAL jsonb_each(a.valores_despues) d
WHERE a.operacion = 'UPDATE'
  AND a.valores_antes -> d.key IS DISTINCT FROM d.value
ORDER BY a.id_evento;

-- 3. Sentencia UPDATE para restaurar el valor anterior del RFC de María García (id = 3)
-- UPDATE clientes SET rfc = 'GAMA780912XYZ' WHERE id = 3;
