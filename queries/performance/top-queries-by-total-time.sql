-- Top 20 queries by total time in the last pg_stat_statements snapshot.
-- Use this first when something is slow. 90% of the time the problem
-- is a single query accounting for a disproportionate slice.
--
-- Requires: pg_stat_statements extension enabled.
--   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
--   -- postgresql.conf: shared_preload_libraries = 'pg_stat_statements'
--   -- restart required
--
-- Note on PG 13 vs 14+:
--   * PG 13: column is `total_time` (milliseconds).
--   * PG 14+: columns are `total_exec_time` and `total_plan_time` (ms each).
--   This file uses PG 14+ syntax. For PG 13 replace `total_exec_time`
--   with `total_time` and drop the `total_plan_time` reference.

SELECT
  round((100 * total_exec_time / nullif(sum(total_exec_time) OVER (), 0))::numeric, 2)
    AS pct_of_total,
  calls,
  round(mean_exec_time::numeric, 2)     AS mean_ms,
  round(total_exec_time::numeric / 1000, 2) AS total_s,
  rows,
  round(shared_blks_hit * 100.0
        / nullif(shared_blks_hit + shared_blks_read, 0), 2)
    AS buffer_hit_pct,
  -- Trim noise: first 180 chars of the query. Comment this out if
  -- you want full query text.
  regexp_replace(left(query, 180), '\s+', ' ', 'g') AS query_preview
FROM pg_stat_statements
WHERE query NOT ILIKE '%pg_stat_statements%'
  AND query NOT ILIKE 'BEGIN%'
  AND query NOT ILIKE 'COMMIT%'
ORDER BY total_exec_time DESC
LIMIT 20;
