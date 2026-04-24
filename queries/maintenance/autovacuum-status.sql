-- Autovacuum status per table. Identifies tables that vacuum hasn't
-- visited in a while or that have a growing dead tuple count.
--
-- The thresholds are intentionally conservative — if a table shows
-- up here it doesn't mean there's a problem, just that it's worth
-- a look.

SELECT
  schemaname,
  relname AS table_name,
  n_live_tup AS live_rows,
  n_dead_tup AS dead_rows,
  CASE
    WHEN n_live_tup = 0 THEN 0
    ELSE round((100.0 * n_dead_tup / n_live_tup)::numeric, 1)
  END AS dead_pct,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze,
  vacuum_count + autovacuum_count AS vacuum_runs_lifetime
FROM pg_stat_user_tables
WHERE n_live_tup > 1000
ORDER BY dead_rows DESC
LIMIT 30;
