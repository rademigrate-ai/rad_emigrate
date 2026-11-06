#!/usr/bin/env python3
"""Commit/reopen a research-reviewed CMS draft using normal LOCAL Auth sessions.

Run only on an owned disposable Supabase stack after migration reconstruction.
Synthetic evidence is seeded locally; real Auth JWTs exercise the public RPCs.
No research provider, source website, hosted database or Feed publisher is called.
The owning test stack discards these uniquely named fixtures when stopped.
"""

from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import subprocess
import urllib.parse
import uuid
from pathlib import Path

import verify_local_auth_isolation as auth


def sql(statement: str) -> str:
    if os.environ.get("RAD_SELF_HOST_TEST_ROOT"):
        from self_host_stack import sql as stack_sql
        from self_host_test_target import target_root

        return (
            stack_sql(target_root(), statement.encode("utf8"))
            .stdout.decode("utf8")
            .strip()
        )
    command = ["supabase", "status", "--output", "json"]
    if os.name == "nt":
        command = ["cmd.exe", "/d", "/s", "/c", *command]
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    address = urllib.parse.urlsplit(json.loads(result.stdout)["DB_URL"])
    auth.require(
        address.hostname in {"127.0.0.1", "localhost", "::1"}, "owned loopback database"
    )
    binary = shutil.which("psql")
    if binary is None and os.name == "nt":
        binary = "C:/Program Files/PostgreSQL/17/bin/psql.exe"
    auth.require(bool(binary), "PostgreSQL client available")
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith("PG")}
    env.update(PGHOSTADDR=address.hostname, PGCLIENTENCODING="UTF8")
    if address.password:
        env["PGPASSWORD"] = urllib.parse.unquote(address.password)
    run = subprocess.run(
        [
            binary,
            "-XAtqw",
            "-h",
            address.hostname,
            "-p",
            str(address.port),
            "-U",
            address.username,
            "-d",
            address.path.lstrip("/"),
            "-v",
            "ON_ERROR_STOP=1",
        ],
        input=statement,
        capture_output=True,
        text=True,
        encoding="utf8",
        env=env,
        timeout=90,
    )
    # Never emit the connection URL, keys, JWTs, request payloads or raw SQL errors.
    auth.require(run.returncode == 0, "isolated SQL fixture/assertion")
    return run.stdout.strip()


def rpc(name: str, token: str, params: dict) -> dict:
    response, _ = auth.expect_success(
        "POST", "/rest/v1/rpc/" + name, token, params, label="research/CMS " + name
    )
    auth.require(
        isinstance(response, dict) and isinstance(response.get("data"), dict),
        "valid CMS envelope",
    )
    return response["data"]


def denied(
    name: str,
    token: str,
    params: dict,
    code: str | None = None,
    message: str | None = None,
) -> None:
    status, body = auth.expect_denied(
        "POST",
        "/rest/v1/rpc/" + name,
        token,
        params,
        label="denied research/CMS " + name,
    )
    if code:
        actual = auth.json_body(body).get("code")
        auth.require(
            actual == code, f"specific RPC denial {code}; received {actual} for {name}"
        )
    if message:
        auth.require(
            auth.json_body(body).get("message") == message, "expected editorial refusal"
        )
    auth.require(status >= 400, "no mutation acknowledged")


