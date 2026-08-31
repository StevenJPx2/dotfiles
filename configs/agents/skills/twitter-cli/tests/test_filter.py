"""Tests for twitter_cli.filter module."""

from __future__ import annotations

from twitter_cli.filter import filter_tweets, score_tweet


def test_filter_tweets_does_not_mutate_input(tweet_factory) -> None:
    tweet = tweet_factory("1", score=0.0)
    output = filter_tweets([tweet], {"mode": "all", "weights": {}})

    assert tweet.score == 0.0
    assert output[0].score > 0.0
    assert output[0] is not tweet


def test_filter_tweets_applies_language_and_retweet_filters(tweet_factory) -> None:
    tweets = [
        tweet_factory("1", lang="en", is_retweet=False),
        tweet_factory("2", lang="zh", is_retweet=False),
        tweet_factory("3", lang="en", is_retweet=True),
    ]
    output = filter_tweets(
        tweets,
        {
            "mode": "all",
            "lang": ["en"],
            "excludeRetweets": True,
            "weights": {},
        },
    )

    assert [tweet.id for tweet in output] == ["1"]


def test_filter_topn_mode(tweet_factory) -> None:
    tweets = [tweet_factory(str(i)) for i in range(10)]
    output = filter_tweets(tweets, {"mode": "topN", "topN": 3})
    assert len(output) == 3


def test_filter_topn_default(tweet_factory) -> None:
    """Default topN is 20, so 5 tweets should all be returned."""
    tweets = [tweet_factory(str(i)) for i in range(5)]
    output = filter_tweets(tweets, {"mode": "topN"})
    assert len(output) == 5


def test_filter_score_mode(tweet_factory) -> None:
    from twitter_cli.models import Metrics

    tweets = [
        tweet_factory("high", metrics=Metrics(likes=1000, retweets=500, replies=200, views=100000, bookmarks=50)),
        tweet_factory("low", metrics=Metrics(likes=0, retweets=0, replies=0, views=1, bookmarks=0)),
    ]
    output = filter_tweets(tweets, {"mode": "score", "minScore": 100.0})
    assert len(output) == 1
    assert output[0].id == "high"


def test_filter_empty_input() -> None:
    output = filter_tweets([], {"mode": "all"})
    assert output == []


def test_score_tweet_basic(tweet_factory) -> None:
    tweet = tweet_factory("1")
    score = score_tweet(tweet)
    assert isinstance(score, float)
    assert score > 0


def test_score_tweet_custom_weights(tweet_factory) -> None:
    tweet = tweet_factory("1")
    weights = {"likes": 0, "retweets": 0, "replies": 0, "bookmarks": 0, "views_log": 0}
    assert score_tweet(tweet, weights) == 0.0


def test_filter_all_mode_sorts_by_score(tweet_factory) -> None:
    from twitter_cli.models import Metrics

    tweets = [
        tweet_factory("low", metrics=Metrics(likes=1)),
        tweet_factory("high", metrics=Metrics(likes=100)),
    ]
    output = filter_tweets(tweets, {"mode": "all"})
    assert output[0].id == "high"
    assert output[1].id == "low"
