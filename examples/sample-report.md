# Postgres production playbook — report

- Generated: `2026-04-24 17:15:00 UTC`
- Target DSN: `postgresql://postgres:***@localhost:5432/playbook`
- Queries run: 9
- Queries with errors: 1

## health

### `cache-hit-ratio`

| table_name | reads_total | heap_hit_pct | idx_hit_pct |
| --- | --- | --- | --- |
| demo_users | 4213 | 99.93 | 99.85 |

### `connections-breakdown`

| application_name | state | connections | oldest_in_state | oldest_transaction |
| --- | --- | --- | --- | --- |
| psql | idle | 1 | 00:00:12 | NULL |
| pg_basebackup | active | 0 | NULL | NULL |

## locks

### `lock-tree`

_(no rows)_

## maintenance

### `autovacuum-status`

| schemaname | table_name | live_rows | dead_rows | dead_pct | last_vacuum | last_autovacuum | last_analyze | last_autoanalyze | vacuum_runs_lifetime |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| public | demo_users | 2000 | 0 | 0.0 | NULL | NULL | NULL | 2026-04-24 17:14:55+00 | 1 |

### `bloat-estimate`

_(no rows)_

## performance

### `top-queries-by-total-time`

> **Error:** relation "pg_stat_statements" does not exist

### `unused-indexes`

| schemaname | table_name | index_name | scans_since_reset | index_size | table_size |
| --- | --- | --- | --- | --- | --- |
| public | demo_users | demo_users_created_idx | 0 | 64 kB | 144 kB |

### `missing-indexes-hint`

_(no rows)_

## replication

### `replication-lag`

_(no rows)_
