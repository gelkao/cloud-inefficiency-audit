DROP VIEW IF EXISTS line_items;
CREATE VIEW line_items AS
SELECT
  external_id                                                AS box,
  from_date                                                  AS date,
  substr(from_date, 1, 7)                                    AS month,
  lower(substr(product, 1, instr(product, ' ') - 1))         AS type,
  CASE WHEN unit = 'Hours' THEN 'hourly' ELSE 'monthly' END  AS kind,
  CAST(quantity AS REAL)                                     AS qty,
  CAST(TRIM(REPLACE(REPLACE(REPLACE(total,'€',''),'$',''),',','')) AS REAL) AS paid,
  CASE WHEN total LIKE '%$%' THEN 'usd' ELSE 'eur' END       AS currency,
  grouping
FROM raw_invoices
WHERE product LIKE '%Cloud Server%';

DROP VIEW IF EXISTS detected_group;
CREATE VIEW detected_group AS
SELECT price_group FROM (
  SELECT p.price_group, COUNT(*) AS votes
  FROM line_items li
  JOIN prices p
    ON p.type = li.type AND p.currency = li.currency
   AND p.effective_from = (
         SELECT MAX(p2.effective_from) FROM prices p2
         WHERE p2.type = li.type AND p2.price_group = p.price_group
           AND p2.currency = li.currency AND p2.effective_from <= li.date)
  WHERE li.kind = 'monthly' AND ABS(li.paid - p.price_monthly) < 0.02
  GROUP BY p.price_group
  ORDER BY votes DESC, p.price_group
  LIMIT 1
);

DROP VIEW IF EXISTS customer_rates;
CREATE VIEW customer_rates AS
SELECT type, month, kind, MIN(paid / qty) AS rate
FROM line_items
WHERE qty > 0
GROUP BY type, month, kind;

DROP TABLE IF EXISTS priced;
CREATE TABLE priced AS
SELECT
  li.box, li.date, li.month, li.grouping, li.type, li.kind, li.qty, li.currency,
  li.paid,
  MIN(
    COALESCE(
      ( SELECT MIN(
          COALESCE(
            ( SELECT cr.rate FROM customer_rates cr
               WHERE cr.type = cand.type AND cr.month = li.month AND cr.kind = li.kind ),
            ( SELECT CASE WHEN li.kind = 'hourly' THEN p.price_hourly ELSE p.price_monthly END
               FROM prices p
               WHERE p.type = cand.type AND p.currency = li.currency
                 AND p.price_group = (SELECT price_group FROM detected_group)
                 AND p.effective_from <= li.date
               ORDER BY p.effective_from DESC LIMIT 1 )
          ) )
        FROM server_types cand
        WHERE cand.ram_gb = st.ram_gb AND cand.vcpu >= st.vcpu
      ) * li.qty,
      li.paid
    ),
    li.paid
  ) AS optimal,
  MIN(
    COALESCE(
      ( SELECT MIN(
          ( SELECT CASE WHEN li.kind = 'hourly' THEN p.price_hourly ELSE p.price_monthly END
             FROM prices p
             WHERE p.type = cand.type AND p.currency = li.currency
               AND p.price_group = (SELECT price_group FROM detected_group)
               AND p.effective_from <= li.date
             ORDER BY p.effective_from DESC LIMIT 1 )
        )
        FROM server_types cand
        WHERE cand.ram_gb = st.ram_gb AND cand.vcpu >= st.vcpu
      ) * li.qty,
      li.paid
    ),
    li.paid
  ) AS optimal_recoverable
FROM line_items li
JOIN server_types st ON st.type = li.type;
