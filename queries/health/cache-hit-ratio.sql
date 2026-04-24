-- Buffer cache hit ratio, table-by-table.
-- Rule of thumb: anything under 95% on a hot table means you're
-- either undersized on shared_buffers or missing an index that would
-- keep the working set smaller.
--
-- shared_buffers sizing: start at 25% of RAM on a dedicated DB host,
-- 15% if the host shares workload. Going over 40% rarely helps because
-- the OS page cache already has the data.

SELECT
  relname AS table_name,
  heap_blks_read + heap_blks_hit AS reads_total,
  CASE
    WHEN heap_blks_read + heap_blks_hit = 0 THEN 0
    ELSE round((100.0 * heap_blks_hit / (heap_blks_read + heap_blks_hit))::numeric, 2)
  END AS heap_hit_pct,
  CASE
    WHEN idx_blks_read + idx_blks_hit = 0 THEN 0
    ELSE round((100.0 * idx_blks_hit / (idx_blks_read + idx_blks_hit))::numeric, 2)
  END AS idx_hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_read + heap_blks_hit > 1000  -- skip tiny tables
ORDER BY heap_blks_read + heap_blks_hit DESC
LIMIT 30;
