SELECT
    CASE
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+'
    END AS rango_edad,
    COUNT(*) AS total
FROM clientes
GROUP BY 1;

SELECT
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes
GROUP BY 1;

SELECT
    CASE
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+'
    END AS rango_edad,
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes
GROUP BY 1, 2;

SELECT
    CASE
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+'
    END AS rango_edad,
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes
GROUP BY 1, 2
HAVING COUNT(*) >= 5;

-- Reto:
SELECT
    CASE
        WHEN edad < 30 THEN 'Menor de 30'
        WHEN edad BETWEEN 30 AND 50 THEN '30-50'
        ELSE 'Mayor de 50'
    END AS macro_rango_edad,
    CONCAT(LEFT(codigo_postal, 1), 'xxxx') AS macro_region_postal,
    EXTRACT(YEAR FROM fecha_alta)::INTEGER AS anio_alta,
    COUNT(*) AS total_clientes
FROM clientes
GROUP BY 1, 2, 3
HAVING COUNT(*) >= 5;
