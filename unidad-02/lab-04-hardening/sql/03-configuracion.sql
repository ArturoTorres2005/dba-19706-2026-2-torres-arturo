SELECT
    line_number,
    type,
    database,
    user_name,
    address,
    netmask,
    auth_method
FROM pg_hba_file_rules;

SHOW password_encryption;

SELECT
    extname,
    extversion
FROM pg_extension
ORDER BY extname;

SHOW max_connections;
SHOW superuser_reserved_connections;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;

ALTER DATABASE comercializadora_norte SET statement_timeout = '30s';
ALTER DATABASE comercializadora_norte SET idle_in_transaction_session_timeout = '60s';
