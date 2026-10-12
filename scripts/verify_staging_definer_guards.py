#!/usr/bin/env python3
"""Read-only local regression of user-facing SECURITY DEFINER guards.

Runs each attempted call in its own READ ONLY transaction as an ordinary
authenticated principal with no privileged profile. No target function may
reach a write; the expected outcome for protected RPCs is SQLSTATE 42501.
"""

import argparse
import json
import subprocess


USER = "11111111-1111-4111-8111-111111111111"
OTHER = "22222222-2222-4222-8222-222222222222"
NIL = "00000000-0000-0000-0000-000000000000"
CALLS = {
    "configure_ai_provider": "public.configure_ai_provider('probe','Probe','openai_compatible','https://example.com','sample-key-123',false,1)",
    "promote_knowledge_from_evidence": f"public.promote_knowledge_from_evidence('probe','en','Probe','Probe','valid claim text','{NIL}'::uuid)",
    "publish_content_draft": f"public.publish_content_draft('{NIL}'::uuid)",
    "register_knowledge_conflict": "public.register_knowledge_conflict('probe','statement A','statement B')",
    "set_ai_model_configuration": f"public.set_ai_model_configuration('{NIL}'::uuid,false,'user',1,100)",
    "set_content_draft_status": f"public.set_content_draft_status('{NIL}'::uuid,'review')",
    "set_research_finding_status": f"public.set_research_finding_status('{NIL}'::uuid,'review')",
    "set_research_source_configuration": f"public.set_research_source_configuration('{NIL}'::uuid,'Probe',false,'user','general_web')",
    "set_user_role": f"public.set_user_role('{NIL}'::uuid,'admin')",
    "update_content_draft": f"public.update_content_draft('{NIL}'::uuid,'Valid title','Valid body')",
    "upsert_research_source": "public.upsert_research_source(null,'Probe','https://example.com','external','general_web','user',false)",
    "get_ai_daily_quota_status_cross_owner": f"public.get_ai_daily_quota_status('{OTHER}'::uuid,'super_admin')",
    "get_ai_access_decision_cross_owner": f"public.get_ai_access_decision('{OTHER}'::uuid,null)",
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--container", default="supabase_db_rad_prepilot_codex_20261012")
    args = parser.parse_args()
    if not args.container.startswith("supabase_db_rad_prepilot_"):
        raise SystemExit("refusing a database outside the disposable prepilot stack")
    claims = json.dumps({"sub": USER, "role": "authenticated"})
    failures = []
    for name, call in CALLS.items():
        sql = (
            "begin read only; "
            "set local role authenticated; "
            f"select set_config('request.jwt.claim.sub','{USER}',true); "
            f"select set_config('request.jwt.claims','{claims}',true); "
            f"select {call}; rollback;"
        )
        result = subprocess.run(
            ["docker", "exec", args.container, "psql", "-X", "-v", "ON_ERROR_STOP=1",
             "-U", "postgres", "-d", "postgres", "-Atc", sql],
            capture_output=True, text=True, timeout=30,
        )
        detail = result.stderr.strip().splitlines()[-1] if result.stderr.strip() else ""
        passed = result.returncode != 0 and "forbidden" in result.stderr.lower()
        print(json.dumps({"function": name, "pass": passed,
                          "exit_code": result.returncode, "error": detail}))
        if not passed:
            failures.append(name)
    if failures:
        raise SystemExit("guard regression failed: " + ", ".join(failures))
    print(f"PASS: {len(CALLS)} protected RPCs denied ordinary authenticated caller")


if __name__ == "__main__":
    main()
