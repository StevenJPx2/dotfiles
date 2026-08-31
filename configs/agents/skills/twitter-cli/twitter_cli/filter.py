"""Tweet filtering and engagement scoring.

Scores tweets by a weighted engagement formula and filters by
configurable rules (topN, min score, language, etc.).
"""

from __future__ import annotations

from dataclasses import replace
import math
from typing import Any, Dict, List, Mapping, Optional, Sequence

from .config import _as_float, _as_int
from .models import Tweet

DEFAULT_WEIGHTS = {
    "likes": 1.0,
    "retweets": 3.0,
    "replies": 2.0,
    "bookmarks": 5.0,
    "views_log": 0.5,
}


def score_tweet(tweet: Tweet, weights: Optional[Dict[str, float]] = None) -> float:
    """Calculate engagement score for a single tweet.

    Formula:
      score = w_likes × likes
            + w_retweets × retweets
            + w_replies × replies
            + w_bookmarks × bookmarks
            + w_views_log × log10(views)

    Args:
        weights: Pre-built weight dict. If None, uses DEFAULT_WEIGHTS.
    """
    w = weights or DEFAULT_WEIGHTS
    m = tweet.metrics
    return (
        w.get("likes", 1.0) * m.likes
        + w.get("retweets", 3.0) * m.retweets
        + w.get("replies", 2.0) * m.replies
        + w.get("bookmarks", 5.0) * m.bookmarks
        + w.get("views_log", 0.5) * math.log10(max(m.views, 1))
    )


def filter_tweets(tweets: Sequence[Tweet], config: Mapping[str, Any]) -> List[Tweet]:
    """Filter and rank tweets according to config.

    Config keys:
      mode: "topN" | "score" | "all"
      topN: int
      minScore: float
      lang: list[str]  (empty = no filter)
      excludeRetweets: bool
      weights: dict
    """
    filtered = list(tweets)

    # 1. Language filter
    lang_filter = config.get("lang", [])
    if lang_filter:
        lang_set = {str(lang) for lang in lang_filter if str(lang)}
        filtered = [tweet for tweet in filtered if tweet.lang in lang_set]

    # 2. Exclude retweets
    if config.get("excludeRetweets", False):
        filtered = [tweet for tweet in filtered if not tweet.is_retweet]

    # 3. Score all tweets
    weights = _build_weights(config.get("weights", {}))
    scored = [replace(tweet, score=round(score_tweet(tweet, weights), 1)) for tweet in filtered]

    # 4. Sort by score (descending)
    scored.sort(key=lambda tweet: tweet.score or 0.0, reverse=True)

    # 5. Apply filter mode
    mode = str(config.get("mode", "topN"))
    if mode == "topN":
        top_n = max(_as_int(config.get("topN"), 20), 1)
        return scored[:top_n]
    if mode == "score":
        min_score = _as_float(config.get("minScore"), 50.0)
        return [tweet for tweet in scored if (tweet.score or 0.0) >= min_score]
    return scored


def _build_weights(raw_weights: Mapping[str, Any]) -> Dict[str, float]:
    """Merge custom weights with defaults and coerce to float."""
    merged = {}
    for key, default_value in DEFAULT_WEIGHTS.items():
        merged[key] = _as_float(raw_weights.get(key), default_value)
    return merged
