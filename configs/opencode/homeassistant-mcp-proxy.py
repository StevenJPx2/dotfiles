#!/usr/bin/env python3
"""Bridge OpenCode's stdio MCP transport to Home Assistant using curl."""

import json
import os
import subprocess
import sys
import tempfile


ENDPOINT = "http://192.168.0.40:8123/api/mcp/assist"


def request(message: dict[str, object]) -> dict[str, object] | None:
    token = os.environ.get("HOMEASSISTANT_TOKEN")

    if not token:
        raise RuntimeError("HOMEASSISTANT_TOKEN is not set")

    payload = json.dumps(message)

    with tempfile.NamedTemporaryFile(mode="w", prefix="ha-mcp-", delete=True) as headers:
        headers.write(f"Authorization: Bearer {token}\n")
        headers.flush()

        result = subprocess.run(
            [
                "curl",
                "-sS",
                "--max-time",
                "30",
                "-X",
                "POST",
                ENDPOINT,
                "-H",
                f"@{headers.name}",
                "-H",
                "Accept: application/json, text/event-stream",
                "-H",
                "Content-Type: application/json",
                "--data-binary",
                payload,
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "curl failed")

    body = result.stdout.strip()

    if not body:
        return None

    if body.startswith("data:"):
        body = next(line[5:].strip() for line in body.splitlines() if line.startswith("data:"))

    return json.loads(body)


def main() -> None:
    for line in sys.stdin:
        try:
            message = json.loads(line)
            response = request(message)

            if response is not None:
                print(json.dumps(response), flush=True)
        except Exception as error:
            message_id = message.get("id") if isinstance(message, dict) else None

            if message_id is not None:
                print(
                    json.dumps(
                        {
                            "jsonrpc": "2.0",
                            "id": message_id,
                            "error": {"code": -32603, "message": str(error)},
                        }
                    ),
                    flush=True,
                )


if __name__ == "__main__":
    main()
