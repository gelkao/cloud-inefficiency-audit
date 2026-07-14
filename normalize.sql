DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices AS
WITH tagged AS (
  SELECT *,
         from_date LIKE '__.__.____' AS is_de,
         TRIM(REPLACE(REPLACE(total, '€', ''), '$', '')) AS amount
  FROM raw_invoices
)
SELECT
  grouping,
  product,
  description,
  reference,
  CAST(CASE WHEN is_de THEN REPLACE(REPLACE(quantity, '.', ''), ',', '.')
            ELSE REPLACE(quantity, ',', '')
       END AS REAL)                                                AS quantity,
  CASE WHEN is_de
       THEN substr(from_date, 7, 4) || '-' || substr(from_date, 4, 2) || '-' || substr(from_date, 1, 2)
       ELSE from_date END                                          AS from_date,
  until_date,
  condition,
  unit,
  external_id,
  price,
  CAST(CASE WHEN is_de THEN REPLACE(REPLACE(amount, '.', ''), ',', '.')
            ELSE REPLACE(amount, ',', '')
       END AS REAL)                                                AS total,
  CASE WHEN total LIKE '%$%' THEN 'usd' ELSE 'eur' END             AS currency
FROM tagged;
