"""Run every .sql file in queries/ against a Postgres instance and
collect the results into a single Markdown report.

Usage:

    python -m playbook.runner \
        --dsn "postgresql://user:pass@host:5432/db" \
        --out report.md

Fails fast if psycopg can't connect. Per-query errors are captured and
included in the report (a missing pg_stat_statements extension, for
example, should degrade gracefully rather than crash the whole run).
"""
from __future__ import annotations

import argparse
import datetime as dt
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

QUERIES_DIR = Path(__file__).resolve().parent.parent.parent / "queries"


@dataclass
class Query:
    category: str
    name: str
    path: Path
    sql: str


@dataclass
class Result:
    query: Query
    columns: list[str]
    rows: list[tuple]
    error: str | None = None


def discover_queries(base: Path = QUERIES_DIR) -> list[Query]:
    queries: list[Query] = []
    for sub in sorted(p for p in base.iterdir() if p.is_dir()):
        for sql_file in sorted(sub.glob("*.sql")):
            queries.append(
                Query(
                    category=sub.name,
                    name=sql_file.stem,
                    path=sql_file,
                    sql=sql_file.read_text(encoding="utf-8"),
                )
            )
    return queries


def run_all(dsn: str, queries: Iterable[Query]) -> list[Result]:
    try:
        import psycopg
    except ImportError as exc:
        raise RuntimeError(
            "psycopg is not installed. `pip install 'psycopg[binary]'`"
        ) from exc

    results: list[Result] = []
    with psycopg.connect(dsn, autocommit=True) as conn:
        for q in queries:
            try:
                with conn.cursor() as cur:
                    cur.execute(q.sql)
                    cols = [d.name for d in cur.description or []]
                    rows = cur.fetchall() if cur.description else []
                    results.append(Result(query=q, columns=cols, rows=rows))
            except Exception as exc:
                results.append(Result(query=q, columns=[], rows=[], error=str(exc)))
    return results


def format_markdown(results: list[Result], dsn_redacted: str = "***") -> str:
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    out: list[str] = []
    out.append(f"# Postgres production playbook — report\n")
    out.append(f"- Generated: `{now}`")
    out.append(f"- Target DSN: `{dsn_redacted}`")
    out.append(f"- Queries run: {len(results)}")
    errors = [r for r in results if r.error]
    out.append(f"- Queries with errors: {len(errors)}\n")

    by_cat: dict[str, list[Result]] = {}
    for r in results:
        by_cat.setdefault(r.query.category, []).append(r)

    for cat in sorted(by_cat):
        out.append(f"## {cat}\n")
        for r in by_cat[cat]:
            out.append(f"### `{r.query.name}`\n")
            if r.error:
                out.append(f"> **Error:** {r.error}\n")
                continue
            if not r.rows:
                out.append("_(no rows)_\n")
                continue
            header = "| " + " | ".join(r.columns) + " |"
            sep = "| " + " | ".join("---" for _ in r.columns) + " |"
            out.append(header)
            out.append(sep)
            for row in r.rows[:30]:
                cells = [_fmt_cell(v) for v in row]
                out.append("| " + " | ".join(cells) + " |")
            if len(r.rows) > 30:
                out.append(f"\n_...{len(r.rows) - 30} more rows truncated_\n")
            out.append("")

    return "\n".join(out) + "\n"


def _fmt_cell(v: object) -> str:
    if v is None:
        return "NULL"
    s = str(v)
    # pipe is the table delimiter, escape any in cell
    return s.replace("|", "\\|").replace("\n", " ")


def redact_dsn(dsn: str) -> str:
    """Remove the password from a DSN for logging."""
    # postgresql://user:pass@host/db -> postgresql://user:***@host/db
    import re
    return re.sub(r"(postgresql://[^:]+:)[^@]+@", r"\1***@", dsn)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="playbook")
    ap.add_argument("--dsn", required=True, help="postgresql:// DSN")
    ap.add_argument("--out", default="report.md", help="Output markdown path")
    args = ap.parse_args(argv)

    queries = discover_queries()
    results = run_all(args.dsn, queries)
    md = format_markdown(results, dsn_redacted=redact_dsn(args.dsn))

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(md, encoding="utf-8")

    errors = sum(1 for r in results if r.error)
    print(f"Ran {len(results)} queries, {errors} errored. Report: {out_path}")
    return 0 if errors == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
