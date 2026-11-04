#!/usr/bin/env python3
"""Background runner for OpenCode CLI prompts.

Runs an OpenCode non-interactive prompt in a detached process, writing all
output to a per-run log file under .tmp/opencode/ so the caller's terminal is
never blocked and output survives shell exit.

Usage:
    python3 scripts/opencode_bg.py run -- <opencode args...>
    python3 scripts/opencode_bg.py status [RUN_ID]
    python3 scripts/opencode_bg.py tail RUN_ID [N]
    python3 scripts/opencode_bg.py list

Exit codes:
    run:     0 launched, 2 invalid usage
    status:  0 completed, 1 running, 2 unknown run id
    list:    always 0
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNS_DIR = ROOT / ".tmp" / "opencode"


def _runs_dir() -> Path:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    return RUNS_DIR


def _run_paths(run_id: str) -> tuple[Path, Path, Path]:
    base = _runs_dir()
    if not re.fullmatch(r"[A-Za-z0-9._-]+", run_id):
        raise SystemExit(f"ERROR: invalid run id: {run_id!r}")
    return (
        base / f"{run_id}.log",
        base / f"{run_id}.pid",
        base / f"{run_id}.json",
    )


def cmd_run(argv: list[str]) -> int:
    if not argv or argv[0] != "--":
        print("usage: opencode_bg.py run -- <opencode args...>", file=sys.stderr)
        return 2
    args = argv[1:]
    if not args:
        print("ERROR: no opencode arguments supplied after --", file=sys.stderr)
        return 2

    run_id = time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    log_path, pid_path, meta_path = _run_paths(run_id)

    with log_path.open("w", encoding="utf-8") as log_file:
        proc = subprocess.Popen(
            args,
            cwd=str(ROOT),
            stdout=log_file,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    pid_path.write_text(str(proc.pid), encoding="utf-8")
    meta_path.write_text(
        json.dumps(
            {"run_id": run_id, "pid": proc.pid, "args": args, "started": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "log": str(log_path)},
            indent=2,
        ),
        encoding="utf-8",
    )
    print(run_id)
    return 0


def _is_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def cmd_status(run_id: str | None) -> int:
    if run_id is None:
        metas = sorted(_runs_dir().glob("*.json"))
        if not metas:
            print("no runs recorded")
            return 0
        run_id = metas[-1].stem
    log_path, pid_path, meta_path = _run_paths(run_id)
    if not meta_path.exists() and not pid_path.exists():
        print(f"unknown run id: {run_id}", file=sys.stderr)
        return 2
    pid = int(pid_path.read_text(encoding="utf-8")) if pid_path.exists() else -1
    running = pid > 0 and _is_running(pid)
    print(f"run: {run_id}\npid: {pid}\nstate: {'running' if running else 'completed'}\nlog: {log_path}")
    return 0 if not running else 1


def cmd_tail(run_id: str, n: int) -> int:
    log_path, _, _ = _run_paths(run_id)
    if not log_path.exists():
        print(f"no log for run id: {run_id}", file=sys.stderr)
        return 2
    lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    for line in lines[-max(1, n):]:
        print(line)
    return 0


def cmd_list() -> int:
    base = _runs_dir()
    metas = sorted(base.glob("*.json"))
    if not metas:
        print("no runs recorded")
        return 0
    for meta in metas:
        try:
            data = json.loads(meta.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        running = _is_running(int(data.get("pid", -1)))
        state = "running" if running else "done   "
        print(f"{data['run_id']}  [{state}]  {' '.join(data['args'])[:80]}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    p_run = sub.add_parser("run")
    p_run.add_argument("rest", nargs=argparse.REMAINDER)
    p_status = sub.add_parser("status")
    p_status.add_argument("run_id", nargs="?")
    p_tail = sub.add_parser("tail")
    p_tail.add_argument("run_id")
    p_tail.add_argument("n", nargs="?", type=int, default=50)
    sub.add_parser("list")
    ns = parser.parse_args()

    if ns.command == "run":
        return cmd_run(ns.rest)
    if ns.command == "status":
        return cmd_status(ns.run_id)
    if ns.command == "tail":
        return cmd_tail(ns.run_id, ns.n)
    return cmd_list()


if __name__ == "__main__":
    raise SystemExit(main())