def main() -> None:
    seed = uuid.uuid4().hex[:8]
    email = f"research-cms-admin-{seed}@example.test"
    password = secrets.token_urlsafe(32)
    actor = str(uuid.UUID(auth.create_test_user(email, password)))
    other_email = f"research-cms-user-{seed}@example.test"
    other_password = secrets.token_urlsafe(32)
    other = str(uuid.UUID(auth.create_test_user(other_email, other_password)))
    auth.rows(
        "PATCH",
        f"/rest/v1/profiles?id=eq.{actor}",
        auth.SERVICE_ROLE_KEY,
        {"role": "admin"},
    )
    token, _ = auth.sign_in(email, password)
    user_token, _ = auth.sign_in(other_email, other_password)

    # Reuse the existing lossless fixture, replacing only its synthetic identity
    # namespace and actors. No forged JWT is used for any HTTP acceptance step.
    source = (
        Path(__file__).resolve().parents[1] / "supabase/tests/stage71_rich_review.sql"
    ).read_text("utf8")
    fixture = source.split("-- Authenticated non-Admin", 1)[0]
    fixture, removed = re.subn(
        r"insert into auth[.]users\(id,email\) values.*?;", "", fixture, flags=re.S
    )
    auth.require(removed == 1, "exact existing local fixture boundary")
    fixture = fixture.replace("71000000-0000-4000-8000-000000000001", actor)
    fixture = fixture.replace("71000000-0000-4000-8000-000000000002", other)
    fixture = fixture.replace("71000000-", seed + "-").replace(
        "stage71.example.org", f"stage71-{seed}.example.org"
    )
    fixture = fixture.replace("stage71-synthetic", "stage71-" + seed)
    # Seed the article and evidence, then let the normal Auth RPC perform the
    # first proposal write. The table also prevents duplicate snapshot proposals.
    fixture = fixture[
        : fixture.index(" response:=public.propose_structured_research(req);")
    ] + fixture[fixture.index(" insert into rich_test_state values(") :].replace(
        ",('proposal',response->'data')", ""
    )
    output = sql(
        fixture + "select jsonb_object_agg(name,value)from rich_test_state;commit;"
    )
    state = next(
        value
        for line in output.splitlines()
        if line.startswith("{")
        for value in [json.loads(line)]
        if {"base", "request", "sections", "fa"} <= value.keys()
    )
    request = state["request"]
    request["request_key"] = str(uuid.uuid4())
    proposed = rpc("propose_structured_research", token, {"p_request": request})
    auth.require(
        proposed == rpc("propose_structured_research", token, {"p_request": request}),
        "proposal retry identity",
    )
    auth.require(proposed["published"] is False, "research never publishes")
    proposal = str(uuid.UUID(proposed["proposal_id"]))
    article = str(uuid.UUID(request["article_id"]))
    before = json.loads(
        sql(f"""select jsonb_build_object(
     'feed',(select count(*)from public.feed_items),
     'revisions',(select count(*)from public.visa_article_revisions where article_id='{article}'),
     'base',(select to_jsonb(r)from public.visa_article_revisions r where id='{state["base"]["revision_id"]}'),
     'rich',(select composition from private.rad_editorial_rich_revisions where revision_id='{state["base"]["revision_id"]}'),
     'fa',(select to_jsonb(h)from public.visa_article_heads h where article_id='{article}'and locale='fa'));""")
    )
    context = rpc("get_research_review_context_v2", token, {"p_proposal_id": proposal})
    auth.require(
        context["stale"] is False and len(context["structured_patches"]) == 5,
        "source-backed full review context",
    )
    rejected_request = json.loads(json.dumps(request))
    rejected_request["request_key"] = str(uuid.uuid4())
    rejected_request["snapshot_id"] = request["snapshot_id"][:-3] + "053"
    for patch in rejected_request["patches"]:
        patch["evidence"]["snapshot_id"] = rejected_request["snapshot_id"]
        patch["evidence"]["excerpt"] = "SYNTHETIC fixture 2."
    rejected = rpc(
        "propose_structured_research", token, {"p_request": rejected_request}
    )
    rejection = {
        "proposal_id": rejected["proposal_id"],
        "expected_proposal_revision": 1,
        "expected_review_revision": 0,
        "base_revision_id": context["base"]["revision_id"],
        "base_content_hash": context["base"]["content_hash"],
        "mode": "reject_proposal",
        "decisions": [],
        "note": "SYNTHETIC rejected source change",
        "request_key": str(uuid.uuid4()),
    }
    refusal = rpc("save_structured_research_review", token, {"p_request": rejection})
    auth.require(
        refusal["published"] is False and refusal["draft_revision"] is None,
        "rejection creates no draft/publication",
    )
    rejected_context = rpc(
        "get_research_review_context_v2",
        token,
        {"p_proposal_id": rejected["proposal_id"]},
    )
    auth.require(
        rejected_context["proposal"]["editorial_state"] == "rejected",
        "rejection persists in the proposal history",
    )
    decisions = [
        {
            "section_id": patch["id"],
            "decision": "edit" if i == 0 else "reject" if i == 3 else "accept",
            "edited_text": "SYNTHETIC manual cell" if i == 0 else None,
        }
        for i, patch in enumerate(context["structured_patches"])
    ]
    review = {
        "proposal_id": proposal,
        "expected_proposal_revision": context["proposal"]["revision"],
        "expected_review_revision": context["review_revision"],
        "base_revision_id": context["base"]["revision_id"],
        "base_content_hash": context["base"]["content_hash"],
        "mode": "save_review",
        "decisions": decisions,
        "note": "SYNTHETIC local human review",
        "request_key": str(uuid.uuid4()),
    }
    for unauthorized in (user_token, auth.ANON_KEY):
        denied(
            "get_research_review_context_v2", unauthorized, {"p_proposal_id": proposal}
        )
        denied("save_structured_research_review", unauthorized, {"p_request": review})
        denied("propose_structured_research", unauthorized, {"p_request": request})
    saved = rpc("save_structured_research_review", token, {"p_request": review})
    auth.require(
        saved == rpc("save_structured_research_review", token, {"p_request": review}),
        "saved review retry",
    )
    # A separate login/client round trip must retrieve committed decisions.
    auth.expect_success("POST", "/auth/v1/logout", token, label="local reviewer logout")
    token, _ = auth.sign_in(email, password)
    reopened = rpc("get_research_review_context_v2", token, {"p_proposal_id": proposal})
    auth.require(
        reopened["decisions"] == decisions and reopened["review_revision"] == 1,
        "review survives logout/relogin",
    )
    denied(
        "save_structured_research_review",
        token,
        {"p_request": {**review, "request_key": str(uuid.uuid4())}},
        "PT409",
    )
    create = {
        **review,
        "mode": "create_draft",
        "expected_review_revision": 1,
        "request_key": str(uuid.uuid4()),
    }
    denied(
        "save_structured_research_review",
        token,
        {
            "p_request": {
                **create,
                "base_content_hash": "0" * 64,
                "request_key": str(uuid.uuid4()),
            }
        },
        "PT409",
    )
    created = rpc("save_structured_research_review", token, {"p_request": create})
    auth.require(
        created == rpc("save_structured_research_review", token, {"p_request": create}),
        "committed draft retry",
    )
    auth.require(
        created["published"] is False
        and created["draft_revision"]["editorial_state"] == "draft",
        "unpublished draft only",
    )
    draft = rpc(
        "get_cms_article_draft",
        token,
        {"p_request": {"article_id": article, "locale": "en"}},
    )
    auth.require(
        draft["revision_id"] == created["draft_revision"]["revision_id"],
        "reopen exact saved revision",
    )
    auth.require(
        "SYNTHETIC manual cell" in json.dumps(draft["content"]), "reopened edited text"
    )
    auth.expect_success(
        "POST", "/auth/v1/logout", token, label="local draft reviewer logout"
    )
    token, _ = auth.sign_in(email, password)
    again = rpc(
        "get_cms_article_draft",
        token,
        {"p_request": {"article_id": article, "locale": "en"}},
    )
    auth.require(draft == again, "CMS draft survives a second login and reload")
    for unauthorized in (user_token, auth.ANON_KEY):
        denied(
            "get_cms_article_draft",
            unauthorized,
            {"p_request": {"article_id": article, "locale": "en"}},
        )
    denied(
        "get_editorial_article",
        auth.ANON_KEY,
        {"p_article_id": article, "p_locale": "en", "p_preview": False},
        "PT404",
    )
    denied("publish_visa_article_revision", user_token, {"p_request": {}}, "PT403")
    denied(
        "publish_visa_article_revision",
        token,
        {
            "p_request": {
                "article_id": article,
                "revision_id": draft["revision_id"],
                "content_hash": created["draft_revision"]["content_hash"],
                "request_key": str(uuid.uuid4()),
            }
        },
        "PT409",
        "invalid_editorial_transition",
    )
    after = json.loads(
        sql(f"""select jsonb_build_object(
     'feed',(select count(*)from public.feed_items),
     'revisions',(select count(*)from public.visa_article_revisions where article_id='{article}'),
     'base',(select to_jsonb(r)from public.visa_article_revisions r where id='{state["base"]["revision_id"]}'),
     'rich',(select composition from private.rad_editorial_rich_revisions where revision_id='{state["base"]["revision_id"]}'),
     'fa',(select to_jsonb(h)from public.visa_article_heads h where article_id='{article}'and locale='fa'),
     'published',(select count(*)from public.visa_article_heads where article_id='{article}'and published_id is not null),
     'ancestry',(select count(*)from private.rad_structured_revision_ancestry where proposal_id='{proposal}'),
     'actor_receipts',(select count(*)from private.rad_research_review_versions where proposal_id='{proposal}'and actor_id='{actor}'and created_at is not null));
    """)
    )
    auth.require(
        all(before[k] == after[k] for k in ("feed", "base", "rich", "fa")),
        "original body/author/locale/Feed preserved",
    )
    auth.require(
        after["revisions"] == before["revisions"] + 1
        and after["published"] == 0
        and after["ancestry"] == 1
        and after["actor_receipts"] == 2,
        "one committed audited draft, no duplicate or publication",
    )
    auth.expect_success("POST", "/auth/v1/logout", token, label="local Admin logout")
    auth.expect_success(
        "POST", "/auth/v1/logout", user_token, label="local user logout"
    )
    print(
        "PASS: normal local Auth -> evidence-bound proposal -> persisted review -> one CMS draft -> logout/login/reopen; "
        "idempotency, stale/hash refusal, role/draft privacy, history/author/locale preservation, zero publication/Feed changes. "
        "SYNTHETIC LOCAL ACCEPTANCE ONLY; Production and paid research were not invoked."
    )


if __name__ == "__main__":
    main()
