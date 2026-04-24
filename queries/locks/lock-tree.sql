-- Who is blocking whom — full wait tree.
-- When the app hangs on a random request and the DB looks fine at
-- first glance, this is the first thing to run.
--
-- Output is a list of (blocking_pid, blocked_pid) pairs plus the
-- queries involved. The query at the top of the chain is usually the
-- one you need to cancel (or figure out why it's slow).

WITH locks AS (
  SELECT
    blocked.pid                        AS blocked_pid,
    blocked.usename                    AS blocked_user,
    blocked.application_name           AS blocked_app,
    blocking.pid                       AS blocking_pid,
    blocking.usename                   AS blocking_user,
    blocking.application_name          AS blocking_app,
    left(blocked.query, 160)           AS blocked_query,
    left(blocking.query, 160)          AS blocking_query,
    blocked.state                      AS blocked_state,
    blocking.state                     AS blocking_state,
    now() - blocked.xact_start         AS blocked_wait
  FROM pg_stat_activity blocked
  JOIN pg_stat_activity blocking
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
)
SELECT *
FROM locks
ORDER BY blocked_wait DESC NULLS LAST;
