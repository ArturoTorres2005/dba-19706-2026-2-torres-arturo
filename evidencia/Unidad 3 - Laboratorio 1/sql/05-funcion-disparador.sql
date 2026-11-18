-- ============================================================================
-- LAB-01: Bitácoras y auditoría del dato en PostgreSQL
-- Archivo: sql/05-funcion-disparador.sql
-- Actividad 11: Crear la función de auditoría (SECURITY DEFINER) y el disparador
-- Alumno: Arturo Torres Urias | Grupo: 4-3
-- ============================================================================

-- 1. Crear función de disparador con SECURITY DEFINER y search_path fijo
CREATE OR REPLACE FUNCTION auditoria.registrar_cambio_cliente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.cambios_clientes (operacion, id_cliente, valores_despues)
        VALUES (TG_OP, NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria.cambios_clientes (operacion, id_cliente, valores_antes, valores_despues)
        VALUES (TG_OP, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO auditoria.cambios_clientes (operacion, id_cliente, valores_antes)
        VALUES (TG_OP, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

-- 2. Revocar ejecución directa de la función a PUBLIC
REVOKE ALL ON FUNCTION auditoria.registrar_cambio_cliente() FROM PUBLIC;

-- 3. Crear el disparador AFTER INSERT OR UPDATE OR DELETE FOR EACH ROW
CREATE TRIGGER trg_auditoria_clientes
AFTER INSERT OR UPDATE OR DELETE ON clientes
FOR EACH ROW EXECUTE FUNCTION auditoria.registrar_cambio_cliente();

-- 4. Verificar que el disparador está creado y habilitado (tgenabled = 'O')
SELECT tgname, tgenabled, tgrelid::regclass
FROM pg_trigger
WHERE NOT tgisinternal;
