"""Explicit local HTTP worker/native-Postgres acceptance, with synthetic proof.

Not a browser, hosted gateway, public TLS/DNS, or production acceptance test.
Uses the existing owned empty scratch DB and rolls back every fixture row.
The HTTP RPC adapter enforces native PG roles but does not implement JWT crypto.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import queue
import shutil
import socket
import subprocess
import threading
import time
import urllib.error
import urllib.request
import uuid
from datetime import UTC, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PYTHON_PSQL = Path(
    shutil.which("psql") or r"C:\Program Files\PostgreSQL\17\bin\psql.exe"
)
DATABASE = "rad_research_worker_http_20261031"
ADMIN = "81000000-0000-4000-8000-000000000001"
ARTICLE = "81000000-0000-4000-8000-000000000010"
AUTHORITY = "81000000-0000-4000-8000-000000000060"
BINDING = "81000000-0000-4000-8000-000000000080"
WORKER_TOKEN = "synthetic-native-official-worker-token-00000000"
SERVICE_KEY = "synthetic-native-service-key"
ADMIN_KEY = "synthetic-native-admin-key"
USER_KEY = "synthetic-native-user-key"
PG_ENV = {
    key: value for key, value in os.environ.items() if not key.upper().startswith("PG")
}
PG_ENV.update(PGHOSTADDR="127.0.0.1", PGCONNECT_TIMEOUT="5", PGCLIENTENCODING="UTF8")
ALLOWED_RPCS = [
    "claim_official_research_job",
    "get_official_research_job",
    "finish_official_research_job",
    "get_bound_official_refresh_targets",
    "renew_bound_official_refresh_lease",
    "yield_bound_official_refresh",
    "ingest_bound_official_refresh",
    "enqueue_research_refresh",
    "get_research_review_context_v2",
    "save_structured_research_review",
    "save_visa_article_draft",
    "publish_visa_article_revision",
]


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


class NativeSession:
    def __init__(self):
        self.process = subprocess.Popen(
            [
                str(PYTHON_PSQL),
                "-XqAt",
                "-h",
                "127.0.0.1",
                "-p",
                "64932",
                "-U",
                "postgres",
                "-d",
                DATABASE,
                "-v",
                "ON_ERROR_STOP=0",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            env=PG_ENV,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        self.output = queue.Queue()
        self.errors = []
        self.lock = threading.Lock()
        threading.Thread(target=self._read, daemon=True).start()
        threading.Thread(
            target=lambda: self.errors.extend(self.process.stderr.readlines()),
            daemon=True,
        ).start()

    def _read(self):
        for line in self.process.stdout:
            self.output.put(line.rstrip("\r\n"))
        self.output.put(None)

    def execute(self, sql):
        with self.lock:
            marker = "END_" + uuid.uuid4().hex
            before = len(self.errors)
            self.process.stdin.write(sql + "\n\\echo " + marker + "\n")
            self.process.stdin.flush()
            lines = []
            while True:
                line = self.output.get(timeout=30)
                if line == marker:
                    break
                if line is None:
                    raise RuntimeError("native_session_closed")
                if line:
                    lines.append(line)
            if len(self.errors) > before:
                raise RuntimeError(
                    "native_sql_failure: " + "".join(self.errors[before:])
                )
            return lines

    def query(self, sql):
        return json.loads(
            self.execute("select to_jsonb(value) from (" + sql + ")value;")[-1]
        )

    def rpc(self, name, params, role="service_role"):
        return json.loads(
            self.execute(
                "select pg_temp.native_rpc("
                + literal(name)
                + ","
                + literal(json.dumps(params))
                + "::jsonb,"
                + literal(role)
                + ");"
            )[-1]
        )

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write("rollback;\n\\q\n")
            self.process.stdin.flush()
            self.process.wait(timeout=5)
        self.process.stdin.close()


def http_json(url, body=None, headers=None):
    payload = None if body is None else json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers=headers or {},
        method="POST" if body is not None else "GET",
    )
    try:
        response = urllib.request.urlopen(request, timeout=20)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return response.status, json.loads(response.read())


def run(runtime: Path, output: Path):
    marker = json.loads((runtime / "RAD_DISPOSABLE_LOCAL_ONLY.json").read_text())
    if (
        marker.get("port") != 64932
        or Path(marker.get("source", "")).resolve() != ROOT.resolve()
    ):
        raise ValueError("owned_local_native_runtime_required")
    if not PYTHON_PSQL.is_file() or not shutil.which("deno"):
        raise ValueError("native_psql_and_deno_required")
    output.mkdir(parents=True, exist_ok=True)
    session = NativeSession()
    server = None
    worker = None
    checks = []
    calls = []
    state = {
        "text": "NAV BEGIN_SOURCE exact controlled source version two END_SOURCE FOOTER",
        "replay_ingest": True,
    }
    try:
        tracked_rows_sql = """select (select count(*) from auth.users) users,
 (select count(*) from private.rad_research_jobs) jobs,(select count(*) from public.visa_articles) articles,
 (select count(*) from public.source_documents) documents,(select count(*) from public.source_snapshots) snapshots,
 (select count(*) from public.visa_research_proposals) proposals,(select count(*) from private.rad_official_refresh_bindings) bindings,
 (select count(*) from private.rad_bound_raw_captures) raw_captures"""
        initial = session.query(tracked_rows_sql)
        if (
            any(initial.values())
            or session.query("select current_database() database")["database"]
            != DATABASE
        ):
            raise ValueError("empty_owned_research_scratch_required")
        fingerprint_sql = """select jsonb_object_agg(n.nspname||'.'||p.proname,md5(pg_get_functiondef(p.oid))) definitions
