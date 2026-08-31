"""Tests for twitter_cli.cache module."""

from __future__ import annotations

import json
import time


from twitter_cli.cache import resolve_cached_tweet, save_tweet_cache
from twitter_cli.models import Author, Metrics, Tweet


def _make_tweet(tweet_id: str, text: str = "hello") -> Tweet:
    return Tweet(
        id=tweet_id,
        text=text,
        author=Author(id="u1", name="Alice", screen_name="alice"),
        metrics=Metrics(likes=1),
        created_at="2025-01-01",
    )


class TestSaveAndResolve:
    """save_tweet_cache → resolve_cached_tweet round-trip."""

    def test_round_trip(self, tmp_path, monkeypatch) -> None:
        cache_file = tmp_path / "last_results.json"
        monkeypatch.setattr("twitter_cli.cache._CACHE_FILE", cache_file)
        monkeypatch.setattr("twitter_cli.cache._CACHE_DIR", tmp_path)

        tweets = [_make_tweet("100"), _make_tweet("200"), _make_tweet("300")]
        save_tweet_cache(tweets)

        assert cache_file.exists()
        tweet_id, size = resolve_cached_tweet(1)
        assert tweet_id == "100"
        assert size == 3

        tweet_id, size = resolve_cached_tweet(3)
        assert tweet_id == "300"
        assert size == 3

    def test_out_of_range_returns_none(self, tmp_path, monkeypatch) -> None:
        cache_file = tmp_path / "last_results.json"
        monkeypatch.setattr("twitter_cli.cache._CACHE_FILE", cache_file)
        monkeypatch.setattr("twitter_cli.cache._CACHE_DIR", tmp_path)

        save_tweet_cache([_make_tweet("100")])

        tweet_id, size = resolve_cached_tweet(99)
        assert tweet_id is None
        assert size == 1


class TestCacheExpiry:
    """TTL expiration behavior."""

    def test_expired_cache_returns_none(self, tmp_path, monkeypatch) -> None:
        cache_file = tmp_path / "last_results.json"
        monkeypatch.setattr("twitter_cli.cache._CACHE_FILE", cache_file)

        # Write cache with old timestamp
        payload = {
            "created_at": time.time() - 7200,  # 2 hours ago
            "tweets": [{"index": 1, "id": "100", "author": "alice", "text": "hi"}],
        }
        cache_file.write_text(json.dumps(payload), encoding="utf-8")

        tweet_id, size = resolve_cached_tweet(1)
        assert tweet_id is None
        assert size == 0


class TestCacheEdgeCases:
    """Corrupted and missing cache files."""

    def test_missing_file(self, tmp_path, monkeypatch) -> None:
        cache_file = tmp_path / "does_not_exist.json"
        monkeypatch.setattr("twitter_cli.cache._CACHE_FILE", cache_file)

        tweet_id, size = resolve_cached_tweet(1)
        assert tweet_id is None
        assert size == 0

    def test_corrupted_json(self, tmp_path, monkeypatch) -> None:
        cache_file = tmp_path / "last_results.json"
        cache_file.write_text("{{invalid json", encoding="utf-8")
        monkeypatch.setattr("twitter_cli.cache._CACHE_FILE", cache_file)

        tweet_id, size = resolve_cached_tweet(1)
        assert tweet_id is None
        assert size == 0

    def test_wrong_structure(self, tmp_path, monkeypatch) -> None:
        cache_file = tmp_path / "last_results.json"
        cache_file.write_text('"just a string"', encoding="utf-8")
        monkeypatch.setattr("twitter_cli.cache._CACHE_FILE", cache_file)

        tweet_id, size = resolve_cached_tweet(1)
        assert tweet_id is None
        assert size == 0
