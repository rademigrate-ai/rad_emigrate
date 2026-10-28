"""Run acceptance at one immutable Git HEAD; save bounded, secret-free receipts.

Only loopback native SQL fixtures are supported. Builds use the repository CI's
non-production placeholder config and never contact hosted databases or deploy.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

from tools.content_completion.phase_bundle import save_json, sha


def git(*args):
    return subprocess.check_output(
        ["git", "-c", "safe.directory=" + Path.cwd().as_posix(), *args], text=True
    ).strip()


def run(args):
    head = git("rev-parse", "HEAD")
    if git("diff", "--name-only", "HEAD"):
        raise ValueError("tracked_worktree_must_match_final_HEAD")
    destination = args.directory / "verification" / args.group
    destination.mkdir(parents=True, exist_ok=True)
    python = sys.executable
    commands = []
    if args.group == "core":
        owned = [
            "tools/content_completion",
            "scripts/tests/test_phase_source_evidence.py",
        ]
        commands = [
            [
                "git",
                "-c",
                "safe.directory=" + Path.cwd().as_posix(),
                "diff",
                "--check",
                head + "^",
                head,
            ],
            ["node", "scripts/check_password_recovery_redirect.cjs"],
            [
                python,
                "-m",
                "tools.content_completion.phase_scan",
                "--directory",
                str(args.directory),
            ],
            [python, "-m", "ruff", "format", "--isolated", "--check", *owned],
            [
                python,
                "-m",
                "ruff",
                "check",
                "--isolated",
                "--select",
                "E4,E7,E9,F,I,UP,B",
                "--target-version",
                "py311",
                *owned,
            ],
            [python, "-m", "unittest", "discover", "-s", "scripts/tests", "-v"],
            [
                str(args.deno),
                "test",
                "--allow-env",
                "--allow-read=.",
                "supabase/functions/tests",
            ],
            [str(args.deno), "lint", "supabase/functions"],
            [
                python,
                "-m",
                "tools.content_consolidation.verify",
                "artifacts/RAD_CONTENT_CONSOLIDATION_20261026",
            ],
            [
                python,
                "-m",
                "tools.content_completion.phase_verify",
                "--directory",
                str(args.directory),
                "--reproduce",
            ],
        ]
    elif args.group == "flutter":
        dart = args.flutter.parent / "cache/dart-sdk/bin/dart.exe"
        commands = [
            [
                str(dart),
                "format",
                "--output=none",
                "--set-exit-if-changed",
                "lib",
                "test",
            ],
            [str(args.flutter), "analyze", "--no-pub"],
            [str(args.flutter), "test", "--no-pub"],
            [
                str(args.flutter),
                "build",
                "web",
                "--no-pub",
                "--dart-define=SUPABASE_URL=https://example.supabase.co",
                "--dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder",
            ],
            [
                str(args.flutter),
                "build",
                "apk",
                "--debug",
                "--no-pub",
                "--dart-define=SUPABASE_URL=https://example.supabase.co",
                "--dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder",
            ],
        ]
    else:
        for test in (
            "corrective_routing_research",
            "editorial_content_security",
            "editorial_legacy_slug",
            "stage7_research_review",
            "stage71_rich_review",
        ):
            commands.append(
                [
                    str(args.psql),
                    "-h",
                    "127.0.0.1",
                    "-p",
                    "64139",
                    "-U",
                    "postgres",
                    "-d",
                    "rad_content_rehearsal",
                    "-Xw",
                    "-v",
                    "ON_ERROR_STOP=1",
                    "-f",
                    "supabase/tests/" + test + ".sql",
                ]
            )
        commands.append(
            [
                python,
                "-m",
                "tools.content_completion.rehearse_delivery",
                "--directory",
                str(args.directory),
                "--psql",
                str(args.psql),
                "--database",
                "rad_content_rehearsal",
                "--port",
                "64139",
                "--report-directory",
                str(destination),
            ]
        )
    rows = []
    environment = dict(os.environ)
    environment.update(PGCLIENTENCODING="UTF8", PYTHONIOENCODING="utf-8")
    for index, command in enumerate(commands):
        if git("rev-parse", "HEAD") != head or git("diff", "--name-only", "HEAD"):
            raise ValueError("HEAD_or_tracked_files_changed_during_acceptance")
        path = destination / f"{index + 1:02d}.log"
        started = datetime.now(UTC).isoformat()
        clock = time.monotonic()
        with path.open("wb") as stream:
            result = subprocess.run(
                command,
                stdout=stream,
                stderr=subprocess.STDOUT,
                env=environment,
                timeout=1800,
            )
        row = {
            "head": head,
            "command": command,
            "started_at": started,
            "seconds": round(time.monotonic() - clock, 3),
            "exit_code": result.returncode,
            "log": path.relative_to(args.directory).as_posix(),
            "log_sha256": sha(path.read_bytes()),
        }
        rows.append(row)
        save_json(
            destination / "receipt.json",
            {
                "head": head,
                "group": args.group,
                "checks": rows,
                "all_passed": all(r["exit_code"] == 0 for r in rows),
                "planned_checks": len(commands),
                "completed_checks": len(rows),
                "artifact_manifest_sha256": sha(
                    (args.directory / "final-manifest.json").read_bytes()
                ),
                "hosted_writes": 0,
            },
        )
        print(json.dumps(row), flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
    if git("diff", "--name-only", "HEAD"):
        raise ValueError("tracked_files_changed_during_acceptance")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--group", choices=("core", "flutter", "sql"), required=True)
    parser.add_argument(
        "--flutter",
        type=Path,
        default=Path("C:/Users/Mehrshad/develop/flutter/bin/flutter.bat"),
    )
    parser.add_argument(
        "--deno", type=Path, default=Path("C:/Users/Mehrshad/.deno/bin/deno.exe")
    )
    parser.add_argument(
        "--psql", type=Path, default=Path("C:/Program Files/PostgreSQL/17/bin/psql.exe")
    )
    run(parser.parse_args())
