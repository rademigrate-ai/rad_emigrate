"""Run repository CI keyword/credential scans with path-only output."""

import argparse
import subprocess
from pathlib import Path

from tools.content_completion.phase_bundle import save_json


def scan(directory):
    git = ["git", "-c", "safe.directory=" + Path.cwd().as_posix()]
    head = subprocess.check_output([*git, "rev-parse", "HEAD"], text=True).strip()
    patterns = {
        "audit_keywords": r"TODO|FIXME|demo|fake|mock|password|service_role|secret|SUPABASE_SERVICE",
        "high_risk_credentials": r"sb_secret_[A-Za-z0-9]+|eyJ[A-Za-z0-9_-]{40,}[.][A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|SUPABASE_SERVICE_ROLE_KEY[[:space:]]*=[[:space:]]*[^<$[:space:]][^[:space:]]+",
    }
    results = {}
    for rule, pattern in patterns.items():
        command = [
            *git,
            "grep",
            "-I",
            "-i",
            "-l",
            "-E",
            pattern,
            head,
            "--",
            ".",
            ":(exclude)pubspec.lock",
            ":(exclude).github/workflows/ci.yml",
        ]
        result = subprocess.run(
            command, capture_output=True, text=True, encoding="utf-8"
        )
        if result.returncode not in (0, 1):
            raise ValueError("tracked_scan_failed")
        results[rule] = {
            "exit_code": result.returncode,
            "paths": result.stdout.splitlines(),
            "interpretation": "review locations; test fixtures and defensive error names are not credential disclosures"
            if rule == "audit_keywords"
            else "must_have_zero_matches",
        }
    save_json(
        directory / "verification/security/keyword-scan.json",
        {
            "head": head,
            "scope": "CI tracked-text path-only patterns; not a substitute for platform secret stores or encrypted archive scanning",
            "rules": results,
        },
    )
    if results["high_risk_credentials"]["paths"]:
        raise ValueError("potential_credentials_require_review_values_not_printed")
    print(
        "PASS: tracked credential patterns; audit keyword paths retained without values"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    scan(parser.parse_args().directory)
