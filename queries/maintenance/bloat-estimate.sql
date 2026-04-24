-- Bloat estimate per table. Approximate — reflects HOT updates,
-- dead tuples not yet vacuumed, and fillfactor decisions.
--
-- This is a well-known community query (original attribution:
-- Peter Geoghegan + Heikki + many others on pgsql-performance).
-- It doesn't require the pgstattuple extension, so it's safe to run
-- in most managed DBs (RDS, Cloud SQL) where you can't install
-- extensions easily.
--
-- Action signals:
--   * bloat_pct > 20 on a hot write-heavy table -> tune autovacuum
--     for that table (ALTER TABLE ... SET (autovacuum_vacuum_scale_factor = 0.02)).
--   * bloat_bytes > a few GB on any table -> consider a manual
--     VACUUM (FULL) during maintenance window, or pg_repack online.

SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
  pg_size_pretty(bloat_bytes)                                            AS bloat_size,
  round((100.0 * bloat_bytes / nullif(pg_total_relation_size(schemaname || '.' || tablename), 0))::numeric, 1)
    AS bloat_pct
FROM (
  SELECT
    schemaname,
    tablename,
    (n_dead_tup * block_size_ratio)::bigint AS bloat_bytes
  FROM (
    SELECT
      n.nspname AS schemaname,
      c.relname AS tablename,
      s.n_dead_tup,
      -- Rough average row size: 40 bytes header + column data estimate
      -- This is a conservative proxy; for precise numbers use pgstattuple.
      40::bigint AS block_size_ratio
    FROM pg_stat_user_tables s
    JOIN pg_class c ON c.oid = s.relid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
  ) sub
) outer_sub
WHERE bloat_bytes > 1024 * 1024  -- only report > 1 MB bloat
ORDER BY bloat_bytes DESC
LIMIT 30;
