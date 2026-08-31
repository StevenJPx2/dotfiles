"""Tests for twitter_cli.output module."""

from __future__ import annotations

import json

import click
import pytest
import yaml

from twitter_cli.output import (
    default_structured_format,
    emit_structured,
    ensure_utf8_streams,
    error_payload,
    success_payload,
    use_rich_output,
)


# ── ensure_utf8_streams ─────────────────────────────────────────────────


def test_ensure_utf8_streams_no_error() -> None:
    """ensure_utf8_streams should not raise on any platform."""
    ensure_utf8_streams()


# ── success_payload / error_payload ──────────────────────────────────────


def test_success_payload_structure() -> None:
    payload = success_payload({"key": "value"})
    assert payload["ok"] is True
    assert payload["schema_version"] == "1"
    assert payload["data"] == {"key": "value"}


def test_success_payload_with_list() -> None:
    payload = success_payload([1, 2, 3])
    assert payload["ok"] is True
    assert payload["data"] == [1, 2, 3]


def test_error_payload_structure() -> None:
    payload = error_payload("not_found", "User not found")
    assert payload["ok"] is False
    assert payload["schema_version"] == "1"
    assert payload["error"]["code"] == "not_found"
    assert payload["error"]["message"] == "User not found"
    assert "details" not in payload["error"]


def test_error_payload_with_details() -> None:
    payload = error_payload("api_error", "oops", details={"id": "123"})
    assert payload["error"]["details"] == {"id": "123"}


# ── default_structured_format ────────────────────────────────────────────


def test_format_json_flag() -> None:
    assert default_structured_format(as_json=True, as_yaml=False) == "json"


def test_format_yaml_flag() -> None:
    assert default_structured_format(as_json=False, as_yaml=True) == "yaml"


def test_format_both_flags_raises() -> None:
    with pytest.raises(click.UsageError):
        default_structured_format(as_json=True, as_yaml=True)


def test_format_env_yaml(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "yaml")
    assert default_structured_format(as_json=False, as_yaml=False) == "yaml"


def test_format_env_json(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "json")
    assert default_structured_format(as_json=False, as_yaml=False) == "json"


def test_format_env_rich(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "rich")
    assert default_structured_format(as_json=False, as_yaml=False) is None


def test_format_auto_non_tty(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "auto")
    monkeypatch.setattr("sys.stdout", type("FakeStdout", (), {"isatty": lambda self: False})())
    assert default_structured_format(as_json=False, as_yaml=False) == "yaml"


# ── use_rich_output ──────────────────────────────────────────────────────


def test_use_rich_when_no_structured(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "rich")
    assert use_rich_output(as_json=False, as_yaml=False) is True


def test_no_rich_when_json() -> None:
    assert use_rich_output(as_json=True, as_yaml=False) is False


def test_no_rich_when_compact(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "rich")
    assert use_rich_output(as_json=False, as_yaml=False, compact=True) is False


# ── emit_structured ──────────────────────────────────────────────────────


def test_emit_structured_json(capsys) -> None:
    result = emit_structured({"key": "val"}, as_json=True, as_yaml=False)
    assert result is True
    captured = capsys.readouterr()
    parsed = json.loads(captured.out)
    assert parsed["ok"] is True
    assert parsed["data"]["key"] == "val"


def test_emit_structured_yaml(capsys) -> None:
    result = emit_structured({"key": "val"}, as_json=False, as_yaml=True)
    assert result is True
    captured = capsys.readouterr()
    parsed = yaml.safe_load(captured.out)
    assert parsed["ok"] is True
    assert parsed["data"]["key"] == "val"


def test_emit_structured_returns_false_when_rich(monkeypatch) -> None:
    monkeypatch.setenv("OUTPUT", "rich")
    result = emit_structured({"key": "val"}, as_json=False, as_yaml=False)
    assert result is False


def test_emit_structured_wraps_already_wrapped_payload(capsys) -> None:
    """If data is already in the agent schema, it should not be double-wrapped."""
    already_wrapped = {"ok": True, "schema_version": "1", "data": "hello"}
    emit_structured(already_wrapped, as_json=True, as_yaml=False)
    captured = capsys.readouterr()
    parsed = json.loads(captured.out)
    assert parsed["data"] == "hello"
    assert "data" not in str(parsed.get("data", {}) if isinstance(parsed.get("data"), dict) else "")
