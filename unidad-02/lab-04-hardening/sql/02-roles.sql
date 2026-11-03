SELECT
    rolname,
    rolsuper,
    rolinherit,
    rolcreaterole,
    rolcreatedb,
    rolcanlogin
FROM pg_roles
WHERE rolname NOT LIKE 'pg_%'
ORDER BY rolname;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dba_admin') THEN
        CREATE ROLE dba_admin LOGIN CREATEDB CREATEROLE PASSWORD 'Dba_Lab04_TempPassword!';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_user') THEN
        CREATE ROLE app_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD 'App_Lab04_TempPassword!';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'consulta_user') THEN
        CREATE ROLE consulta_user LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD 'Con_Lab04_TempPassword!';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE comercializadora_norte TO app_user, consulta_user;
GRANT USAGE ON SCHEMA public TO app_user, consulta_user;
GRANT SELECT, INSERT, UPDATE ON public.clientes_soporte TO app_user;
GRANT SELECT ON public.v_analitica_clientes TO consulta_user;

SELECT
    rolname,
    rolcanlogin AS login,
    rolsuper AS superuser,
    rolcreaterole AS createrole,
    rolcreatedb AS createdb
FROM pg_roles
WHERE rolname IN ('postgres', 'dba_admin', 'app_user', 'consulta_user', 'soporte', 'analista')
ORDER BY rolname;
