"""Check public build configuration and compiled artifacts without credentials."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from urllib.parse import urlsplit

from scripts.staging_environment import legacy_public_claims

PRODUCTION = "inshddthftkhcdosoqcn"
SECRET = re.compile(
    rb"(?:sb_secret_[A-Za-z0-9_-]{20,}|sbp_[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,})"
)
JWT = re.compile(rb"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")


def validate_environment(values):
    environment = values.get("APP_ENV", "production")
    parsed = urlsplit(values.get("SUPABASE_URL", ""))
    if (
        environment not in ("production", "staging", "development")
        or parsed.scheme != "https"
        or not parsed.hostname
        or not re.fullmatch(r"[a-z0-9-]+\.supabase\.co", parsed.hostname)
        or parsed.netloc != parsed.hostname
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError("canonical_https_supabase_origin_required")
    project = parsed.hostname.split(".")[0]
    if environment == "production" and project != PRODUCTION:
        raise ValueError("production_project_binding_required")
    if any(
        values.get(name)
        for name in ("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEY")
    ):
        raise ValueError("backend_secret_not_allowed_in_web_build_environment")
    key = values.get("SUPABASE_PUBLISHABLE_KEY") or values.get("SUPABASE_ANON_KEY", "")
    if re.fullmatch(r"sb_publishable_[A-Za-z0-9_-]{20,200}", key):
        kind = "publishable"
    else:
        claims = legacy_public_claims(key)
        if claims.get("role") != "anon" or claims.get("ref") != project:
            raise ValueError("public_anon_key_for_exact_project_required")
        kind = "legacy_anon"
    return {
        "environment": environment,
        "project": project,
        "origin": f"https://{parsed.hostname}",
        "public_key_kind": kind,
    }


def verify_artifact(directory, values, expected_commit):
    config = validate_environment(values)
    if not re.fullmatch(r"[a-f0-9]{40}", expected_commit):
        raise ValueError("exact_commit_required")
    version = json.loads((directory / "version.json").read_text("utf8"))
    if version != {"git_sha": expected_commit, "flutter": "3.47.6"}:
        raise ValueError("artifact_version_commit_mismatch")
    if (directory / "404.html").read_bytes() != (directory / "index.html").read_bytes():
        raise ValueError("spa_fallback_must_match_index")
    main = (directory / "main.dart.js").read_bytes()
    key = values.get("SUPABASE_PUBLISHABLE_KEY") or values.get("SUPABASE_ANON_KEY", "")
    if config["origin"].encode() not in main or key.encode() not in main:
        raise ValueError("compiled_public_configuration_not_found")
    origins = set(re.findall(rb"https://[a-z0-9-]+\.supabase\.co", main))
    if origins != {config["origin"].encode()}:
        raise ValueError("unexpected_supabase_origin_in_bundle")
    files = {}
    for path in sorted(directory.rglob("*")):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if SECRET.search(data):
            raise ValueError("credential_pattern_in_artifact:" + path.name)
        for match in JWT.finditer(data):
            claims = legacy_public_claims(match.group().decode())
            if claims.get("role") != "anon" or claims.get("ref") != config["project"]:
                raise ValueError(
                    "nonpublic_or_wrong_project_jwt_in_artifact:" + path.name
                )
        files[path.relative_to(directory).as_posix()] = hashlib.sha256(data).hexdigest()
    return config | {
        "status": "PASS_BUILD_ARTIFACT_NOT_DEPLOYMENT_ACCEPTANCE",
        "commit": expected_commit,
        "file_count": len(files),
        "tree_sha256": hashlib.sha256(
            json.dumps(files, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest(),
        "spa_fallback": "PASS",
        "privileged_key_scan": "PASS",
        "production_content_acceptance": "SEPARATE_REQUIRED_GATE",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scope", choices=("environment", "artifact"), required=True)
    parser.add_argument("--directory", type=Path, default=Path("build/web"))
    args = parser.parse_args()
    try:
        if args.scope == "environment":
            report = validate_environment(os.environ)
        else:
            commit = subprocess.check_output(
                ["git", "rev-parse", "HEAD"], text=True
            ).strip()
            report = verify_artifact(args.directory, os.environ, commit)
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from None
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
