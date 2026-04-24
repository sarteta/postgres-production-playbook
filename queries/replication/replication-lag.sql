-- Replication lag from the primary's perspective.
-- Run on the primary. Empty result = no replicas connected.
--
-- What "lag" means in Postgres (there are 3 flavors):
--   * write_lag  - time between local WAL flush and the replica ACK'ing write.
--   * flush_lag  - time between local flush and replica flush.
--   * replay_lag - time between local flush and replica actually applying.
--
-- `replay_lag` is the one that matters for read-your-writes consistency
-- on a replica. If it climbs under steady load, the replica is CPU or
-- I/O bound and can't apply WAL as fast as the primary is producing it.

SELECT
  application_name,
  client_addr,
  state,
  sync_state,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn))    AS sent_lag,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn))   AS flush_lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn))  AS replay_lag_bytes,
  write_lag,
  flush_lag,
  replay_lag
FROM pg_stat_replication
ORDER BY replay_lag DESC NULLS LAST;
