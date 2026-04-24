-- Tables with a high seq_scan-to-idx_scan ratio. Hint for missing
-- indexes — this is a starting point, not a recommendation.
--
-- Rule of thumb that has worked for me:
--   * Small tables (<= 10k rows) happily seq-scan. Don't add an index.
--   * Tables > 100k rows where seq_scans > 10% of (seq_scans + idx_scans)
--     are worth investigating.
--   * Use EXPLAIN (ANALYZE, BUFFERS) on the actual slow query before
--     adding anything. Indexes aren't free — they slow writes.

SELECT
  schemaname,
  relname AS table_name,
  n_live_tup AS approx_rows,
  seq_scan,
  seq_tup_read,
  idx_scan,
  idx_tup_fetch,
  CASE
    WHEN seq_scan + idx_scan = 0 THEN 0
    ELSE round((100.0 * seq_scan / (seq_scan + idx_scan))::numeric, 1)
  END AS pct_seq_scans,
  pg_size_pretty(pg_relation_size(relid)) AS table_size
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
  AND seq_scan > 0
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pct_seq_scans DESC, n_live_tup DESC
LIMIT 30;
