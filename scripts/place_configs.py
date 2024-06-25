import argparse
import difflib
import json
import shutil
from difflib import SequenceMatcher
from pathlib import Path
from typing import TypedDict


class ConfigDict(TypedDict, total=False):
    install_path: str


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-y",
        "--yes-all",
        action="store_true",
        default=False,
        help="Skip confirmation prompts",
    )
    args = parser.parse_args()

    for config_json in Path("./configs").glob("*/config.json"):
        config: ConfigDict = json.loads(config_json.read_text())
        install_path = config.get("install_path")

        if install_path is None:
            raise ValueError(f"'install_path' not found in {config_json}")

        install_path = Path(install_path)

        install_path.mkdir(parents=True, exist_ok=True)

        for file in config_json.parent.iterdir():
            if file.name == "config.json":
                continue

            file_text = file.open().readlines()
            dst_path = install_path / file.name
            dst_text = dst_path.open().readlines()

            if dst_path.is_file() and not args.yes_all:
                diff = SequenceMatcher(lambda x: x in " \t", file_text, dst_text)
                if diff.quick_ratio() < 1:
                    print(difflib.unified_diff(file_text, dst_text))
                    accept = input("Do you want to accept these changes? [Y]/N")
                    if accept.strip().upper() == "N":
                        print(f"Not injecting {file.name}")
                        continue

            shutil.copyfile(file, dst_path)


if __name__ == "__main__":
    main()
