CREATE SCHEMA pii;
CREATE SCHEMA analitica;

CREATE TABLE pii.mapa_cliente (
    token UUID PRIMARY KEY,
    cliente_id BIGINT UNIQUE
        REFERENCES public.clientes(id)
);

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO pii.mapa_cliente (token, cliente_id)
SELECT
    gen_random_uuid(),
    id
FROM clientes;

SELECT * FROM pii.mapa_cliente;

CREATE TABLE analitica.clientes AS
SELECT
    m.token AS cliente_token,
    c.edad,
    c.ciudad,
    c.codigo_postal,
    c.fecha_alta
FROM pii.mapa_cliente m
JOIN clientes c
    ON c.id = m.cliente_id;

SELECT * FROM analitica.clientes;

CREATE ROLE analista NOLOGIN;

GRANT USAGE ON SCHEMA analitica TO analista;
GRANT SELECT ON analitica.clientes TO analista;

SET ROLE analista;
SELECT * FROM analitica.clientes;
SELECT * FROM pii.mapa_cliente;
SELECT * FROM public.clientes;
RESET ROLE;
