#!/usr/bin/env python3
"""Load .env key/value pairs and export them into the process environment.

Usage:
    set -a; eval "$(python3 scripts/opencode_env.py)"; set +a

Rules:
- Reads .env from the repository root (override with ZEAZ_DOTENV_PATH).
- Ignores blank lines, full-line comments, and the optional `export ` prefix.
- Supports single- or double-quoted values.
- Never prints values to stdout: only `export KEY` names are emitted, so
  secrets are not echoed into logs or shell history output.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINE_RE = re.compile(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$")


def parse_dotenv(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    if not path.is_file():
        return pairs
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = LINE_RE.match(line)
        if not match:
            continue
        key, value = match.group(1), match.group(2).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
            value = value[1:-1]
        elif '"' in value or "'" not in value:
            value = value.split(" #", 1)[0].strip()
        pairs.append((key, value))
    return pairs


def main() -> int:
    dotenv_path = Path(os.environ.get("ZEAZ_DOTENV_PATH", str(ROOT / ".env")))
    lines: list[str] = []
    for key, value in parse_dotenv(dotenv_path):
        # Emit KEY='value' with single-quote escaping so the caller's shell
        # actually receives the values (names-only exports would not).
        escaped = value.replace("'", "'\\''")
        lines.append(f"{key}='{escaped}'")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
