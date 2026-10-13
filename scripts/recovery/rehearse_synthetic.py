#!/usr/bin/env python3
"""Run recovery tooling against two NEW network-none PostgreSQL 17.11 clusters.

Creates synthetic fixtures and age identities under a new local work folder.
Preserves containers and test artifacts for investigation; no production API,
database service, private object, or paid resource is used.
"""

import argparse
import hashlib
import json
import re
import subprocess
import sys
import time
from pathlib import Path

IMAGE = "public.ecr.aws/supabase/postgres:17.11.0.002"
TOOLS = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--age-dir", required=True)
    parser.add_argument("--work-dir", required=True)
    parser.add_argument("--suffix", required=True)
    parser.add_argument("--reuse-containers", action="store_true",
                        help="reuse this script's isolated fixture after an early failed attempt")
    parser.add_argument("--database-tag", default="", help="fresh target database suffix for a rerun")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z0-9-]+", args.suffix):
        raise ValueError("invalid synthetic container suffix")
    if args.database_tag and not re.fullmatch(r"[a-z0-9_]+", args.database_tag):
        raise ValueError("invalid synthetic database tag")
    work = Path(args.work_dir).resolve()
    work.mkdir(parents=False, exist_ok=False)
    transcript = work / "raw-evidence.txt"
    age = str(Path(args.age_dir) / ("age.exe" if sys.platform == "win32" else "age"))
    keygen = str(Path(args.age_dir) / ("age-keygen.exe" if sys.platform == "win32" else "age-keygen"))
    source = "rad-recovery-src-" + args.suffix
    target = "rad-recovery-target-" + args.suffix
    tag = "_" + args.database_tag if args.database_tag else ""
    naive_db, safe_db = "rad_recovery_naive" + tag, "rad_recovery_safe" + tag

    def log(value):
        print(value, flush=True)
        with transcript.open("a", encoding="utf-8") as stream:
            stream.write(value + "\n")

    def run(label, command, expected=0, stdin=None, timeout=300):
        result = subprocess.run(command, input=stdin, text=True, capture_output=True, timeout=timeout)
        log(f"{label}: exit={result.returncode}, expected={expected}")
        # Only synthetic output. Secret identity generation stderr is never logged.
        if result.stdout.strip():
            log(result.stdout.strip())
        if result.stderr.strip() and label != "synthetic_age_identity":
            log(result.stderr.strip())
        if result.returncode != expected:
            raise RuntimeError(f"{label} failed; preserve {work}")
        return result

    def sql(container, database, statement, confirmed=False):
        cmd = ["docker", "exec", "-i"]
        if confirmed:
            cmd += ["-e", "PGOPTIONS=-c rad.recovery_target_confirmed=yes"]
        cmd += [container, "psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-U", "supabase_admin",
                "-d", database, "-f", "-"]
        return run(f"synthetic_sql_{database}", cmd, stdin=statement)

    results = {}
    try:
        log("Synthetic-only independent recovery rehearsal; no production connections")
        for name in (source, target):
            if not args.reuse_containers:
                run("create_network_none_" + name,
                    ["docker", "run", "--pull", "never", "-d", "--name", name, "--network", "none",
                     "-e", "POSTGRES_PASSWORD=synthetic-local-recovery-only", IMAGE])
            for _ in range(60):
                ready = subprocess.run(["docker", "exec", name, "pg_isready", "-U", "supabase_admin"],
                                       capture_output=True, timeout=5)
                if ready.returncode == 0:
                    break
                time.sleep(1)
            else:
                raise RuntimeError("synthetic PostgreSQL startup timed out")
            if run("verify_network_none", ["docker", "inspect", name, "--format", "{{.HostConfig.NetworkMode}}"] ).stdout.strip() != "none":
                raise ValueError("synthetic container must have network=none")
        neutral = (TOOLS / "neutralize_target_defaults.sql").read_text(encoding="utf-8")
        if not args.reuse_containers:
            sql(source, "postgres", "CREATE DATABASE rad_recovery_fixture;")
            sql(source, "rad_recovery_fixture", neutral, confirmed=True)
            sql(source, "rad_recovery_fixture", (TOOLS / "synthetic_fixture.sql").read_text(encoding="utf-8"))
        else:
            sql(source, "rad_recovery_fixture", "UPDATE storage.objects SET name='synthetic-owner/fixture.pdf',"
                "metadata='{\"size\":17}' WHERE id='00000000-0000-0000-0000-000000000002'; "
                "INSERT INTO storage.objects VALUES('00000000-0000-0000-0000-000000000003',"
                "'documents','empty.bin','{\"size\":0}') ON CONFLICT(id) DO NOTHING;")
        identity, recipients = work / "identity.txt", work / "recipients.txt"
        run("synthetic_age_identity", [keygen, "-o", str(identity)])
        recipient = run("synthetic_public_recipient", [keygen, "-y", str(identity)]).stdout.strip()
        recipients.write_text(recipient + "\n", encoding="ascii")
        run("encrypted_database_backup", [sys.executable, str(TOOLS / "encrypted_backup.py"), "database",
            "--docker-container", source, "--database", "rad_recovery_fixture", "--writes-frozen",
            "--age", age, "--recipients", str(recipients), "--output-dir", str(work / "database")])
        run("verify_database_ciphertext_bundle", [sys.executable, str(TOOLS / "verify_bundle.py"),
            "--root", str(work / "database")])
        for file, plain in (("database.dump.age", "database.dump"), ("catalog.json.age", "source.json")):
            run("decrypt_synthetic_" + plain, [age, "-d", "-i", str(identity), "-o", str(work / plain),
                                               str(work / "database" / file)])
        run("copy_synthetic_archive", ["docker", "cp", str(work / "database.dump"), target + ":/tmp/recovery.dump"])
        toc = run("inspect_synthetic_archive", ["docker", "exec", target, "pg_restore", "--list", "/tmp/recovery.dump"]).stdout
        # The existing public schema is explicitly retained on both new targets.
        toc = "\n".join(line for line in toc.splitlines() if " SCHEMA - public " not in line) + "\n"
        (work / "toc.list").write_text(toc, encoding="utf-8")
        run("copy_reviewed_synthetic_toc", ["docker", "cp", str(work / "toc.list"), target + ":/tmp/toc.list"])
        sql(target, "postgres", f"CREATE DATABASE {naive_db}; CREATE DATABASE {safe_db};")
        sql(target, naive_db, "ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public "
            "GRANT ALL ON TABLES TO anon,authenticated,service_role; "
            "ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public "
            "GRANT EXECUTE ON FUNCTIONS TO anon,authenticated,service_role;")
        # Confirmation guard must reject a target-default mutation without a marker.
        run("target_confirmation_denial", ["docker", "exec", "-i", target, "psql", "-X", "-q", "-v",
            "ON_ERROR_STOP=1", "-U", "supabase_admin", "-d", safe_db, "-f", "-"],
            expected=3, stdin=neutral)
        sql(target, safe_db, neutral, confirmed=True)
        for db, expected in ((naive_db, 1), (safe_db, 0)):
            run("restore_" + db, ["docker", "exec", target, "pg_restore", "-U", "supabase_admin",
                "--exit-on-error", "--single-transaction", "--use-list=/tmp/toc.list", "-d", db, "/tmp/recovery.dump"])
            snapshot = work / (db + ".json")
            run("capture_" + db, [sys.executable, str(TOOLS / "snapshot.py"), "capture", "--docker-container", target,
                "--database", db, "--data-hashes", "--all-user-schemas", "--writes-frozen", "--output", str(snapshot)])
            run("compare_" + db, [sys.executable, str(TOOLS / "snapshot.py"), "compare", "--source",
                str(work / "source.json"), "--target", str(snapshot)], expected=expected)
        sql(target, safe_db, "UPDATE public.consultation_requests SET message='tampered synthetic'; "
            "SELECT setval('public.consultation_requests_id_seq',99,true);")
        run("capture_mutated_data_and_sequence", [sys.executable, str(TOOLS / "snapshot.py"), "capture",
            "--docker-container", target, "--database", safe_db, "--data-hashes", "--all-user-schemas",
            "--writes-frozen", "--output", str(work / "mutated.json")])
        run("detect_mutated_data_and_sequence", [sys.executable, str(TOOLS / "snapshot.py"), "compare",
            "--source", str(work / "source.json"), "--target", str(work / "mutated.json")], expected=1)
        sql(target, safe_db, "UPDATE public.consultation_requests SET message='Synthetic only'; "
            "SELECT setval('public.consultation_requests_id_seq',1,true);")
        run("capture_repaired_synthetic_fixture", [sys.executable, str(TOOLS / "snapshot.py"), "capture",
            "--docker-container", target, "--database", safe_db, "--data-hashes", "--all-user-schemas",
            "--writes-frozen", "--output", str(work / "final-restore.json")])
        run("compare_final_restored_fixture", [sys.executable, str(TOOLS / "snapshot.py"), "compare",
            "--source", str(work / "source.json"), "--target", str(work / "final-restore.json")])
        source_snapshot = json.loads((work / "source.json").read_text(encoding="utf-8"))
        results["source_tables_hashed"] = len(source_snapshot["data_hashes"])
        results["source_rows_hashed"] = sum(v["rows"] for v in source_snapshot["data_hashes"].values())
        results["effective_privilege_entries"] = sum(len(v) for k, v in source_snapshot.items() if k.startswith("effective_"))
        objects = work / "storage-source"
        (objects / "documents" / "synthetic-owner").mkdir(parents=True)
        (objects / "documents" / "synthetic-owner" / "fixture.pdf").write_bytes(b"%PDF-synthetic\x00\xff\n")
        (objects / "documents" / "empty.bin").write_bytes(b"")
        run("encrypted_storage_backup", [sys.executable, str(TOOLS / "encrypted_backup.py"), "storage",
            "--synthetic", "--root", str(objects), "--writes-frozen", "--age", age,
            "--recipients", str(recipients), "--output-dir", str(work / "storage")])
        run("verify_storage_ciphertext_bundle", [sys.executable, str(TOOLS / "verify_bundle.py"),
            "--root", str(work / "storage")])
        run("decrypt_storage_tar", [age, "-d", "-i", str(identity), "-o", str(work / "storage.tar"),
                                    str(work / "storage" / "storage.tar.age")])
        run("decrypt_storage_manifest", [age, "-d", "-i", str(identity), "-o", str(work / "storage-source.json"),
                                         str(work / "storage" / "storage-manifest.json.age")])
        restored = work / "storage-restored"
        restored.mkdir()
        run("extract_synthetic_storage", ["tar", "-xf", str(work / "storage.tar"), "-C", str(restored)])
        run("hash_restored_storage", [sys.executable, str(TOOLS / "storage_manifest.py"), "capture",
            "--root", str(restored), "--output", str(work / "storage-restored.json")])
        run("compare_storage_bytes", [sys.executable, str(TOOLS / "storage_manifest.py"), "compare",
            "--source", str(work / "storage-source.json"), "--target", str(work / "storage-restored.json")])
        run("reconcile_storage_database_inventory", [sys.executable, str(TOOLS / "storage_manifest.py"), "reconcile",
            "--database-snapshot", str(work / "source.json"), "--storage-manifest", str(work / "storage-source.json")])
        damaged = bytearray((work / "storage" / "storage.tar.age").read_bytes())
        damaged[-1] ^= 1
        (work / "tampered.age").write_bytes(damaged)
        run("age_tamper_rejection", [age, "-d", "-i", str(identity), "-o", str(work / "tampered-output"),
                                     str(work / "tampered.age")], expected=1)
        results.update(status="PASS", naive_restore_overgrant_detected=True, hardened_restore_parity=True,
                       encrypted_storage_bytes_match=True, ciphertext_tamper_rejected=True,
                       data_and_sequence_mutation_detected=True,
                       storage_database_inventory_matches_bytes=True,
                       source_container=source, target_container=target)
        (work / "summary.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        log(json.dumps(results, indent=2))
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as exc:
        log("FAIL: " + str(exc))
        return 1


if __name__ == "__main__":
    sys.exit(main())
