import argparse
import difflib
import json
import os
import shutil
import subprocess
from difflib import SequenceMatcher
from pathlib import Path

from config_dict import ConfigDict


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
        pre_install_command = config.get("pre_install")
        post_install_command = config.get("post_install")

        if install_path is None:
            raise ValueError(f"'install_path' not found in {config_json}")

        if pre_install_command is not None:
            subprocess.run(pre_install_command, shell=True)

        install_path = Path(install_path).expanduser().resolve()

        install_path.mkdir(parents=True, exist_ok=True)

        for file_root, _, filenames in os.walk(config_json.parent):
            for file_name in filenames:
                file = Path(file_root) / file_name
                if file.name == "config.json":
                    continue

                dst_path = install_path / "/".join(file_root.split("/")[2:]) / file_name
                try:
                    file_text = file.open().readlines()
                except UnicodeDecodeError:
                    file_text = None

                if dst_path.is_file() and not args.yes_all and file_text is not None:
                    dst_text = dst_path.open().readlines()

                    diff = SequenceMatcher(lambda x: x in " \t", file_text, dst_text)
                    if diff.quick_ratio() < 1:
                        print(
                            "\n".join(
                                difflib.unified_diff(
                                    dst_text,
                                    file_text,
                                    fromfile=str(file),
                                    tofile=str(dst_path),
                                ),
                            )
                        )
                        accept = input("Do you want to accept these changes? [Y]/N ")
                        if accept.strip().upper() == "N":
                            print(
                                f"Not injecting {file.name}",
                                str(file.relative_to(config_json.parent)),
                            )
                            continue
                shutil.copy(
                    file,
                    dst_path.with_name(dst_path.name.replace("dot_", ".")),
                )

        if post_install_command is not None:
            subprocess.run(post_install_command, shell=True)


if __name__ == "__main__":
    main()
