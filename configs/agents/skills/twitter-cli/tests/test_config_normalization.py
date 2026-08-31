from __future__ import annotations

from pathlib import Path

from twitter_cli.config import load_config


def test_filter_normalization_for_invalid_values(tmp_path: Path) -> None:
    config_file = tmp_path / "config.yaml"
    config_file.write_text(
        "\n".join(
            [
                "fetch:",
                "  count: -5",
                "filter:",
                "  mode: unknown",
                "  topN: -1",
                "  minScore: abc",
                "  lang: zh",
                "  weights:",
                "    likes: bad",
                "    retweets: 4",
            ]
        ),
        encoding="utf-8",
    )

    config = load_config(str(config_file))
    assert config["fetch"]["count"] == 1
    assert config["filter"]["mode"] == "topN"
    assert config["filter"]["topN"] == 1
    assert config["filter"]["minScore"] == 50.0
    assert config["filter"]["lang"] == []
    assert config["filter"]["weights"]["likes"] == 1.0
    assert config["filter"]["weights"]["retweets"] == 4.0
    # rateLimit should get defaults since it wasn't in the yaml
    assert config["rateLimit"]["requestDelay"] == 2.5
    assert config["rateLimit"]["maxRetries"] == 3
    assert config["rateLimit"]["retryBaseDelay"] == 5.0
    assert config["rateLimit"]["maxCount"] == 200


def test_rate_limit_normalization(tmp_path: Path) -> None:
    config_file = tmp_path / "config.yaml"
    config_file.write_text(
        "\n".join(
            [
                "rateLimit:",
                "  requestDelay: -2",
                "  maxRetries: bad",
                "  retryBaseDelay: 0.1",
                "  maxCount: 0",
            ]
        ),
        encoding="utf-8",
    )

    config = load_config(str(config_file))
    assert config["rateLimit"]["requestDelay"] == 0.0  # clamped to >= 0
    assert config["rateLimit"]["maxRetries"] == 3  # fallback to default
    assert config["rateLimit"]["retryBaseDelay"] == 1.0  # clamped to >= 1.0
    assert config["rateLimit"]["maxCount"] == 1  # clamped to >= 1
