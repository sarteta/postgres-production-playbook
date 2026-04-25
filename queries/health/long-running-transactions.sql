-- Transactions that have been open longer than expected. These are
-- usually the cause of (a) bloat that vacuum can't clean, (b) lock
-- queues piling up, (c) replication slots growing unchecked.
--
-- Pull this whenever you see "high disk I/O on prod and I don't know
-- why" or "autovacuum keeps starting and getting cancelled".
--
-- Thresholds:
--   * > 5 minutes  -> investigate (could be a slow analytical query)
--   * > 30 minutes -> almost always a leaked transaction (forgot a
--                     commit/rollback in app code, or held by an
--                     interactive psql session)
--
-- The 'idle in transaction' rows are the dangerous ones — they hold
-- locks and prevent vacuum from cleaning rows that other sessions
-- have already deleted, so dead_tup grows even if nothing visible
-- is happening.

SELECT
  pid,
  usename                                AS username,
  application_name,
  client_addr,
  state,
  now() - xact_start                     AS xact_age,
  now() - state_change                   AS in_state_for,
  wait_event_type,
  wait_event,
  left(query, 200)                       AS query_preview
FROM pg_stat_activity
WHERE xact_start IS NOT NULL
  AND pid <> pg_backend_pid()
  AND now() - xact_start > interval '1 minute'
ORDER BY xact_age DESC;