from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prokind='f' and
 ((n.nspname='public' and p.proname in('get_bound_official_refresh_targets','ingest_bound_official_refresh',
 'renew_bound_official_refresh_lease','yield_bound_official_refresh','finish_official_research_job',
 'save_structured_research_review','get_research_review_context_v2'))
 or(n.nspname='private' and p.proname in('rad_lock_bound_refresh_authority','rad_complete_bound_target')))"""
        fingerprints = session.query(fingerprint_sql)["definitions"]
        if len(fingerprints) != 9:
            raise ValueError("current_bound_refresh_schema_required")
        fixture = (ROOT / "supabase/tests/rad_bound_official_refresh.sql").read_text(
            encoding="utf-8-sig"
        )
        fixture = fixture.split("create function pg_temp.refresh_text", 1)[0]
        session.execute(fixture)
        session.execute(
            "update private.rad_research_jobs set status='queued',lease_token=null,lease_until=null,attempts=0;"
        )
        whitelist = ",".join(literal(x) for x in ALLOWED_RPCS)
        session.execute(
            """
create function pg_temp.native_rpc(function_name text,args jsonb,requested_role text) returns jsonb
language plpgsql as $$declare call_args text;result jsonb;claims jsonb;code text;message text;begin
 if not function_name=any(array["""
            + whitelist
            + """]) or requested_role not in('authenticated','service_role','ordinary_user') then raise exception 'fixture_rpc_denied';end if;
 claims:=jsonb_build_object('role',case when requested_role='ordinary_user' then 'authenticated' else requested_role end);
 if requested_role='ordinary_user' then claims:=claims||jsonb_build_object('sub','81000000-0000-4000-8000-000000000002');end if;
 if requested_role='authenticated' then claims:=claims||jsonb_build_object('sub','"""
            + ADMIN
            + """');end if;
 perform set_config('request.jwt.claims',claims::text,true);
 select string_agg(format('%I=>%s',key,case when value='null'::jsonb then 'NULL' else quote_literal(case when jsonb_typeof(value)='string' then value#>>'{}' else value::text end) end),',' order by key) into call_args from jsonb_each(args);
 begin
  perform set_config('role',case when requested_role='ordinary_user' then 'authenticated' else requested_role end,true);
  execute format('select to_jsonb(public.%I(%s))',function_name,coalesce(call_args,'')) into result;
  perform set_config('role','postgres',true);
  return jsonb_build_object('ok',true,'data',result);
 exception when others then
  get stacked diagnostics code=returned_sqlstate,message=message_text;
  perform set_config('role','postgres',true);
  return jsonb_build_object('ok',false,'code',code,'message',message);
 end;
end $$;
"""
        )

        class Api(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def respond(self, status, value):
                raw = json.dumps(value, ensure_ascii=False).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def do_GET(self):
                if self.path != "/source":
                    return self.respond(404, {})
                raw = ("<html><p>" + state["text"] + "</p></html>").encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html;charset=utf-8")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def do_POST(self):
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 2_000_000:
                    return self.respond(422, {})
                params = json.loads(self.rfile.read(length))
                if self.path == "/fetch":
                    if (
                        self.headers.get("Authorization")
                        != "Bearer synthetic-native-egress-purpose-token-00000000"
                        or params != {"url": "https://bound-refresh.example.org/info"}
                    ):
                        return self.respond(403, {})
                    with urllib.request.urlopen(
                        base + "/source", timeout=5
                    ) as response:
                        body = response.read()
                    return self.respond(
                        200,
                        {
                            "status": 200,
                            "headers": {"content-type": "text/html;charset=utf-8"},
                            "body_base64": base64.b64encode(body).decode(),
                        },
                    )
                prefix = "/rest/v1/rpc/"
                name = self.path.removeprefix(prefix)
                key = self.headers.get("Authorization", "").removeprefix("Bearer ")
                if (
                    not self.path.startswith(prefix)
                    or name not in ALLOWED_RPCS
                    or key not in (SERVICE_KEY, ADMIN_KEY, USER_KEY)
                ):
                    return self.respond(403, {})
                role = (
                    "service_role"
                    if key == SERVICE_KEY
                    else "ordinary_user"
                    if key == USER_KEY
                    else "authenticated"
                )
                if name == "ingest_bound_official_refresh" and state.get(
                    "stale_target_once"
                ):
                    params["p_expected_snapshot_id"] = str(uuid.uuid4())
                    state["stale_target_once"] = False
                result = session.rpc(name, params, role)
                calls.append(
                    {
                        "rpc": name,
                        "role": role,
                        "ok": result["ok"],
                        "error": None
                        if result["ok"]
                        else {"code": result["code"], "message": result["message"]},
                    }
                )
                (output / "rpc_trace.json").write_text(
                    json.dumps(calls, indent=2), encoding="utf-8"
                )
                if (
                    name == "ingest_bound_official_refresh"
                    and state["replay_ingest"]
                    and result["ok"]
                ):
                    replay = session.rpc(name, params, role)
                    assert replay == result, (
                        "same-lease exact ingest retry changed result"
                    )
                    state["replay_ingest"] = False
                    checks.append("same_lease_exact_ingest_retry")
                if result["ok"]:
                    return self.respond(200, result["data"])
                code = result["code"]
                return self.respond(
                    403
                    if code in ("PT403", "42501")
                    else 409
                    if code == "PT409"
                    else 422,
                    {"code": code, "message": result["message"]},
                )

        server = ThreadingHTTPServer(("127.0.0.1", 0), Api)
        base = "http://127.0.0.1:" + str(server.server_address[1])
        threading.Thread(target=server.serve_forever, daemon=True).start()
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            worker_port = reservation.getsockname()[1]
        worker = subprocess.Popen(
            [
                shutil.which("deno"),
                "run",
                "--allow-env",
                "--allow-read=.",
                "--allow-net=127.0.0.1",
                "supabase/functions/tests/fixtures/native_bound_worker.ts",
            ],
            cwd=ROOT,
            env={
                **os.environ,
                "RAD_ACCEPTANCE_API": base,
                "RAD_ACCEPTANCE_WORKER_PORT": str(worker_port),
            },
            stdout=subprocess.DEVNULL,
            stderr=(output / "worker.log").open("w", encoding="utf-8"),
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        worker_url = "http://127.0.0.1:" + str(worker_port)
        for _ in range(100):
            try:
                with socket.create_connection(("127.0.0.1", worker_port), timeout=0.2):
                    break
            except OSError:
                time.sleep(0.05)
        headers = {
            "x-rad-official-source-token": WORKER_TOKEN,
            "Content-Type": "application/json",
        }

        def rpc(name, params, admin=False, want=200):
            status, result = http_json(
                base + "/rest/v1/rpc/" + name,
                params,
                {
                    "Authorization": "Bearer " + (ADMIN_KEY if admin else SERVICE_KEY),
                    "Content-Type": "application/json",
                },
            )
            assert status == want, (name, status, result)
            return result

        def dispatch(want=200):
            status, result = http_json(worker_url + "?dispatch=1", {}, headers)
            assert status == want, (status, result)
            return result

        def enqueue():
            return rpc(
                "enqueue_research_refresh",
                {
                    "p_request": {
                        "authority_ids": [AUTHORITY],
                        "request_key": str(uuid.uuid4()),
                    }
                },
                admin=True,
            )["data"]["job_id"]

        def proposals():
            return session.query(
                "select coalesce(jsonb_agg(id order by created_at,id),'[]') ids from public.visa_research_proposals"
            )["ids"]

        def context(pid):
            return rpc(
                "get_research_review_context_v2", {"p_proposal_id": pid}, admin=True
            )["data"]

        def review(ctx, mode, decision=None, edit=None, revision=None):
            return rpc(
                "save_structured_research_review",
                {
                    "p_request": {
                        "proposal_id": ctx["proposal"]["id"],
                        "expected_proposal_revision": ctx["proposal"]["revision"],
                        "expected_review_revision": ctx["review_revision"],
                        "base_revision_id": ctx["base"]["revision_id"],
                        "base_content_hash": ctx["base"]["content_hash"],
                        "mode": mode,
                        "decisions": []
                        if decision is None
                        else [
                            {
                                "section_id": ctx["structured_patches"][0]["id"],
                                "decision": decision,
                                "edited_text": edit,
                            }
                        ],
                        "note": "SYNTHETIC explicit human review",
                        "request_key": str(uuid.uuid4()),
                    }
                },
                admin=True,
                want=200 if revision is None else revision,
            )

        assert http_json(worker_url + "?dispatch=1", {})[0] == 403
        result = dispatch()
        assert result["claimed"] == 1 and result["succeeded"] == 1
        pid = proposals()[0]
        ctx = context(pid)
        assert (
            ctx["bound_source_change"]["new_fragment"]
            == "exact controlled source version two"
        )
        assert ctx["bound_source_change"]["source_language"] == "en"
        assert ctx["proposal"]["editorial_state"] == "review"
        metadata = ctx["bound_source_change"]["review_metadata"]
        assert (
            metadata["context_scope"]
            == "current_registry_context_not_capture_verification"
        )
        assert (
            metadata["publisher_name"] == "SYNTHETIC candidate"
            and metadata["jurisdiction"] == "ZZ"
        )
        assert (
            metadata["source_published_at"] is None
            and metadata["effective_date"] is None
        )
        assert metadata["uncertainty_code"] == "human_legal_review_required"
        assert metadata["change_classification"] == "bound_source_text_change"
        snapshot_dates = session.query(
            "select (select fetched_at from public.source_snapshots where id='"
            + ctx["bound_source_change"]["old_snapshot_id"]
            + "') old_fetched_at,(select fetched_at from public.source_snapshots where id='"
            + ctx["bound_source_change"]["new_snapshot_id"]
            + "') new_fetched_at"
        )
        assert (
            metadata["old_fetched_at"] == snapshot_dates["old_fetched_at"]
            and metadata["new_fetched_at"] == snapshot_dates["new_fetched_at"]
        )
        checks.append(
            "review_metadata_retains_real_capture_times_and_unknown_legal_dates"
        )
        evidence_hash = session.query(
            "select md5(evidence::text) hash from private.rad_bound_proposal_evidence where proposal_id='"
            + pid
            + "'"
        )["hash"]
        session.execute(
            "update private.authority_entities set name='SYNTHETIC changed registry label' where id='"
            + AUTHORITY
            + "';"
        )
        assert (
            context(pid)["bound_source_change"]["review_metadata"]["publisher_name"]
            == "SYNTHETIC changed registry label"
        )
        assert (
            session.query(
                "select md5(evidence::text) hash from private.rad_bound_proposal_evidence where proposal_id='"
                + pid
                + "'"
            )["hash"]
            == evidence_hash
        )
        checks.append("current_registry_metadata_does_not_rewrite_capture_evidence")
        denied_status, denied_body = http_json(
            base + "/rest/v1/rpc/get_research_review_context_v2",
            {"p_proposal_id": pid},
            {"Authorization": "Bearer " + USER_KEY, "Content-Type": "application/json"},
        )
        assert denied_status == 403 and "bound_source_change" not in json.dumps(
            denied_body
        )
        checks.append("ordinary_user_denied_private_review_metadata")
        checks.append("actual_http_dispatch_egress_adapter_sql_snapshot_proposal")
        before = session.query(
            "select head_id,published_id from public.visa_article_heads where article_id='"
            + ARTICLE
            + "' and locale='en'"
        )
        review(ctx, "save_review")
        assert (
            session.query(
                "select head_id,published_id from public.visa_article_heads where article_id='"
                + ARTICLE
                + "' and locale='en'"
            )
            == before
        )
        checks.append("save_review_deferral_preserves_article")
        review(context(pid), "reject_proposal")
        assert (
            session.query(
                "select head_id,published_id from public.visa_article_heads where article_id='"
                + ARTICLE
                + "' and locale='en'"
            )
            == before
        )
        checks.append("explicit_admin_reject_preserves_article")
        state["text"] = (
            "NAV ONLY UPDATE BEGIN_SOURCE exact controlled source version two END_SOURCE FOOTER"
        )
        enqueue()
        dispatch()
        assert len(proposals()) == 1
        checks.append("page_noise_no_proposal")
        before_snapshots = session.query(
            "select count(*) count from public.source_snapshots"
        )["count"]
        state["text"] = (
            "BEGIN_SOURCE stale frozen snapshot must not be captured END_SOURCE"
        )
        state["stale_target_once"] = True
        enqueue()
        dispatch(want=503)
        assert len(proposals()) == 1
        assert (
            session.query("select count(*) count from public.source_snapshots")["count"]
            == before_snapshots
        )
        checks.append("stale_snapshot_target_conflict_preserves_evidence")
        state["text"] = "BEGIN_SOURCE exact controlled source version three END_SOURCE"
        enqueue()
        dispatch()
        ctx = context(next(p for p in proposals() if p != pid))
        accepted = review(ctx, "create_draft", "accept")
        assert accepted["data"]["published"] is False
        head = session.query(
            "select rev.id,rev.content_hash,rev.revision,h.published_id from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id where h.article_id='"
            + ARTICLE
            + "' and h.locale='en'"
        )
        assert head["revision"] == 2 and head["published_id"] is None
        checks.append("actual_stage7_admin_accept_creates_only_unpublished_draft")
        rpc(
            "publish_visa_article_revision",
            {
                "p_request": {
                    "article_id": ARTICLE,
                    "revision_id": head["id"],
                    "content_hash": head["content_hash"],
                    "request_key": str(uuid.uuid4()),
                }
            },
            admin=True,
            want=409,
        )
        checks.append("unapproved_draft_publication_denied")
        previous = set(proposals())
        state["text"] = "BEGIN_SOURCE exact controlled source version four END_SOURCE"
        enqueue()
        dispatch()
        ctx = context(next(p for p in proposals() if p not in previous))
        review(ctx, "create_draft", "edit", "SYNTHETIC human edited wording")
        head = session.query(
            "select rev.id,rev.revision,h.published_id from public.visa_article_heads h join public.visa_article_revisions rev on rev.id=h.head_id where h.article_id='"
            + ARTICLE
            + "' and h.locale='en'"
        )
        assert head["revision"] == 3 and head["published_id"] is None
        checks.append("actual_stage7_admin_edit_creates_only_unpublished_draft")
        previous = set(proposals())
        state["text"] = "BEGIN_SOURCE exact controlled source version five END_SOURCE"
        enqueue()
        dispatch()
        ctx = context(next(p for p in proposals() if p not in previous))
        body = ctx["base"]["body"]
        body.update(
            expected_revision=ctx["base"]["revision"],
            title="SYNTHETIC intervening human draft",
            request_key=str(uuid.uuid4()),
        )
        rpc("save_visa_article_draft", {"p_request": body}, admin=True)
        review(ctx, "save_review", revision=409)
        checks.append("stale_head_review_conflict")
        before_proposals = set(proposals())
        before_snapshots = session.query(
            "select count(*) count from public.source_snapshots"
        )["count"]
        session.execute(
            "update private.authority_trust_roots set active=false where id='81000000-0000-4000-8000-000000000061';"
        )
        state["text"] = "BEGIN_SOURCE forbidden after revocation END_SOURCE"
        enqueue()
        dispatch(want=503)
        assert set(proposals()) == before_proposals
        assert (
            session.query("select count(*) count from public.source_snapshots")["count"]
            == before_snapshots
        )
        checks.append("revoked_root_rejects_before_snapshot_or_proposal")
        session.execute("rollback;")
        final = session.query(tracked_rows_sql)
        assert final == initial
        assert session.query(fingerprint_sql)["definitions"] == fingerprints
        result = {
            "source_head": subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
            ).strip(),
            "observed_at": datetime.now(UTC).isoformat(),
            "scope": "local_http_native_pg_synthetic_proof_only_not_browser_or_hosted_gateway",
            "database": DATABASE,
            "checks": checks,
            "rpc_calls": calls,
            "final_fixture_rows": final,
            "paid_provider_calls": 0,
            "database_function_fingerprints_md5": fingerprints,
        }
        result["source_sha256"] = {
            str(path.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(
                path.read_bytes()
            ).hexdigest()
            for path in [
                Path(__file__),
                ROOT / "supabase/functions/tests/fixtures/native_bound_worker.ts",
                ROOT / "supabase/functions/official-source-worker/handler.ts",
                ROOT / "supabase/functions/official-source-worker/refresh.ts",
                ROOT / "supabase/functions/official-source-worker/dispatcher.ts",
                ROOT / "supabase/functions/research-sync/egress.ts",
                ROOT
                / "supabase/migrations/20261030221423_rad_bound_refresh_authority_lock.sql",
                ROOT
                / "supabase/migrations/20261031152706_rad_bound_research_review_metadata.sql",
            ]
        }
        (output / "acceptance.json").write_text(
            json.dumps(result, indent=2), encoding="utf-8"
        )
        print(
            json.dumps(
                {"status": "PASS", "checks": checks, "final_fixture_rows": final},
                indent=2,
            )
        )
        return result
    finally:
        if worker is not None:
            worker.terminate()
            worker.wait(timeout=5)
        if server is not None:
            server.shutdown()
            server.server_close()
        session.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    run(args.runtime, args.output)
