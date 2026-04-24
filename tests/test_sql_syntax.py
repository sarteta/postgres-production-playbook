"""Parse every .sql file with sqlparse. This is a weak syntax check —
sqlparse is a tokenizer, not a validator — but it catches obvious
typos and unbalanced parentheses without requiring a live Postgres
connection.

The integration CI job (see .github/workflows/tests.yml) runs them
against a real Postgres 16 via the `services:` container.
"""
import sqlparse

from playbook.runner import discover_queries


def test_every_query_is_at_least_one_valid_statement():
    for q in discover_queries():
        parsed = sqlparse.parse(q.sql)
        # Filter out bare comment "statements" (all-comment files)
        statements = [p for p in parsed if p.tokens and not p.is_whitespace]
        assert statements, f"{q.path.name} parsed to 0 statements"
        # Our playbook convention: one statement per file.
        non_cte_stmts = [s for s in statements if str(s).strip()]
        # Allow comment-only statements at start, but require exactly one
        # non-empty executable statement.
        exec_stmts = [s for s in non_cte_stmts if _has_keyword(s)]
        assert len(exec_stmts) == 1, (
            f"{q.path.name} should contain exactly one executable statement, "
            f"found {len(exec_stmts)}"
        )


def test_no_obviously_destructive_keywords():
    """The playbook is read-only by design. This test prevents a regression
    where someone accidentally drops a DROP, DELETE, TRUNCATE, UPDATE or
    INSERT into a diagnostic script."""
    banned = {"DROP", "DELETE", "TRUNCATE", "UPDATE", "INSERT", "ALTER", "GRANT", "REVOKE"}
    for q in discover_queries():
        tokens = {t.value.upper() for t in sqlparse.parse(q.sql)[0].flatten() if t.ttype is not None}
        intersection = tokens & banned
        # Allow them only in comment-level prose, not as actual DML keywords.
        # We detect them via token ttype — comment tokens have ttype =
        # Token.Comment*, not Token.Keyword — so this is a robust check.
        assert not intersection, f"{q.path.name} contains banned keywords: {intersection}"


def _has_keyword(stmt) -> bool:
    for t in stmt.flatten():
        if t.ttype is not None and "Keyword" in str(t.ttype):
            return True
    return False
