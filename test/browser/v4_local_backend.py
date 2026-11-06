"""Create only the dedicated, marked V4 loopback Supabase acceptance stack.

Existing contributor stacks and hosted projects are never modified. Runtime
accounts and CLI output remain in the ignored, protected runtime directory.
"""

import argparse
import hashlib
import json
import secrets
import shutil
import socket
import subprocess
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = "rad_full_content_v4_20261028"
PORT = 64522
ACTOR = "0166163b-582b-4d2e-82dc-f9942c2f80b5"


def protect(file):
    sid = (
        subprocess.check_output(["whoami", "/user", "/fo", "csv", "/nh"], text=True)
        .strip()
        .split(",")[-1]
        .strip('"')
    )
    subprocess.run(
        ["icacls", str(file), "/inheritance:r", "/grant:r", "*" + sid + ":(F)"],
        check=True,
        capture_output=True,
    )


def prepare(runtime):
    expected = {"project": PROJECT, "source": str(ROOT), "port": PORT}
    marker = runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json"
    if runtime.exists() and (
        not marker.exists() or json.loads(marker.read_text()) != expected
    ):
        raise ValueError("refuse_unmarked_or_different_runtime")
    runtime.mkdir(parents=True, exist_ok=True)
    (runtime / ".gitignore").write_text("*\n", encoding="utf-8")
    marker.write_text(json.dumps(expected), encoding="utf-8")
    folder = runtime / "supabase"
    (folder / "migrations").mkdir(parents=True, exist_ok=True)
    config = f'''project_id = "{PROJECT}"
[api]
port = 64521
[db]
port = {PORT}
shadow_port = 64520
major_version = 17
[db.seed]
enabled = false
[studio]
port = 64523
[inbucket]
port = 64524
smtp_port = 64525
pop3_port = 64526
[auth]
site_url = "http://127.0.0.1:64332"
additional_redirect_urls = ["http://127.0.0.1:64332/reset-password"]
'''
    (folder / "config.toml").write_text(config, encoding="utf-8")
    manifest = {}
    for source in sorted((ROOT / "supabase/migrations").glob("*.sql")):
        target = folder / "migrations" / source.name
        if target.exists() and target.read_bytes() != source.read_bytes():
            raise ValueError("runtime_migration_changed_after_capture:" + source.name)
        shutil.copyfile(source, target)
        manifest[source.name] = hashlib.sha256(source.read_bytes()).hexdigest()
    (runtime / "migration-capture.json").write_text(
        json.dumps(manifest, indent=2), encoding="utf-8"
    )
    return expected


def start(runtime, cli):
    containers = subprocess.check_output(
        ["docker", "ps", "--format", "{{.Names}}"], text=True
    ).splitlines()
    if "supabase_db_" + PROJECT not in containers:
        for port in range(64520, 64527):
            with socket.socket() as test:
                try:
                    test.bind(("127.0.0.1", port))
                except OSError as error:
                    raise ValueError(
                        "dedicated_port_already_in_use:" + str(port)
                    ) from error
    logfile = runtime / "supabase-start.private.log"
    with logfile.open("wb") as stream:
        result = subprocess.run(
            [
                str(cli),
                "--workdir",
                str(runtime),
                "start",
                "--exclude",
                "realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor",
            ],
            stdout=stream,
            stderr=subprocess.STDOUT,
            check=False,
        )
    protect(logfile)
    if result.returncode:
        raise RuntimeError("isolated_start_failed; see protected local log")


def initialize(runtime, cli):
    result = subprocess.run(
        [str(cli), "--workdir", str(runtime), "status", "--output", "json"],
        capture_output=True,
        text=True,
        check=True,
    )
    status = json.loads(result.stdout)
    api = status.get("API_URL") or status.get("api_url")
    anon = status.get("ANON_KEY") or status.get("anon_key")
    service = status.get("SERVICE_ROLE_KEY") or status.get("service_role_key")
    if api != "http://127.0.0.1:64521" or not anon or not service:
        raise ValueError("exact_V4_loopback_status_required")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def request(method, path, payload):
        req = urllib.request.Request(
            api + path,
            data=json.dumps(payload).encode(),
            method=method,
            headers={
                "apikey": service,
                "Authorization": "Bearer " + service,
                "Content-Type": "application/json",
            },
        )
        try:
            with opener.open(req, timeout=30) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            raise RuntimeError("local_fixture_API_status:" + str(error.code)) from None

    account_file = runtime / "qa-accounts.private.json"
    if account_file.exists():
        data = json.loads(account_file.read_text())
        if data.get("project") != PROJECT or data.get("api_url") != api:
            raise ValueError("fixture_account_target_changed")
    else:
        accounts = []
        for role in ["user_a", "super_admin"]:
            email = f"qa-v4-{role}-{uuid.uuid4().hex}@example.invalid"
            password = secrets.token_urlsafe(32)
            user = request(
                "POST",
                "/auth/v1/admin/users",
                {
                    "email": email,
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {"full_name": "SYNTHETIC V4 QA " + role},
                },
            )
            request(
                "PATCH",
                "/rest/v1/profiles?id=eq." + user["id"],
                {
                    "role": "user" if role == "user_a" else role,
                    "full_name": "SYNTHETIC V4 QA " + role,
                },
            )
            accounts.append(
                {"id": user["id"], "role": role, "email": email, "password": password}
            )
        data = {
            "project": PROJECT,
            "api_url": api,
            "accounts": accounts,
            "scope": "generated local-only synthetic GoTrue identities; no hosted accounts",
        }
        account_file.write_text(json.dumps(data), encoding="utf-8")
    protect(account_file)
    sql = f"""begin;
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values('{ACTOR}','00000000-0000-0000-0000-000000000000','authenticated','authenticated','qa-v4-import-attribution@example.invalid','{{}}','{{"full_name":"SYNTHETIC V4 import attribution"}}',now(),now()) on conflict(id) do nothing;
update public.profiles set role='super_admin' where id='{ACTOR}';
commit;"""
    subprocess.run(
        [
            "docker",
            "exec",
            "supabase_db_" + PROJECT,
            "psql",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-X",
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            sql,
        ],
        capture_output=True,
        check=True,
    )
    (runtime / "flutter-public.json").write_text(
        json.dumps(
            {"SUPABASE_URL": api, "SUPABASE_ANON_KEY": anon, "APP_ENV": "development"}
        ),
        encoding="utf-8",
    )
    receipt = {
        "project": PROJECT,
        "api_url": api,
        "db_port": PORT,
        "import_actor": ACTOR,
        "super_admin_id": next(
            row["id"] for row in data["accounts"] if row["role"] == "super_admin"
        ),
        "marker": str(runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json"),
        "hosted_operations": 0,
        "existing_stacks_modified": 0,
    }
    (runtime / "readiness.json").write_text(
        json.dumps(receipt, indent=2), encoding="utf-8"
    )
    print(json.dumps(receipt))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", required=True, type=Path)
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    runtime_path = args.runtime.resolve()
    if runtime_path != ROOT / "_scratch/v4-runtime":
        raise ValueError("only_owned_worktree_runtime_supported")
    prepare(runtime_path)
    start(runtime_path, args.cli)
    initialize(runtime_path, args.cli)
