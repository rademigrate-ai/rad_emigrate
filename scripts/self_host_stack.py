#!/usr/bin/env python3
"""Prepare and operate an explicitly owned, disposable official self-host test stack.

No cloud credentials, CLI dev stack, public bind, implicit teardown or resets.
The offline bundle stays unchanged; install copies and secrets live outside Git.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import re
import secrets
import shutil
import subprocess
import time
from pathlib import Path

MARKER = "RAD_DISPOSABLE_SELF_HOST_V1"


def storage_response_privacy(template: str) -> str:
    """Keep the pinned Storage route/auth unchanged; disable response caching."""
    anchor = "                          prefix: /storage/v1/\n                        route:\n"
    replacement = (
        "                          prefix: /storage/v1/\n"
        "                        # RAD_PRIVATE_STORAGE_NO_STORE\n"
        "                        response_headers_to_add:\n"
        "                          - header:\n"
        "                              key: cache-control\n"
        "                              value: private, no-store, max-age=0\n"
        "                            append_action: OVERWRITE_IF_EXISTS_OR_ADD\n"
        "                        route:\n"
    )
    if template.count(replacement) == 1:
        return template
    if template.count(anchor) != 1 or "RAD_PRIVATE_STORAGE_NO_STORE" in template:
        raise ValueError(
            "pinned Storage gateway route differs; review before preparing"
        )
    return template.replace(anchor, replacement, 1)


def run(args: list[str], **kwargs) -> subprocess.CompletedProcess:
    result = subprocess.run(args, capture_output=True, **kwargs)
    if result.returncode:
        # Docker/SQL output can contain interpolated credentials. Never echo it.
        raise RuntimeError(
            f"{Path(args[0]).name} operation failed (exit {result.returncode})"
        )
    return result


def save(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf8")


def jwt(secret: str, role: str) -> str:
    def b64(value: bytes) -> str:
        return base64.urlsafe_b64encode(value).rstrip(b"=").decode()

    now = int(time.time())
    head = b64(b'{"alg":"HS256","typ":"JWT"}')
    body = b64(
        json.dumps(
            {"role": role, "iss": "supabase", "iat": now, "exp": now + 86400 * 30}
        ).encode()
    )
    signed = head + "." + body
    return (
        signed
        + "."
        + b64(hmac.new(secret.encode(), signed.encode(), hashlib.sha256).digest())
    )


def compose(root: Path, *args: str) -> list[str]:
    identity = json.loads((root / "RAD_ISOLATED_INSTALL.json").read_text("utf8"))
    if identity.get("marker") != MARKER or not re.fullmatch(
        r"rad-selfhost-[a-z0-9-]+", identity["project"]
    ):
        raise ValueError("not an owned disposable RAD self-host install")
    return [
        "docker",
        "compose",
        "--project-directory",
        str(root),
        "--env-file",
        str(root / ".env"),
        "-p",
        identity["project"],
        "-f",
        str(root / "compose.rad.json"),
        *args,
    ]


def prepare(bundle: Path, output: Path, project: str, port: int) -> dict:
    bundle, output = bundle.resolve(), output.resolve()
    if output.exists() or not re.fullmatch(r"rad-selfhost-[a-z0-9-]+", project):
        raise ValueError("new output and distinct rad-selfhost-* project required")
    if not 1024 < port < 65535 or port in range(54320, 54330):
        raise ValueError("choose a distinct unprivileged loopback API port")
    manifest = json.loads((bundle / "RAD_BUNDLE_MANIFEST.json").read_text("utf8"))
    for name, digest in manifest["tracked_app_file_sha256"].items():
        relative = Path(name)
        source = (
            bundle / "rad_migrations" / relative.name
            if relative.parts[1] == "migrations"
            else bundle / "volumes/functions" / Path(*relative.parts[2:])
        )
        if (
            source.is_symlink()
            or hashlib.sha256(source.read_bytes()).hexdigest() != digest
        ):
            raise ValueError("bundle application source hash mismatch")
    if any(bundle.rglob(".env")):
        raise ValueError("input bundle contains live secrets")
    raw = run(
        [
            "docker",
            "compose",
            "--project-directory",
            str(bundle),
            "--env-file",
            str(bundle / ".env.example"),
            "-f",
            str(bundle / "docker-compose.yml"),
            "config",
            "--no-interpolate",
            "--no-path-resolution",
            "--format",
            "json",
        ]
    )
    model = json.loads(raw.stdout)
    model["name"] = project
    model.pop("networks", None)
    model["volumes"] = {
        name: {}
        for name in ("db-data", "db-config", "storage-data", "deno-cache", "snippets")
    }
    limits = {"db": "1200m", "studio": "512m", "realtime": "512m", "functions": "768m"}
    for name, service in model["services"].items():
        service.pop("container_name", None)
        service.pop("ports", None)
        service.pop("networks", None)
        service["mem_limit"] = limits.get(name, "384m")
        service["pids_limit"] = 256
        service["logging"] = {
            "driver": "json-file",
            "options": {"max-size": "10m", "max-file": "3"},
        }
        service["security_opt"] = ["no-new-privileges:true"]
        for mount in service.get("volumes", []):
            target = mount["target"]
            volume = {
                "/var/lib/postgresql/data": "db-data",
                "/var/lib/storage": "storage-data",
                "/app/snippets": "snippets",
            }.get(target)
            if volume:
                mount.clear()
                mount.update(type="volume", source=volume, target=target)
            elif mount["type"] == "bind":
                mount["read_only"] = True
                mount["bind"] = {"create_host_path": False}
        if name == "api-gw":
            service["ports"] = [
                {
                    "target": 8000,
                    "published": str(port),
                    "host_ip": "127.0.0.1",
                    "protocol": "tcp",
                }
            ]
            service["networks"] = {"default": {"aliases": ["envoy", "kong"]}}
        if name == "supavisor":
            service["profiles"] = ["pooler"]
        if name == "realtime":
            service["hostname"] = "realtime-dev.supabase-realtime"
    model["services"]["test-mail"] = {
        "image": "public.ecr.aws/supabase/mailpit@sha256:ed9b00c609e77e99c79b93f1178255ebc271868920f2c69a8d166bd5634ed10d",
        "restart": "unless-stopped",
        "mem_limit": "128m",
        "pids_limit": 128,
        "ports": [
            {
                "target": 8025,
                "published": str(port + 25),
                "host_ip": "127.0.0.1",
                "protocol": "tcp",
            }
        ],
        "environment": {"MP_SMTP_BIND_ADDR": "0.0.0.0:1025"},
        "logging": {
            "driver": "json-file",
            "options": {"max-size": "10m", "max-file": "2"},
        },
    }
    # Generated local credentials only. External mail, paid AI, research egress and
    # automatic workers stay disabled until their distinct operational approvals.
    env = {}
    for line in (bundle / ".env.example").read_text("utf8").splitlines():
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            env[key] = value
    for key in (
        "POSTGRES_PASSWORD",
        "JWT_SECRET",
        "DASHBOARD_PASSWORD",
        "SECRET_KEY_BASE",
        "VAULT_ENC_KEY",
        "PG_META_CRYPTO_KEY",
        "REALTIME_DB_ENC_KEY",
        "S3_PROTOCOL_ACCESS_KEY_SECRET",
    ):
        env[key] = secrets.token_hex(
            32 if key not in {"VAULT_ENC_KEY", "REALTIME_DB_ENC_KEY"} else 16
        )
    # Realtime's pinned release uses AES-128 ECB for tenant configuration and
    # requires exactly 16 bytes (Vault separately requires 32 characters).
    env["REALTIME_DB_ENC_KEY"] = secrets.token_hex(8)
    env.update(
        ANON_KEY=jwt(env["JWT_SECRET"], "anon"),
        SERVICE_ROLE_KEY=jwt(env["JWT_SECRET"], "service_role"),
        POSTGRES_HOST="db",
        POSTGRES_PORT="5432",
        POSTGRES_DB="postgres",
        FUNCTIONS_VERIFY_JWT="true",
        SITE_URL="http://127.0.0.1:58080",
        API_EXTERNAL_URL=f"http://127.0.0.1:{port}",
        SUPABASE_PUBLIC_URL=f"http://127.0.0.1:{port}",
        ADDITIONAL_REDIRECT_URLS="http://127.0.0.1:58080/**",
        ENABLE_EMAIL_AUTOCONFIRM="false",
        SMTP_HOST="test-mail",
        SMTP_PORT="1025",
        SMTP_USER="",
        SMTP_PASS="",
        DASHBOARD_USERNAME="rad-operator",
        DISABLE_SIGNUP="false",
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(bundle, output)
    gateway = output / "volumes/api/envoy/lds.template.yaml"
    original_gateway_sha = hashlib.sha256(gateway.read_bytes()).hexdigest()
    gateway.write_bytes(storage_response_privacy(gateway.read_text("utf8")).encode())
    save(
        output / "STORAGE_GATEWAY_PRIVACY.json",
        {
            "scope": "ALL_STORAGE_RESPONSES_PRIVATE_NO_STORE",
            "original_template_sha256": original_gateway_sha,
            "installed_template_sha256": hashlib.sha256(
                gateway.read_bytes()
            ).hexdigest(),
            "authorization_and_prefix_rewrite": "UNCHANGED",
        },
    )
    (output / ".env").write_text(
        "".join(f"{key}={value}\n" for key, value in env.items()), encoding="utf8"
    )
    (output / ".env").chmod(0o600)
    save(output / "compose.rad.json", model)
    identity = {
        "marker": MARKER,
        "project": project,
        "api_port": port,
        "rad_commit": manifest["rad_commit"],
        "upstream_commit": manifest["official_self_hosted_commit"],
        "migration_count": manifest["migration_count"],
    }
    save(output / "RAD_ISOLATED_INSTALL.json", identity)
    run(compose(output, "config", "--quiet"))
    return identity


def pin(root: Path, lock_file: Path | None = None) -> dict:
    model = json.loads((root / "compose.rad.json").read_text("utf8"))
    lock = json.loads(lock_file.read_text("utf8")) if lock_file else None
    images = {}
    for service in model["services"].values():
        tag = service["image"]
        reference = tag
        if lock is not None:
            locked = lock.get(tag) or next(
                (v for v in lock.values() if v["digest"] == tag), None
            )
            if not locked or locked.get("architecture") != "amd64":
                raise ValueError("image missing from approved amd64 digest lock")
            reference = locked["digest"]
        run(["docker", "pull", reference])
        details = json.loads(run(["docker", "image", "inspect", reference]).stdout)[0]
        digests = details.get("RepoDigests") or []
        if not digests:
            raise ValueError("image lacks immutable repository digest")
        if lock is not None and reference not in digests:
            raise ValueError("downloaded image does not match locked digest")
        images[tag] = {
            "digest": digests[0],
            "image_id": details["Id"],
            "architecture": details["Architecture"],
        }
        service["image"] = digests[0]
        save(root / "IMAGE_DIGESTS.json", images)
        print("Pinned " + tag, flush=True)
    save(root / "compose.rad.json", model)
    return images


def sql(root: Path, statement: bytes) -> subprocess.CompletedProcess:
    return run(
        compose(
            root,
            "exec",
            "-T",
            "db",
            "psql",
            "-XAtq",
            "-U",
            "supabase_admin",
            "-d",
            "postgres",
            "-v",
            "ON_ERROR_STOP=1",
        ),
        input=statement,
    )


def migrate(root: Path) -> dict:
    # Fresh installs only: no guessing a managed project's history/alias baseline.
    foundations = sql(
        root,
        b"select (to_regclass('auth.sessions') is not null and to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null)::int;",
    ).stdout.strip()
    if foundations != b"1":
        raise ValueError(
            "start official Auth and Storage first; their schemas must exist before RAD migrations"
        )
    count = int(
        sql(root, b"select count(*) from pg_tables where schemaname='public';").stdout
    )
    if count:
        raise ValueError(
            "migration runner requires empty RAD public schema; no reset or overwrite"
        )
    history = []
    sql(
        root,
        b"create schema if not exists rad_install; create table rad_install.migrations(version text primary key, sha256 text not null, applied_at timestamptz not null default now());",
    )
    statements = []
    for path in sorted((root / "rad_migrations").glob("*.sql")):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        # Some authoritative legacy sources contain BEGIN without COMMIT. CLI
        # migration execution commits them; a separate psql session silently
        # rolls them back. Explicitly close each file without editing its bytes.
        statements.extend(
            [
                b"BEGIN;\n",
                path.read_bytes(),
                f"\ninsert into rad_install.migrations values ('{path.stem}', '{digest}', now());\nCOMMIT;\n".encode(),
            ]
        )
        history.append({"file": path.name, "sha256": digest})
    try:
        sql(root, b"".join(statements))
    except RuntimeError:
        applied = (
            sql(root, b"select version from rad_install.migrations order by version;")
            .stdout.decode()
            .splitlines()
        )
        failed = next(
            (p["file"] for p in history if Path(p["file"]).stem not in applied),
            "unknown",
        )
        save(
            root / "MIGRATION_RECEIPT.json",
            {"status": "FAILED", "applied_versions": applied, "failed_file": failed},
        )
        raise RuntimeError("self-host migration failed at " + failed) from None
    result = {"status": "APPLIED_FRESH_NOT_RUNTIME_ACCEPTANCE", "applied": history}
    save(root / "MIGRATION_RECEIPT.json", result)
    return result


def start(root: Path, wait_seconds: int = 240) -> None:
    """Allow transient health failures during a bounded, non-destructive boot."""
    run(compose(root, "up", "-d"))
    model = json.loads((root / "compose.rad.json").read_text("utf8"))
    expected = {
        name
        for name, service in model["services"].items()
        if not service.get("profiles")
    }
    deadline = time.monotonic() + wait_seconds
    unready = expected
    while time.monotonic() < deadline:
        result = run(compose(root, "ps", "--all", "--format", "json"))
        services = [
            json.loads(line) for line in result.stdout.decode().splitlines() if line
        ]
        ready = {
            item["Service"]
            for item in services
            if item["State"] == "running" and item.get("Health", "") in ("", "healthy")
        }
        unready = expected - ready
        if not unready:
            return
        if any(
            item["Service"] in unready and item["State"] in ("exited", "dead")
            for item in services
        ):
            raise RuntimeError(
                "self-host service exited; inspect private operator logs"
            )
        time.sleep(2)
    raise RuntimeError(
        "self-host health deadline exceeded: " + ",".join(sorted(unready))
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command", choices=["prepare", "pin", "start", "migrate", "status"]
    )
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--project", default="rad-selfhost-acceptance-20261104")
    parser.add_argument("--port", type=int, default=58000)
    parser.add_argument("--image-lock", type=Path)
    parser.add_argument("--wait-seconds", type=int, default=240)
    args = parser.parse_args()
    root = args.root.resolve()
    if args.command == "prepare":
        print(json.dumps(prepare(args.bundle, root, args.project, args.port)))
    elif args.command == "pin":
        pin(root, args.image_lock)
    elif args.command == "start":
        if not 1 <= args.wait_seconds <= 900:
            parser.error("--wait-seconds must be between 1 and 900")
        start(root, args.wait_seconds)
        print("Owned isolated stack started; runtime acceptance pending")
    elif args.command == "migrate":
        print("Applied migrations:", len(migrate(root)["applied"]))
    else:
        result = run(compose(root, "ps", "--format", "json"))
        for line in result.stdout.decode().splitlines():
            item = json.loads(line)
            print(item["Service"], item["State"], item.get("Health", ""))


if __name__ == "__main__":
    main()
