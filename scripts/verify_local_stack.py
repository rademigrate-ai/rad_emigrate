#!/usr/bin/env python3
"""Windows/Unix local Supabase acceptance runner; never links to a hosted project.

Requires an installed Supabase CLI, Docker, and psql. Runtime files and local
credentials stay outside the checkout. Does not reset another writer's stack.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "rad_codex_local47"
PORT = 55322


def safe_output(value: str) -> str:
    value = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[REDACTED_JWT]", value)
    value = re.sub(r"sb_(?:secret|publishable)_[A-Za-z0-9_-]+", "[REDACTED_KEY]", value)
    value = re.sub(r"(?im)^.*(?:anon key|service.role key|secret key|publishable key|s3 access|s3 secret).*$", "[REDACTED_LOCAL_KEY]", value)
    return value


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("start", "verify", "apply", "stop"))
    parser.add_argument("--supabase", default=shutil.which("supabase"))
    parser.add_argument("--psql", default=shutil.which("psql"))
    parser.add_argument("--lineage", choices=("canonical", "historical"), default="canonical")
    parser.add_argument("--runtime", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--proposal", type=Path)
    args = parser.parse_args()
    if not args.supabase or not Path(args.supabase).is_file():
        parser.error("--supabase must name an installed native CLI executable")
    project = PROJECT if args.lineage == "canonical" else PROJECT + "_reconstruct"
    port = PORT if args.lineage == "canonical" else 57322
    runtime_name = project if args.lineage == "canonical" else f"{project}_{port}"
    runtime = (args.runtime or Path(tempfile.gettempdir()) / runtime_name).resolve()
    if runtime == ROOT or ROOT in runtime.parents:
        parser.error("runtime must be outside the source checkout")
    marker = runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json"
    identity = {"project": project, "source": str(ROOT), "port": port}
    if marker.exists():
        if json.loads(marker.read_text()) != identity:
            parser.error("refusing a runtime owned by another checkout")
    elif runtime.exists() and any(runtime.iterdir()):
        parser.error("refusing a nonempty unmarked runtime")
    elif args.operation != "start":
        parser.error("start the dedicated runtime first")
    runtime.mkdir(parents=True, exist_ok=True)
    marker.write_text(json.dumps(identity), encoding="utf-8")
    env = os.environ.copy()
    env["PATH"] = str(Path(args.supabase).parent) + os.pathsep + env["PATH"]
    if args.psql:
        env["PATH"] = str(Path(args.psql).parent) + os.pathsep + env["PATH"]
    env["PGPASSWORD"] = "postgres"  # public disposable-stack default only
    env["PYTHONIOENCODING"] = "utf-8"
    results: list[dict[str, object]] = []

    def run(label: str, command: list[str], cwd: Path = runtime, include_stderr: bool = False) -> str:
        print(f"START {label}", flush=True)
        result = subprocess.run(command, cwd=cwd, env=env, text=True, encoding="utf-8", errors="replace", capture_output=True, timeout=1800)
        results.append({"check": label, "exit_code": result.returncode})
        if result.returncode:
            print(safe_output((result.stdout + "\n" + result.stderr)[-14000:]), flush=True)
            raise RuntimeError(f"{label} failed (exit {result.returncode})")
        print(f"PASS {label}", flush=True)
        return result.stdout + ("\n" + result.stderr if include_stderr else "")

    cli = [str(Path(args.supabase).resolve()), "--workdir", str(runtime)]
    report: dict[str, object] = {"project": project, "lineage": args.lineage, "production_mutations": False, "started_at": datetime.now(timezone.utc).isoformat()}
    try:
        if args.operation == "stop":
            run("stop owned disposable stack", [*cli, "stop", "--no-backup"])
            # Forward-application proof belongs to the destroyed database, not
            # its next incarnation. Clear only this marked runtime's proof.
            (runtime / "RAD_FORWARD_REPLAY.json").unlink(missing_ok=True)
            report["status"] = "PASS"
            return
        if args.operation == "start":
            target = runtime / "supabase"
            target.mkdir(exist_ok=True)
            config = f'''project_id = "{project}"
[api]
port = {port-1}
[db]
port = {port}
shadow_port = {port-2}
major_version = 17
[studio]
port = {port+1}
[inbucket]
port = {port+2}
smtp_port = {port+3}
pop3_port = {port+4}
[auth]
site_url = "http://127.0.0.1:{port-1}"
additional_redirect_urls = ["http://127.0.0.1:{port-1}/reset-password"]
'''
            existing = target / "config.toml"
            if existing.exists() and existing.read_text() != config:
                raise RuntimeError("owned runtime config changed; inspect before proceeding")
            existing.write_text(config, encoding="utf-8")
            migrations = target / "migrations"
            migrations.mkdir(exist_ok=True)
            hashes = {}
            source_folder = ROOT / ("supabase/migrations" if args.lineage == "canonical" else "supabase/reconciliation/candidate")
            for source in sorted(source_folder.glob("*.sql")):
                # Match Git's canonical SQL bytes and Linux CI. PostgreSQL
                # preserves CRLF in function bodies, which otherwise changes
                # the pinned function fingerprint on a Windows checkout.
                data = source.read_bytes().replace(b"\r\n", b"\n")
                if not data.strip():
                    continue  # an unimplemented local proposal is not a migration
                destination = migrations / source.name
                if destination.exists() and destination.read_bytes().replace(b"\r\n", b"\n") != data:
                    raise RuntimeError(f"refusing to rewrite an already-copied migration: {source.name}")
                destination.write_bytes(data)
                hashes[source.name] = hashlib.sha256(data).hexdigest()
            report["migration_sha256"] = hashes
            run("local Supabase startup and migration replay", [*cli, "start", "--exclude", "studio,postgres-meta,realtime,imgproxy,edge-runtime,logflare,vector,supavisor"])
        else:
            if not args.psql:
                parser.error("verification requires --psql")
            db_args = [str(Path(args.psql).resolve()), "-X", "-v", "ON_ERROR_STOP=1", "-h", "127.0.0.1", "-p", str(port), "-U", "postgres", "-d", "postgres"]
            if args.operation == "apply":
                if not args.proposal or args.proposal.resolve().parent != ROOT / "supabase/migrations":
                    parser.error("--proposal must be one local migration in this checkout")
                run("apply local-only SQL proposal", [*db_args, "-f", str(args.proposal.resolve())], ROOT)
                report["status"] = "PASS"
                return
            if args.lineage == "historical":
                applied_marker = runtime / "RAD_FORWARD_REPLAY.json"
                candidates = {p.name for p in (ROOT / "supabase/reconciliation/candidate").glob("*.sql")}
                forward = [p for p in sorted((ROOT / "supabase/migrations").glob("*.sql")) if p.name not in candidates and p.read_bytes().strip()]
                forward_hashes = {p.name: hashlib.sha256(p.read_bytes().replace(b"\r\n", b"\n")).hexdigest() for p in forward}
                if applied_marker.exists():
                    if json.loads(applied_marker.read_text()) != forward_hashes:
                        raise RuntimeError("forward SQL changed after replay; rebuild only this marked disposable stack")
                else:
                    actual = json.loads(run("historical metadata capture", [*db_args, "-At", "-f", str(ROOT / "supabase/reconciliation/catalog_fingerprint.sql")]))
                    expected_history = json.loads((ROOT / "supabase/reconciliation/production_history.json").read_text())
                    if sorted(actual["history"], key=lambda row: row["version"]) != expected_history:
                        raise AssertionError("authoritative historical ledger mismatch")
                    captured = runtime / "reconstructed-catalog.json"
                    captured.write_text(json.dumps(actual), encoding="utf-8")
                    run("historical captured catalog equivalence", [sys.executable, str(ROOT / "scripts/compare_reconciliation_catalog.py"), str(captured)])
                    db_url = f"postgresql://postgres:postgres@127.0.0.1:{port}/postgres"
                    dry_run = run("historical CLI no-pending dry run", [*cli, "db", "push", "--db-url", db_url, "--dry-run"], include_stderr=True)
                    if "up to date" not in dry_run.lower():
                        raise AssertionError("historical dry run did not confirm up-to-date lineage")
                    normalized = runtime / "forward_sql"
                    normalized.mkdir(exist_ok=True)
                    command = [*db_args]
                    for source in forward:
                        target = normalized / source.name
                        target.write_bytes(source.read_bytes().replace(b"\r\n", b"\n"))
                        command += ["-f", str(target)]
                    run("ordered forward proposal reconstruction", command)
                    applied_marker.write_text(json.dumps(forward_hashes), encoding="utf-8")
                report["historical_versions"] = len(candidates)
                report["forward_sql_files"] = len(forward)
                # This proves a synthetic reconstruction only, not the unresolved
                # 47-entry live SQL/content lineage or a Production restore.
            fingerprint = json.loads(run("clean-schema pinned fingerprint", [*db_args, "-At", "-f", str(ROOT / "supabase/bootstrap/schema_fingerprint.sql")]))
            script = (ROOT / "scripts/verify_clean_schema.sh").read_text(encoding="utf-8")
            expected = json.loads(re.search(r"expected_fingerprint='([^']+)'", script).group(1))
            if fingerprint != expected:
                raise AssertionError(f"pinned fingerprint mismatch: {fingerprint}")
            report["fingerprint"] = fingerprint
            for sql in [
                "supabase/reconciliation/security_regression.sql",
                "supabase/tests/phase_a_constraint_backfill.sql",
                "supabase/tests/phase_a_security.sql",
                "supabase/tests/ai_entitlement_rpc_privacy.sql",
                "supabase/tests/corrective_routing_research.sql",
                "supabase/tests/stage2_knowledge_completion.sql",
                "supabase/tests/stage4_user_ai.sql",
                "supabase/tests/local47_crm_notifications.sql",
                "supabase/tests/local47_payment_sandbox.sql",
                "supabase/tests/local47_definer_acl.sql",
                "supabase/tests/local47_document_processing.sql",
            ]:
                if not (ROOT / sql).exists():
                    continue
                command = [*db_args]
                if "constraint_backfill" in sql:
                    command += ["-v", "phase_a_migration=" + str(ROOT / "supabase/migrations/20261012230000_ai_models_check_constraints_alignment.sql")]
                run(sql, [*command, "-f", str(ROOT / sql)], ROOT)
            run("two-user Auth RLS Storage quotas and human Feed", [sys.executable, str(ROOT / "scripts/verify_local_auth_isolation.py")])
            catalog = run("final metadata-only catalog capture", [*db_args, "-At", "-f", str(ROOT / "supabase/reconciliation/catalog_fingerprint.sql")])
            (runtime / "final-catalog.json").write_text(catalog, encoding="utf-8")
            report["final_catalog_sha256"] = hashlib.sha256(catalog.encode()).hexdigest()
        report["status"] = "PASS"
    except Exception as error:
        report["status"] = "FAIL"
        report["error"] = safe_output(str(error))
        raise
    finally:
        report["checks"] = results
        report["finished_at"] = datetime.now(timezone.utc).isoformat()
        report["source_head"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        report["source_dirty"] = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip())
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({k: v for k, v in report.items() if k != "migration_sha256"}, indent=2), flush=True)


if __name__ == "__main__":
    main()
