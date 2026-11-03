SHOW ssl;
SHOW ssl_min_protocol_version;

SELECT
    pid,
    usename,
    client_addr,
    ssl,
    version,
    cipher
FROM pg_stat_ssl
JOIN pg_stat_activity USING (pid)
WHERE pid = pg_backend_pid();

SELECT
    datname,
    setconfig
FROM pg_db_role_setting s
JOIN pg_database d ON d.oid = s.setdatabase
WHERE d.datname = 'comercializadora_norte';

SELECT
    grantee,
    table_name,
    privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('app_user', 'consulta_user', 'soporte', 'analista')
ORDER BY grantee, table_name, privilege_type;
