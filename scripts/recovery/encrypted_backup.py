#!/usr/bin/env python3
"""Stream PostgreSQL and staged Storage backups into age encryption.

No plaintext database archive is written. Production service mode requires a
separate owner/DBA approval record, TLS verification, and a declared write
freeze. These checks record intent; database and filesystem permissions remain
the security boundary. Private identities belong on the restore host only.
"""

import argparse
import configparser
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


def approval(args, operation):
    value = json.loads(Path(args.approval_file).read_text(encoding="utf-8"))
    if (value.get("project_ref") != args.project_ref or
            operation not in value.get("authorized_operations", []) or
            not value.get("owner_approval_reference") or not value.get("dba_approval_reference")):
        raise ValueError("missing or mismatched owner/DBA authorization record")
    if not args.writes_frozen:
        raise ValueError("production capture requires --writes-frozen")


def validate_service(args):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.service):
        raise ValueError("invalid service name")
    settings = configparser.ConfigParser(interpolation=None)
    filename = os.environ.get("PGSERVICEFILE")
    if not filename or not settings.read(filename) or args.service not in settings:
        raise ValueError("PGSERVICEFILE must identify an approved service")
    service = settings[args.service]
    if service.get("sslmode") != "verify-full" or service.get("password"):
        raise ValueError("service requires sslmode=verify-full and a separate protected passfile")
    if args.project_ref not in service.get("host", "") + service.get("user", ""):
        raise ValueError("service does not identify the approved project reference")
    if service.get("port", "5432") != "5432":
        raise ValueError("use direct/session connection, not transaction pooling")


def prefix(args, executable, auth=True):
    if args.docker_container:
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", args.docker_container):
            raise ValueError("invalid local container name")
        return ["docker", "exec", "-e", "PGTZ=UTC", "-e",
                "PGOPTIONS=-c default_transaction_read_only=on", args.docker_container,
                executable] + (["-U", "supabase_admin"] if auth else [])
    return [executable]


def encrypted_stream(command, args, name):
    partial = Path(args.output_dir) / (name + ".partial")
    producer = consumer = None
    # Ciphertext and sanitized status only; source stderr may contain secrets.
    with partial.open("xb") as output, open(os.devnull, "wb") as errors:
        try:
            producer = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=errors)
            consumer = subprocess.Popen([args.age, "--encrypt", "-R", args.recipients],
                                        stdin=producer.stdout, stdout=output, stderr=errors)
            producer.stdout.close()
            consumer_code = consumer.wait(timeout=args.timeout)
            producer_code = producer.wait(timeout=args.timeout)
            if producer_code or consumer_code:
                raise RuntimeError(f"{name}: producer exit={producer_code}, age exit={consumer_code}; partial retained")
        finally:
            for process in (producer, consumer):
                if process and process.poll() is None:
                    process.kill()
                    process.wait()
    partial.rename(partial.with_suffix(""))


def finish(args):
    entries = []
    for path in sorted(Path(args.output_dir).glob("*.age")):
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        entries.append({"file": path.name, "bytes": path.stat().st_size, "sha256": digest})
    manifest = {"format": "rad-encrypted-recovery-v1", "files": entries,
                "production_approval_record_checked": bool(args.service or
                    (args.command == "storage" and not args.synthetic))}
    with (Path(args.output_dir) / "ciphertext-manifest.json").open("x", encoding="utf-8") as stream:
        json.dump(manifest, stream, indent=2)
    print(json.dumps({"status": "PASS", "encrypted_files": len(entries)}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("database", "storage"):
        part = sub.add_parser(name)
        part.add_argument("--age", default="age")
        part.add_argument("--recipients", required=True)
        part.add_argument("--output-dir", required=True)
        part.add_argument("--project-ref")
        part.add_argument("--approval-file")
        part.add_argument("--writes-frozen", action="store_true")
        part.add_argument("--timeout", type=int, default=3600)
        part.set_defaults(service=None, docker_container=None, synthetic=False)
        if name == "database":
            conn = part.add_mutually_exclusive_group(required=True)
            conn.add_argument("--docker-container")
            conn.add_argument("--service")
            part.add_argument("--database", default="postgres")
        else:
            part.add_argument("--root", required=True)
            part.add_argument("--synthetic", action="store_true")
    args = parser.parse_args()
    try:
        production = bool(args.service or (args.command == "storage" and not args.synthetic))
        if production:
            if not args.project_ref or not args.approval_file:
                raise ValueError("production capture requires explicit project and approval record")
            approval(args, args.command + "_backup")
            if Path(args.output_dir).resolve().is_relative_to(Path(__file__).resolve().parents[2]):
                raise ValueError("production recovery files must be outside the repository")
            if args.service:
                validate_service(args)
        if not args.writes_frozen:
            raise ValueError("declare --writes-frozen after actually freezing the source")
        if args.command == "storage" and Path(args.output_dir).resolve().is_relative_to(Path(args.root).resolve()):
            raise ValueError("encrypted output directory must be outside the Storage source tree")
        Path(args.recipients).resolve(strict=True)
        Path(args.output_dir).mkdir(mode=0o700, parents=False, exist_ok=False)
        if args.command == "database":
            connection = ["-d", args.database] if args.docker_container else ["-d", f"service={args.service}"]
            version = subprocess.run(prefix(args, "pg_dump", auth=False) + ["--version"], capture_output=True,
                                     text=True, check=True, timeout=30).stdout
            if not re.search(r"\b17\.11\b", version):
                raise ValueError("pg_dump client must be PostgreSQL 17.11")
            encrypted_stream(prefix(args, "pg_dump") + connection +
                             ["--format=custom", "--lock-wait-timeout=5s"], args, "database.dump.age")
            roles_connection = ["-l", args.database] if args.docker_container else connection
            encrypted_stream(prefix(args, "pg_dumpall") + roles_connection +
                             ["--roles-only", "--no-role-passwords"], args, "roles-reference.sql.age")
            snap = [sys.executable, str(Path(__file__).with_name("snapshot.py")), "capture",
                    "--data-hashes", "--all-user-schemas", "--writes-frozen"]
            if args.docker_container:
                snap += ["--docker-container", args.docker_container, "--database", args.database]
            else:
                snap += ["--service", args.service, "--project-ref", args.project_ref,
                         "--approval-file", args.approval_file]
            encrypted_stream(snap, args, "catalog.json.age")
        else:
            # Validate paths before tar follows any names; manifest rejects links.
            import storage_manifest
            storage_manifest.manifest(args.root)
            encrypted_stream(["tar", "-cf", "-", "-C", str(Path(args.root).resolve()), "."],
                             args, "storage.tar.age")
            encrypted_stream([sys.executable, str(Path(__file__).with_name("storage_manifest.py")),
                              "capture", "--root", args.root], args, "storage-manifest.json.age")
        finish(args)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
