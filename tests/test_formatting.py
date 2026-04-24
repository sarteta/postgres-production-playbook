from playbook.runner import Query, Result, format_markdown, redact_dsn


def test_redact_dsn_hides_password():
    assert redact_dsn("postgresql://alice:s3cret@host:5432/db") == \
        "postgresql://alice:***@host:5432/db"


def test_redact_dsn_is_noop_without_password():
    # No password segment -> return unchanged (don't accidentally mangle)
    url = "postgresql://localhost:5432/db"
    assert redact_dsn(url) == url


def test_format_markdown_handles_empty_results():
    md = format_markdown([], dsn_redacted="***")
    assert "Queries run: 0" in md


def test_format_markdown_renders_one_row():
    q = Query(category="performance", name="fake", path=None, sql="SELECT 1")  # type: ignore
    r = Result(query=q, columns=["n"], rows=[(1,)])
    md = format_markdown([r], dsn_redacted="***")
    assert "| n |" in md
    assert "| 1 |" in md


def test_format_markdown_renders_error_cleanly():
    q = Query(category="maintenance", name="oops", path=None, sql="SELECT boom")  # type: ignore
    r = Result(query=q, columns=[], rows=[], error="relation does not exist")
    md = format_markdown([r], dsn_redacted="***")
    assert "> **Error:** relation does not exist" in md


def test_format_markdown_escapes_pipes():
    q = Query(category="c", name="n", path=None, sql="S")  # type: ignore
    r = Result(query=q, columns=["col"], rows=[("a|b",)])
    md = format_markdown([r], dsn_redacted="***")
    assert "a\\|b" in md


def test_format_markdown_truncates_long_result_sets():
    q = Query(category="c", name="n", path=None, sql="S")  # type: ignore
    r = Result(query=q, columns=["n"], rows=[(i,) for i in range(50)])
    md = format_markdown([r], dsn_redacted="***")
    assert "20 more rows truncated" in md
