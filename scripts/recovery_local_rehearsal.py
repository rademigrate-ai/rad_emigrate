"""Explicit synthetic encrypted backup/restore rehearsal on a new local cluster.

Never connects to Supabase or an existing cluster. Does not establish Production
recoverability, real Auth acceptance, managed-schema compatibility or key portability.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import queue
import shutil
import subprocess
import sys
import threading
from datetime import UTC, datetime
from pathlib import Path

from scripts.recovery_checkpoint import checked_export, verify_files

PORT = 64940
SEED = """
CREATE SCHEMA auth; CREATE SCHEMA storage; CREATE SCHEMA supabase_migrations;
CREATE TABLE auth.users(id uuid primary key, encrypted_password text, created_at timestamptz);
CREATE TABLE auth.identities(id uuid primary key, user_id uuid references auth.users, provider text);
CREATE TABLE public.profiles(id uuid primary key references auth.users, role text);
CREATE TABLE public.source_documents(id uuid primary key, validation_status text);
CREATE TABLE public.heads(article_id uuid primary key, head_id uuid, published_id uuid, created_by uuid references auth.users);
CREATE TABLE storage.objects(bucket_id text, name text, owner uuid references auth.users, metadata jsonb, primary key(bucket_id,name));
CREATE TABLE supabase_migrations.schema_migrations(version text primary key);
INSERT INTO auth.users VALUES ('91000000-0000-4000-8000-000000000001','SYNTHETIC_HASH_NOT_A_CREDENTIAL',now());
INSERT INTO auth.identities VALUES ('91000000-0000-4000-8000-000000000002','91000000-0000-4000-8000-000000000001','synthetic');
INSERT INTO public.profiles VALUES ('91000000-0000-4000-8000-000000000001','admin');
INSERT INTO public.source_documents VALUES ('91000000-0000-4000-8000-000000000003',NULL);
INSERT INTO public.heads VALUES ('91000000-0000-4000-8000-000000000004','91000000-0000-4000-8000-000000000005',NULL,'91000000-0000-4000-8000-000000000001');
INSERT INTO storage.objects VALUES ('private','sample','91000000-0000-4000-8000-000000000001','{"size":17}'),('private','empty','91000000-0000-4000-8000-000000000001','{"size":0}');
INSERT INTO supabase_migrations.schema_migrations VALUES ('synthetic-001');
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_profile ON public.profiles USING(id = nullif(current_setting('rad.synthetic_uid',true),'')::uuid);
"""
TABLES = [
    "auth.users",
    "auth.identities",
    "public.profiles",
    "public.source_documents",
    "public.heads",
    "storage.objects",
    "supabase_migrations.schema_migrations",
]


def finalize_shutdown(receipt, exit_code):
    receipt["owned_cluster_stopped"] = exit_code == 0
    if exit_code:
        receipt["status"] = "FAILED_OWNED_CLUSTER_SHUTDOWN"
        raise RuntimeError("owned_cluster_shutdown_failed")


def bounded_snapshot_line(stream, timeout=15):
    results = queue.Queue(maxsize=1)

    def read():
        try:
            results.put(stream.readline())
        except (OSError, ValueError):
            results.put("")

    threading.Thread(target=read, daemon=True).start()
    try:
        return results.get(timeout=timeout).strip()
    except queue.Empty as exc:
        raise RuntimeError("snapshot_export_timeout") from exc


def rehearse(output, pg_bin, gpg):
    output = Path(output).resolve()
    if output.exists():
        raise ValueError("new_owned_output_required")
    output.mkdir(parents=True)
    data = output / "postgres-data"
    keyhome = output / "synthetic-key-home"
    keyhome.mkdir()
    env = {
        k: v
        for k, v in os.environ.items()
        if not k.upper().startswith("PG") and k.upper() != "GNUPGHOME"
    }
    env.update(
        PGHOSTADDR="127.0.0.1",
        PGCONNECT_TIMEOUT="5",
        PGCLIENTENCODING="UTF8",
        GNUPGHOME=str(keyhome),
    )
    hidden = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    marker = {
        "scope": "SYNTHETIC_LOCAL_ONLY_NOT_PRODUCTION_RECOVERY",
        "port": PORT,
        "data": str(data),
        "created_at": datetime.now(UTC).isoformat(),
    }
    (output / "OWNED_LOCAL_CLUSTER.json").write_text(
        json.dumps(marker, indent=2) + "\n", "utf8"
    )

    def run(command, content=None):
        result = subprocess.run(
            command,
            input=content,
            text=True,
            encoding="utf8",
            capture_output=True,
            env=env,
            creationflags=hidden,
            timeout=120,
        )
        if result.returncode:
            raise RuntimeError(result.stderr[-2000:])
        return result.stdout.strip()

    def pg(name, *args):
        return [str(pg_bin / (name + (".exe" if os.name == "nt" else ""))), *args]

    def connection(database):
        if database not in (
            "postgres",
            "rad_recovery_fixture_source",
            "rad_recovery_fixture_restore",
        ):
            raise ValueError("owned_fixture_database_only")
        return ["-h", "127.0.0.1", "-p", str(PORT), "-U", "postgres", "-d", database]

    def sql(database, command):
        return run(
            pg("psql", "-XqAtw", "-v", "ON_ERROR_STOP=1", *connection(database)),
            command,
        )

    def fingerprint(database):
        result = {}
        for table in TABLES:
            result[table] = sql(
                database,
                "SELECT md5(coalesce(string_agg(to_jsonb(t)::text,'|' ORDER BY to_jsonb(t)::text),'')) FROM "
                + table
                + " t;",
            )
        result["fk_count"] = sql(
            database,
            "SELECT count(*) FROM pg_constraint WHERE contype='f' AND convalidated;",
        )
        result["rls"] = sql(
            database,
            "SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass;",
        )
        result["policy"] = sql(
            database,
            "SELECT qual FROM pg_policies WHERE schemaname='public' AND tablename='profiles';",
        )
        return result

    def decrypt_restore(artifact, database):
        decoder = subprocess.Popen(
            [str(gpg), "--batch", "--no-auto-key-retrieve", "--decrypt", str(artifact)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=env,
            creationflags=hidden,
        )
        try:
            result = subprocess.run(
                pg(
                    "pg_restore",
                    "--exit-on-error",
                    "--single-transaction",
                    "--no-password",
                    *connection(database),
                ),
                stdin=decoder.stdout,
                capture_output=True,
                env=env,
                timeout=120,
                creationflags=hidden,
            )
            decoder.stdout.close()
            code = decoder.wait(timeout=15)
            if code or result.returncode:
                raise RuntimeError("decrypt_or_restore_failed")
        finally:
            if decoder.poll() is None:
                decoder.kill()
                decoder.wait()

    started = False
    holder = None
    receipt = marker | {
        "status": "INCOMPLETE",
        "hosted_operations_executed": 0,
        "paid_calls": 0,
        "real_auth_acceptance": False,
        "production_backup_proof": False,
    }
    try:
        run(
            pg(
                "initdb",
                "-D",
                str(data),
                "-U",
                "postgres",
                "-A",
                "trust",
                "--no-locale",
                "-E",
                "UTF8",
            )
        )
        # File redirection avoids inherited Windows pipes keeping pg_ctl alive.
        # A timeout may occur after a server has detached; attempt cleanup of
        # this exact owned data directory even if pg_ctl never returns.
        started = True
        with (output / "pgctl.log").open("a", encoding="utf8") as log:
            result = subprocess.run(
                pg(
                    "pg_ctl",
                    "-D",
                    str(data),
                    "-l",
                    str(output / "postgres.log"),
                    "-o",
                    f"-h 127.0.0.1 -p {PORT} -c max_connections=10",
                    "-w",
                    "start",
                ),
                stdout=log,
                stderr=log,
                env=env,
                creationflags=hidden,
                timeout=45,
            )
        if result.returncode:
            raise RuntimeError("owned_cluster_start_failed")
        sql("postgres", "CREATE DATABASE rad_recovery_fixture_source;")
        sql("postgres", "CREATE DATABASE rad_recovery_fixture_restore;")
        sql("rad_recovery_fixture_source", SEED)
        before = fingerprint("rad_recovery_fixture_source")
        run(
            [
                str(gpg),
                "--batch",
                "--pinentry-mode",
                "loopback",
                "--passphrase",
                "",
                "--quick-generate-key",
                "RAD Synthetic Recovery <synthetic@example.invalid>",
                "rsa2048",
                "encr",
                "1d",
            ]
        )
        keys = run([str(gpg), "--batch", "--with-colons", "--list-keys"])
        fingerprint_key = next(
            line.split(":")[9] for line in keys.splitlines() if line.startswith("fpr:")
        )
        encrypt = [
            str(gpg),
            "--batch",
            "--no-auto-key-retrieve",
            "--trust-model",
            "always",
            "--recipient",
            fingerprint_key,
            "--encrypt",
        ]
        holder = subprocess.Popen(
            pg(
                "psql",
                "-XqAtw",
                "-v",
                "ON_ERROR_STOP=1",
                *connection("rad_recovery_fixture_source"),
            ),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            encoding="utf8",
            env=env,
            creationflags=hidden,
        )
        holder.stdin.write(
            "BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY; SELECT pg_export_snapshot();\n"
        )
        holder.stdin.flush()
        snapshot = bounded_snapshot_line(holder.stdout)
        if not snapshot or "-" not in snapshot:
            raise RuntimeError("snapshot_holder_failed")
        artifact = output / "database.dump.gpg"
        manifest = {
            artifact.name: checked_export(
                pg(
                    "pg_dump",
                    "--format=custom",
                    "--no-password",
                    "--snapshot=" + snapshot,
                    *connection("rad_recovery_fixture_source"),
                ),
                encrypt,
                artifact,
                env,
            )
        }
        holder.stdin.write("ROLLBACK;\n\\q\n")
        holder.stdin.flush()
        holder.wait(timeout=15)
        holder.stdin.close()
        holder.stdout.close()
        holder = None
        # Synthetic object bytes are intentionally small; real backups stream all
        # paginated API objects to encryption and never use this fixture path.
        objects = {"private/sample": b"synthetic storage", "private/empty": b""}
        for index, (_, content) in enumerate(objects.items()):
            path = output / f"storage-{index}.gpg"
            producer = [
                sys.executable,
                "-c",
                "import sys;sys.stdout.buffer.write(" + repr(content) + ")",
            ]
            manifest[path.name] = checked_export(producer, encrypt, path, env)
        verify_files(output, manifest)
        decrypt_restore(artifact, "rad_recovery_fixture_restore")
        after = fingerprint("rad_recovery_fixture_restore")
        if before != after:
            raise RuntimeError("restored_row_acl_fk_mismatch")
        byte_hashes = {}
        for index, (name, content) in enumerate(objects.items()):
            decrypted = subprocess.run(
                [
                    str(gpg),
                    "--batch",
                    "--decrypt",
                    str(output / f"storage-{index}.gpg"),
                ],
                capture_output=True,
                env=env,
                timeout=30,
                creationflags=hidden,
            )
            if decrypted.returncode or decrypted.stdout != content:
                raise RuntimeError("restored_storage_bytes_mismatch")
            byte_hashes[name] = hashlib.sha256(content).hexdigest()
        fk = subprocess.run(
            pg(
                "psql",
                "-XqAtw",
                "-v",
                "ON_ERROR_STOP=1",
                *connection("rad_recovery_fixture_restore"),
            ),
            input="INSERT INTO public.profiles VALUES ('91000000-0000-4000-8000-000000000099','user');",
            text=True,
            capture_output=True,
            env=env,
            creationflags=hidden,
            timeout=30,
        )
        if fk.returncode == 0 or "foreign key" not in fk.stderr:
            raise RuntimeError("restored_fk_not_enforced")
        receipt.update(
            status="PASS_SYNTHETIC_ONLY",
            encrypted_artifacts=manifest,
            before=before,
            after=after,
            storage_byte_hashes=byte_hashes,
            restored_foreign_key_rejects_orphan=True,
            encryption_fingerprint=fingerprint_key,
            same_exported_snapshot=True,
        )
    finally:
        if holder is not None:
            holder.kill()
            holder.wait()
            holder.stdin.close()
            holder.stdout.close()
        if started:
            try:
                stop_code = -1
                try:
                    with (output / "pgctl.log").open("a", encoding="utf8") as log:
                        stopped = subprocess.run(
                            pg("pg_ctl", "-D", str(data), "-m", "fast", "-w", "stop"),
                            stdout=log,
                            stderr=log,
                            env=env,
                            creationflags=hidden,
                            timeout=45,
                        )
                    stop_code = stopped.returncode
                except (OSError, subprocess.TimeoutExpired):
                    receipt["shutdown_error"] = (
                        "local_shutdown_process_failed_or_timed_out"
                    )
                finalize_shutdown(receipt, stop_code)
            finally:
                (output / "rehearsal-receipt.json").write_text(
                    json.dumps(receipt, indent=2) + "\n", "utf8"
                )
        else:
            (output / "rehearsal-receipt.json").write_text(
                json.dumps(receipt, indent=2) + "\n", "utf8"
            )
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--pg-bin", type=Path, default=Path(r"C:\Program Files\PostgreSQL\17\bin")
    )
    parser.add_argument(
        "--gpg",
        type=Path,
        default=Path(shutil.which("gpg") or r"C:\Program Files\GnuPG\bin\gpg.exe"),
    )
    args = parser.parse_args()
    print(json.dumps(rehearse(args.output, args.pg_bin, args.gpg)))


if __name__ == "__main__":
    main()
