import argparse
import json
from pathlib import Path

from config_dict import ConfigDict


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="Name of the config")
    args = parser.parse_args()

    config_dir = Path(__file__).parent.parent / "configs" / str(args.name)
    config_dir.mkdir()

    config_file_path = config_dir / "config.json"

    config_file_path.write_text(
        json.dumps(ConfigDict(install_path=f"~/.config/{args.name}"))
    )


if __name__ == "__main__":
    main()
