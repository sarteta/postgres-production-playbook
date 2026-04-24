-- Indexes that have been scanned < 50 times since the last stats reset.
-- Unused indexes cost disk, slow INSERT/UPDATE/DELETE, and inflate
-- backup size. They rarely pay rent.
--
-- Caveats before dropping anything:
--   1. pg_stat_reset() clears idx_scan. If stats were reset recently
--      (check pg_stat_database.stats_reset) this list is unreliable.
--   2. Primary keys + unique constraints show here too — DO NOT drop
--      those. The filter below excludes UNIQUE indexes; add filters
--      for your specific naming conventions if needed.
--   3. Indexes used only during nightly ETL or monthly reports can
--      look unused for days. Confirm with the team before dropping.

SELECT
  schemaname,
  relname AS table_name,
  indexrelname AS index_name,
  idx_scan AS scans_since_reset,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
  pg_size_pretty(pg_relation_size(relid))       AS table_size
FROM pg_stat_user_indexes
JOIN pg_index USING (indexrelid)
WHERE idx_scan < 50
  AND NOT indisunique   -- skip uniqueness-enforcing indexes
  AND NOT indisprimary  -- skip primary keys
  AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 50;
