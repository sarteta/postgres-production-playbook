-- Connection breakdown by state + application_name.
-- Run this when max_connections is getting pressed or when you see
-- clients getting timeouts.
--
-- Anti-patterns to look for:
--   * A single application_name with > 50 idle connections (missing
--     connection pooler -- PgBouncer transaction mode fixes this).
--   * `idle in transaction` entries older than a few minutes
--     (long transactions block vacuum and bloat tables fast).

SELECT
  application_name,
  state,
  count(*) AS connections,
  max(now() - state_change) AS oldest_in_state,
  max(now() - xact_start) FILTER (WHERE xact_start IS NOT NULL)
    AS oldest_transaction
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
GROUP BY application_name, state
ORDER BY connections DESC;
