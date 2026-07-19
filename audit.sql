DROP VIEW IF EXISTS line_items;
CREATE VIEW line_items AS
SELECT
  external_id                                                AS box,
  from_date                                                  AS date,
  substr(from_date, 1, 7)                                    AS month,
  lower(substr(product, 1, instr(product, ' ') - 1))         AS type,
  CASE WHEN unit = 'Hours' THEN 'hourly' ELSE 'monthly' END  AS kind,
  quantity                                                   AS qty,
  total                                                      AS paid,
  currency,
  grouping
FROM invoices
WHERE product LIKE '%Cloud Server%';

DROP VIEW IF EXISTS detected_group;
CREATE VIEW detected_group AS
SELECT price_group FROM (
  SELECT p.price_group, COUNT(*) AS votes
  FROM line_items li
  JOIN prices p
    ON p.type = li.type AND p.currency = li.currency
  WHERE li.kind = 'monthly' AND ABS(li.paid - p.price_monthly) < 0.02
  GROUP BY p.price_group
  ORDER BY votes DESC, p.price_group
  LIMIT 1
);

DROP TABLE IF EXISTS priced;
CREATE TABLE priced AS
WITH base AS (
  SELECT
    li.box, li.date, li.month, li.grouping, li.type, li.kind, li.qty, li.currency,
    li.paid, st.ram_gb, st.vcpu, li.type LIKE 'ccx%' AS is_dedicated,
    ( SELECT MIN(
        ( SELECT p.price_monthly FROM prices p
           WHERE p.type = cand.type AND p.currency = li.currency
             AND p.price_group = (SELECT price_group FROM detected_group)
             AND p.effective_from <= li.date
           ORDER BY p.effective_from DESC LIMIT 1 )
      )
      FROM server_types cand
      WHERE cand.ram_gb = st.ram_gb AND cand.vcpu >= st.vcpu
    ) AS cheapest_monthly,
    ( SELECT MIN(
        ( SELECT p.price_hourly FROM prices p
           WHERE p.type = cand.type AND p.currency = li.currency
             AND p.price_group = (SELECT price_group FROM detected_group)
             AND p.effective_from <= li.date
           ORDER BY p.effective_from DESC LIMIT 1 )
      )
      FROM server_types cand
      WHERE cand.ram_gb = st.ram_gb AND cand.vcpu >= st.vcpu
    ) AS cheapest_hourly,
    ( SELECT MAX(p.effective_from) FROM prices p
       WHERE p.effective_from <= li.date AND p.effective_from <> '2026-06-15' ) AS epoch
  FROM line_items li
  JOIN server_types st ON st.type = li.type
),
locked AS (
  SELECT *,
    MIN(cheapest_monthly) OVER win                             AS lm_market,
    MIN(CASE WHEN kind = 'monthly' THEN paid / qty END) OVER win AS lm_bob,
    MIN(cheapest_hourly) OVER win                              AS lh_market,
    MIN(CASE WHEN kind = 'hourly'  THEN paid / qty END) OVER win AS lh_bob
  FROM base
  WINDOW win AS (PARTITION BY box, ram_gb, vcpu, epoch ORDER BY month
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
)
SELECT
  box, date, month, grouping, type, kind, qty, currency, paid,
  MIN( CASE WHEN is_dedicated THEN paid
            ELSE COALESCE( (CASE WHEN kind = 'hourly' THEN cheapest_hourly ELSE cheapest_monthly END) * qty, paid )
       END, paid ) AS optimal,
  MIN( CASE WHEN is_dedicated THEN paid
            ELSE COALESCE(
                   ( CASE WHEN kind = 'monthly'
                          THEN COALESCE( min(lm_market, lm_bob), lm_market, lm_bob )
                          ELSE COALESCE( min(lh_market, lh_bob), lh_market, lh_bob )
                     END ) * qty,
                   paid )
       END, paid ) AS optimal_locked
FROM locked;
