DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices AS
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
FROM raw_invoices;
