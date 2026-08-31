"""Unit tests for the advanced search query builder."""

from __future__ import annotations

from twitter_cli.search import build_search_query


class TestBuildSearchQuery:
    def test_plain_query(self) -> None:
        assert build_search_query("python") == "python"

    def test_empty_query(self) -> None:
        assert build_search_query("") == ""

    def test_from_user(self) -> None:
        assert build_search_query("AI", from_user="elonmusk") == "AI from:elonmusk"

    def test_from_user_strips_at(self) -> None:
        assert build_search_query("AI", from_user="@elonmusk") == "AI from:elonmusk"

    def test_to_user(self) -> None:
        assert build_search_query("hello", to_user="jack") == "hello to:jack"

    def test_lang(self) -> None:
        assert build_search_query("news", lang="fr") == "news lang:fr"

    def test_lang_is_trimmed_and_lowercased(self) -> None:
        assert build_search_query("news", lang=" EN ") == "news lang:en"

    def test_since(self) -> None:
        assert build_search_query("python", since="2026-01-01") == "python since:2026-01-01"

    def test_until(self) -> None:
        assert build_search_query("python", until="2026-03-01") == "python until:2026-03-01"

    def test_date_range(self) -> None:
        result = build_search_query("rust", since="2026-01-01", until="2026-03-01")
        assert result == "rust since:2026-01-01 until:2026-03-01"

    def test_has_links(self) -> None:
        assert build_search_query("python", has=["links"]) == "python filter:links"

    def test_has_multiple(self) -> None:
        result = build_search_query("art", has=["images", "videos"])
        assert result == "art filter:images filter:videos"

    def test_exclude_retweets(self) -> None:
        assert build_search_query("news", exclude=["retweets"]) == "news -filter:retweets"

    def test_exclude_replies(self) -> None:
        assert build_search_query("news", exclude=["replies"]) == "news -filter:replies"

    def test_exclude_multiple(self) -> None:
        result = build_search_query("news", exclude=["retweets", "replies"])
        assert result == "news -filter:retweets -filter:replies"

    def test_min_likes(self) -> None:
        assert build_search_query("python", min_likes=100) == "python min_faves:100"

    def test_min_retweets(self) -> None:
        assert build_search_query("python", min_retweets=50) == "python min_retweets:50"

    def test_combined_operators(self) -> None:
        result = build_search_query(
            "machine learning",
            from_user="openai",
            lang="en",
            since="2026-01-01",
            has=["links"],
            min_likes=50,
            exclude=["retweets"],
        )
        assert result == (
            "machine learning from:openai lang:en since:2026-01-01 "
            "filter:links -filter:retweets min_faves:50"
        )

    def test_operators_only_no_query(self) -> None:
        result = build_search_query("", from_user="elonmusk", since="2026-03-01")
        assert result == "from:elonmusk since:2026-03-01"

    def test_date_range_rejects_reversed_order(self) -> None:
        try:
            build_search_query("python", since="2026-03-02", until="2026-03-01")
        except ValueError as exc:
            assert "--since must be on or before --until" in str(exc)
        else:
            raise AssertionError("Expected ValueError for reversed date range")

    def test_invalid_since_rejected(self) -> None:
        try:
            build_search_query("python", since="not-a-date")
        except ValueError as exc:
            assert "--since must be in YYYY-MM-DD format" in str(exc)
        else:
            raise AssertionError("Expected ValueError for invalid since date")

    def test_negative_min_likes_rejected(self) -> None:
        try:
            build_search_query("python", min_likes=-1)
        except ValueError as exc:
            assert "--min-likes must be greater than or equal to 0" in str(exc)
        else:
            raise AssertionError("Expected ValueError for negative min_likes")

    def test_whitespace_query_trimmed(self) -> None:
        assert build_search_query("  python  ", lang="en") == "python lang:en"

    def test_empty_has_list(self) -> None:
        assert build_search_query("test", has=[]) == "test"

    def test_empty_exclude_list(self) -> None:
        assert build_search_query("test", exclude=[]) == "test"
