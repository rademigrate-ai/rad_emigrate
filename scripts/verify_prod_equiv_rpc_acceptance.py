#!/usr/bin/env python3
"""Behavioral acceptance on the disposable 47+5 local Supabase stack only."""

import concurrent.futures
import json
import subprocess
import uuid

from verify_stage2_browser_e2e import LocalSupabaseFixtures, load_local_environment, require
from verify_prepilot_consultation import access_token


CONTAINER = "supabase_db_rad-prod-equivalent-20261013"


def psql(sql: str, *, container: str = CONTAINER, expect_error: str | None = None) -> str:
    require(container in (CONTAINER, "supabase_db_rad_prepilot_codex_20261012"),
            "refusing a database outside the disposable local stacks")
    result = subprocess.run(
        ["docker", "exec", container, "psql", "-X", "-v", "ON_ERROR_STOP=1",
         "-U", "postgres", "-d", "postgres", "-Atc", sql],
        capture_output=True, text=True, timeout=45,
    )
    if expect_error:
        require(result.returncode != 0 and expect_error in result.stderr,
                f"expected {expect_error!r}, got {result.returncode}: {result.stderr[-300:]}")
        return expect_error
    require(result.returncode == 0, f"local SQL failed: {result.stderr[-500:]}")
    return result.stdout.strip()


def expect_rpc_denied(fixtures, token, name, payload, error):
    status, body, _ = fixtures.request(
        "POST", f"/rest/v1/rpc/{name}", token=token, payload=payload)
    require(status == 403 and error.encode() in body,
            f"{name} returned HTTP {status}: {body[:300]!r}")
    return {"status": status, "error": error}


def feed_approval(admin_id: str):
    draft = str(uuid.uuid4())
    claims = json.dumps({"sub": admin_id, "role": "authenticated"})
    prefix = (
        "begin; "
        f"insert into public.content_drafts(id,language_code,title,body,status) "
        f"values ('{draft}','en','Synthetic rehearsal title','Synthetic rehearsal body','draft'); "
        "set local role authenticated; "
        f"select set_config('request.jwt.claim.sub','{admin_id}',true); "
        f"select set_config('request.jwt.claims','{claims}',true); "
    )
    draft_denial = psql(prefix + f"select public.publish_content_draft('{draft}'::uuid); rollback;",
                        expect_error="draft requires explicit approval")
    review_prefix = prefix.replace("'draft');", "'review');")
    review_denial = psql(review_prefix + f"select public.publish_content_draft('{draft}'::uuid); rollback;",
                         expect_error="draft requires explicit approval")
    approved_prefix = prefix.replace("'draft');", "'approved');")
    approved = psql(
        approved_prefix +
        f"select public.publish_content_draft('{draft}'::uuid); "
        f"select count(*) from public.feed_items where slug like '%{draft[:8]}%'; rollback;"
    )
    lines = approved.splitlines()
    require(len(lines) >= 2 and lines[-2] == "1", f"approved publication did not create one Feed item: {approved}")
    require(psql("select count(*) from public.feed_items") == "0", "Feed fixture escaped rollback")
    return {"draft_denied": draft_denial, "review_denied": review_denial,
            "approved_transaction_feed_rows": 1, "persisted_feed_rows": 0}


def discovery_behavior(container: str):
    slug = "rehearsal_discovery_" + uuid.uuid4().hex[:10]
    claims = json.dumps({"role": "service_role"})
    sql = (
        "begin; "
        "insert into public.ai_providers(slug,display_name,adapter,base_url) "
        f"values ('{slug}','Synthetic discovery','openai_compatible','https://example.com/v1'); "
        f"select set_config('request.jwt.claims','{claims}',true); "
        "select public.ingest_ai_model_catalogue("
        f"(select id from public.ai_providers where slug='{slug}'),1, "
        "'[ {\"slug\":\"new-chat\",\"capability\":\"chat\",\"context_window\":8192,"
        "\"supports_tools\":false,\"supports_structured_output\":false,"
        "\"capability_source\":\"discovered\",\"cost_input_per_million\":0,"
        "\"cost_source\":\"unknown\"} ]'::jsonb); "
        "select enabled::text from public.ai_models where slug='new-chat' "
        f"and provider_id=(select id from public.ai_providers where slug='{slug}'); rollback;"
    )
    output = psql(sql, container=container).splitlines()
    require(len(output) >= 2 and output[-2] in ("true", "false"),
            f"discovery did not return model state: {output}")
    return output[-2] == "true"


