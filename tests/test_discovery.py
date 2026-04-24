from pathlib import Path

from playbook.runner import discover_queries, QUERIES_DIR


def test_discovers_queries_across_categories():
    queries = discover_queries()
    assert len(queries) >= 8
    categories = {q.category for q in queries}
    # Repo ships with these at minimum
    assert "performance" in categories
    assert "health" in categories
    assert "locks" in categories
    assert "maintenance" in categories


def test_every_discovered_query_has_nonempty_sql():
    queries = discover_queries()
    for q in queries:
        assert q.sql.strip(), f"empty SQL in {q.path}"


def test_every_discovered_query_has_documentation_comment():
    """Every .sql file in the playbook should lead with a comment block
    explaining what it does. Bare SQL without context is not useful in
    an on-call situation."""
    queries = discover_queries()
    for q in queries:
        first_nonblank = next((ln for ln in q.sql.splitlines() if ln.strip()), "")
        assert first_nonblank.lstrip().startswith("--"), (
            f"{q.path.name} does not start with a `-- ...` comment"
        )
