-- ============================================================================
-- LAB-01: Bitácoras y auditoría del dato en PostgreSQL
-- Archivo: sql/04-esquema-auditoria.sql
-- Actividad 10: Diseñar y crear el registro de auditoría a nivel de dato
-- Alumno: Arturo Torres Urias | Grupo: 4-3
-- ============================================================================

-- 1. Crear esquema separado para auditoría y revocar acceso público
CREATE SCHEMA IF NOT EXISTS auditoria;
REVOKE ALL ON SCHEMA auditoria FROM PUBLIC;

-- 2. Crear tabla de auditoría de cambios sobre clientes
CREATE TABLE auditoria.cambios_clientes (
    id_evento        BIGSERIAL PRIMARY KEY,
    momento          TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario_sesion   TEXT        NOT NULL DEFAULT session_user,
    usuario_efectivo TEXT        NOT NULL DEFAULT current_user,
    aplicacion       TEXT        DEFAULT current_setting('application_name'),
    ip_cliente       INET        DEFAULT inet_client_addr(),
    operacion        TEXT        NOT NULL,
    id_cliente       BIGINT,
    valores_antes    JSONB,
    valores_despues  JSONB
);
