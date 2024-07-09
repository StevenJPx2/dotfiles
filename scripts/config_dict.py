from typing import TypedDict


class ConfigDict(TypedDict, total=False):
    install_path: str
    pre_install: str
    post_install: str