def main():
    env = load_local_environment()
    require(env["API_URL"] == "http://127.0.0.1:56321", "unexpected local API")
    fixtures = LocalSupabaseFixtures(env)
    results = {"api_url": env["API_URL"], "checks": {}}
    owner = other = admin = None
    quota_seeded = False
    try:
        owner = fixtures.create_identity("user")
        other = fixtures.create_identity("user")
        admin = fixtures.create_identity("admin")
        owner_token = access_token(fixtures, owner)
        other_token = access_token(fixtures, other)

        for name, payload in (
            ("get_ai_daily_quota_status", {"p_user_id": other.user_id, "p_role": "super_admin"}),
            ("get_ai_access_decision", {"p_user_id": other.user_id, "p_guest_key_hash": None}),
        ):
            results["checks"][name + "_cross_owner"] = expect_rpc_denied(
                fixtures, owner_token, name, payload, "forbidden")
        own_status, own_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/get_ai_daily_quota_status", token=owner_token,
            payload={"p_user_id": owner.user_id, "p_role": "super_admin"})
        require(own_status == 200 and json.loads(own_body)["limit"] == 50,
                f"own quota/role derivation HTTP {own_status}: {own_body[:300]!r}")
        results["checks"]["own_quota_role_derived"] = {"status": own_status, "limit": 50}

        psql("insert into public.ai_requests(user_id,capability,status,routing_reason) "
             f"select '{owner.user_id}'::uuid,'chat','running','synthetic_rehearsal_seed' "
             "from generate_series(1,48)")
        quota_seeded = True
        def reserve(_):
            status, body, _ = fixtures.request(
                "POST", "/rest/v1/rpc/consume_ai_daily_quota",
                payload={"p_user_id": owner.user_id, "p_role": "super_admin"})
            require(status == 200, f"quota reservation HTTP {status}: {body[:200]!r}")
            return json.loads(body)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            reservations = list(executor.map(reserve, range(8)))
        allowed = [x for x in reservations if x["allowed"]]
        denied = [x for x in reservations if not x["allowed"]]
        final_count = int(psql(f"select count(*) from public.ai_requests where user_id='{owner.user_id}'"))
        require(len(allowed) == 2 and len(denied) == 6 and final_count == 50,
                f"quota race: allowed={len(allowed)} denied={len(denied)} rows={final_count}")
        require(len({x["request_id"] for x in allowed}) == 2, "duplicate reservation IDs")
        results["checks"]["quota_concurrency"] = {
            "parallel_calls": 8, "preseeded": 48, "allowed": 2,
            "denied": 6, "final_rows": final_count, "role_parameter": "super_admin",
            "profile_role": "user"}

        start_feed = len(fixtures.expect_json("GET", "/rest/v1/feed_items?select=id"))
        anon_status, _, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request", token=fixtures.anon_key,
            payload={"p_topic": "Synthetic topic", "p_message": "Synthetic consultation message"})
        require(anon_status in (401, 403), f"anonymous consultation HTTP {anon_status}")
        results["checks"]["consultation_anon_denied"] = anon_status
        for label, payload, expected in (
            ("invalid_topic", {"p_topic": "x", "p_message": "Valid synthetic message"}, "invalid_consultation_topic"),
            ("invalid_message", {"p_topic": "Valid synthetic topic", "p_message": "short"}, "invalid_consultation_message"),
        ):
            status, body, _ = fixtures.request("POST", "/rest/v1/rpc/submit_consultation_request",
                                               token=other_token, payload=payload)
            require(status == 400 and expected.encode() in body,
                    f"{label} HTTP {status}: {body[:200]!r}")
            results["checks"]["consultation_" + label] = status
        direct_status, _, _ = fixtures.request(
            "POST", "/rest/v1/consultation_requests", token=other_token,
            payload={"user_id": other.user_id, "topic": "Direct", "message": "Must fail"})
        require(direct_status == 403, f"direct consultation INSERT HTTP {direct_status}")
        results["checks"]["consultation_direct_insert_denied"] = direct_status
        owner_application = fixtures.expect_json(
            "POST", "/rest/v1/applications?select=id,user_id",
            payload={"user_id": owner.user_id, "visa_type": "synthetic-rehearsal",
                     "status": "draft"}, prefer="return=representation")[0]["id"]
        related_status, related_body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request", token=other_token,
            payload={"p_topic": "Cross owner application",
                     "p_message": "This synthetic cross-owner request must fail",
                     "p_related_application_id": owner_application})
        require(related_status == 403 and b"related_application_forbidden" in related_body,
                f"cross-owner application HTTP {related_status}: {related_body[:200]!r}")
        results["checks"]["consultation_cross_owner_application_denied"] = related_status
        ids = []
        for i in range(3):
            status, body, _ = fixtures.request(
                "POST", "/rest/v1/rpc/submit_consultation_request", token=other_token,
                payload={"p_topic": f"Synthetic request {i}",
                         "p_message": "Disposable production-equivalent rehearsal request"})
            require(status == 200, f"consultation {i} HTTP {status}: {body[:200]!r}")
            ids.append(json.loads(body))
        limited, body, _ = fixtures.request(
            "POST", "/rest/v1/rpc/submit_consultation_request", token=other_token,
            payload={"p_topic": "Synthetic fourth", "p_message": "Must hit rate limit"})
        require(limited == 400 and b"consultation_rate_limited" in body,
                f"fourth consultation HTTP {limited}: {body[:200]!r}")
        own_rows = fixtures.expect_json(
            "GET", f"/rest/v1/consultation_requests?select=id&id=eq.{ids[0]}", token=other_token)
        other_status, other_body, _ = fixtures.request(
            "GET", f"/rest/v1/consultation_requests?select=id&id=eq.{ids[0]}", token=owner_token)
        require(len(own_rows) == 1 and other_status == 200 and json.loads(other_body) == [],
                "consultation owner isolation failed")
        note_status, _, _ = fixtures.request(
            "GET", f"/rest/v1/consultation_requests?select=admin_note&id=eq.{ids[0]}",
            token=other_token)
        require(note_status == 403, f"admin_note HTTP {note_status}")
        end_feed = len(fixtures.expect_json("GET", "/rest/v1/feed_items?select=id"))
        require(start_feed == end_feed == 0, "consultation created Feed content")
        results["checks"]["consultation_abuse"] = {
            "accepted": 3, "fourth_status": limited, "owner_rows": 1,
            "cross_owner_rows": 0, "admin_note_status": note_status,
            "feed_before": start_feed, "feed_after": end_feed}

        results["checks"]["feed_approval"] = feed_approval(admin.user_id)
        live_discovery = discovery_behavior(CONTAINER)
        repo_discovery = discovery_behavior("supabase_db_rad_prepilot_codex_20261012")
        require(live_discovery and not repo_discovery,
                f"unexpected discovery behavior live={live_discovery} repo={repo_discovery}")
        results["checks"]["discovery_behavior"] = {
            "production_equivalent_auto_enables_new_chat": live_discovery,
            "repository_50_chain_auto_enables_new_chat": repo_discovery,
            "owner_decision_required": True}
        results["result"] = "PASS_LOCAL_REHEARSAL"
    finally:
        if quota_seeded:
            psql(f"delete from public.ai_requests where user_id='{owner.user_id}'")
        fixtures.cleanup()
        results["fixtures_cleaned"] = True
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
