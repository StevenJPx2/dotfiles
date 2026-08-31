"""twitter-cli: A CLI for Twitter/X."""

try:
    from importlib.metadata import version

    __version__ = version("twitter-cli")
except Exception:
    __version__ = "0.0.0"
