# postgres-production-playbook

[![tests](https://github.com/sarteta/postgres-production-playbook/actions/workflows/tests.yml/badge.svg)](https://github.com/sarteta/postgres-production-playbook/actions/workflows/tests.yml)
[![docker](https://github.com/sarteta/postgres-production-playbook/actions/workflows/docker.yml/badge.svg)](https://github.com/sarteta/postgres-production-playbook/actions/workflows/docker.yml)
[![python](https://img.shields.io/badge/python-3.11%20%7C%203.12%20%7C%203.13-blue)](https://www.python.org)
[![postgres](https://img.shields.io/badge/postgres-13%20%7C%2014%20%7C%2015%20%7C%2016-blue)](https://www.postgresql.org)
[![license](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

A small set of Postgres diagnostic queries I reach for when something's
wrong in production, plus a Python runner that executes them all against
a live DB and aggregates the output into one Markdown report.

Read-only. Every query is a `SELECT` against `pg_stat_*` / `pg_catalog`.
The test suite enforces that -- no `DROP`, `DELETE`, `ALTER`, or anything
that could touch your data can slip into a contribution.

## When I use this

- The app is slow and I need to find the one query accounting for half
  the db time.
- A Lambda/worker hangs on `INSERT`. Something is taking an exclusive
  lock; I need the blocker chain in one query.
- Slack alert says "RDS at 90% CPU". Buffer cache hit ratio + table
  size quickly rules in/out the usual suspects.
- Someone pushed a migration that looked harmless but autovacuum is
  now struggling on a hot table.
- A replica keeps falling behind during peak hours.

I ran variants of these in a 4-year DBA stint (NetMonitor) and as SRE
at SocialNet/Valida, where uptime for two Argentine banks was
non-negotiable. This repo is the result of finally sitting down to
organize them into something I could hand a teammate who's on-call
for the first time.

## What's in it

```
queries/
├── performance/
│   ├── top-queries-by-total-time.sql
│   ├── unused-indexes.sql
│   └── missing-indexes-hint.sql
├── health/
│   ├── cache-hit-ratio.sql
│   └── connections-breakdown.sql
├── locks/
│   └── lock-tree.sql
├── maintenance/
│   ├── bloat-estimate.sql
│   └── autovacuum-status.sql
└── replication/
    └── replication-lag.sql
```

Every `.sql` file opens with a comment block explaining **what it does,
when to use it, and what the output means**. That's enforced by a unit
test -- if you add a query without documentation, CI fails.

## Running it

### Just the SQL, no Python

```bash
psql "$DATABASE_URL" -f queries/performance/top-queries-by-total-time.sql
```

That's the whole story for the SQL side. Each file is a single statement.

### The Python runner (aggregate all queries, write one report)

```bash
pip install -r requirements.txt

python -m playbook.runner \
  --dsn "postgresql://user:pass@host:5432/db" \
  --out out/report.md
```

See [`examples/sample-report.md`](./examples/sample-report.md) for what
a run against a fresh Postgres 16 instance looks like.

## Design choices

**One statement per file.** Makes it trivial to `psql -f` any single
query without touching the rest. It also means `git blame` on a single
file tells you the full history of that diagnostic.

**Comments narrate, they don't repeat the code.** Each file explains
*why* you'd reach for this query and how to read the output. The SQL
itself is self-documenting to someone who reads Postgres.

**No `DELETE`, `UPDATE`, `DROP`, `ALTER`, `INSERT`, `TRUNCATE`,
`GRANT`, or `REVOKE`.** A test (`test_no_obviously_destructive_keywords`)
parses every file and fails on any of those tokens outside of
comment text. You can't accidentally wreck production via this repo.

**Version-aware where it matters.** `top-queries-by-total-time.sql`
calls out the PG 13 vs 14+ column rename (`total_time` → `total_exec_time`)
in the comment block, because that's the exact thing you hit when you
run it against an older RDS instance.

**Managed-DB friendly.** Bloat estimate avoids `pgstattuple` (requires
superuser extension install, doesn't work out-of-the-box on RDS/Cloud SQL
without asking). The heuristic is less precise than `pgstattuple` but
works everywhere.

## Tests

- `test_discovery.py` -- every `.sql` file is discovered, non-empty, and
  starts with a `-- ...` documentation comment.
- `test_sql_syntax.py` -- every file parses via sqlparse into exactly
  one executable statement + no destructive keywords.
- `test_formatting.py` -- the markdown report redacts DSN passwords,
  escapes pipes, truncates long result sets, and renders errors
  cleanly.

Plus a CI integration job that spins up Postgres 16 via GitHub
Actions `services:`, seeds 2k rows, runs the full playbook against it,
and uploads the rendered report as an artifact. So every PR on `main`
proves the whole thing still runs end-to-end against a real database.

## Roadmap

- [ ] Add `--reset-stats` option (optional; requires opt-in flag)
- [ ] Checkpoint / WAL volume query
- [ ] pgbouncer stats queries
- [ ] Slow autovacuum detective (dead_tup growth over time)
- [ ] Grafana dashboard JSON derived from the same queries

## License

MIT © 2026 Santiago Arteta
