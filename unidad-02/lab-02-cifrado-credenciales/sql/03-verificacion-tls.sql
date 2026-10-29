SHOW ssl;

SHOW ssl_min_protocol_version;

SHOW port;

SHOW listen_addresses;

SELECT
    inet_client_addr(),
    inet_client_port();

SELECT
    ssl,
    version,
    cipher
FROM pg_stat_ssl
WHERE pid = pg_backend_pid();
