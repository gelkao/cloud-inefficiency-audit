DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices AS
WITH tagged AS (
  SELECT *,
         from_date LIKE '__.__.____' AS is_de
  FROM raw_invoices
)
SELECT
  grouping,
  product,
  description,
  reference,
  CAST(quantity AS REAL) AS quantity,
  from_date,
  until_date,
  condition,
  unit,
  external_id,
  price,
  CAST(TRIM(REPLACE(REPLACE(REPLACE(total, '€', ''), '$', ''), ',', '')) AS REAL) AS total,
  CASE WHEN total LIKE '%$%' THEN 'usd' ELSE 'eur' END              AS currency
FROM tagged;
