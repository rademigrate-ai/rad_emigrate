"""Rehearse draft import only. Hosted/non-loopback databases are unconditionally refused."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import sqlite3
import subprocess
from contextlib import closing
from pathlib import Path
from urllib.parse import urlsplit

from .dataset import cms_payload, digest, read_jsonl, uid, validate_package
from .parser import HOSTS, normalize_url
from .quality import assess_references, assess_source
from .traceability import verify_graph

ADMIN = "f3a00000-0000-4000-8000-000000000001"
USER = "f3a00000-0000-4000-8000-000000000002"


def load_import(package_path, registry_path):
    validate_package(package_path, registry_path)
    package = json.loads(package_path.read_text(encoding="utf8"))
    root = package_path.parent.resolve()
    source_path = (root / package["source_file"]).resolve()
    if not source_path.is_relative_to(root):
        raise ValueError("source_path_escape")
    if (
        hashlib.sha256(source_path.read_bytes()).hexdigest()
        != package["source_file_sha256"]
    ):
        raise ValueError("source_file_hash")
    sources = read_jsonl(source_path)
    by_source = {s["source_id"]: s for s in sources}
    if len(by_source) != len(sources):
        raise ValueError("duplicate_source_id")
    if len({s["url"] for s in sources}) != len(sources):
        raise ValueError("duplicate_source_url")
    for s in sources:
        if (
            normalize_url(s["url"]) != s["url"]
            or urlsplit(s["url"]).hostname not in HOSTS
        ):
            raise ValueError("source_url_scope")
    articles = read_jsonl(root / package["payload_file"])
    registry = json.loads(registry_path.read_text(encoding="utf8"))
    catalog = set(package["destination_catalog_country_codes"])
    quality_sources = [{**s, "quality": assess_source(s)} for s in sources]
    assess_references(quality_sources)
    quality_by_source = {s["source_id"]: s["quality"] for s in quality_sources}
    assigned = set()
    for s in sources:
        if (
            s.get("publication_allowed") is not False
            or s.get("official_verification_status") != "not_verified"
            or s.get("human_review_status") != "not_reviewed"
        ):
            raise ValueError("unsafe_source_approval")
        if s["body_text"] and digest(s["body_text"]) != s["body_sha256"]:
            raise ValueError("source_body_hash")
    for a in articles:
        s = by_source[a["primary_source_id"]]
        create = a["wire"]["create_visa_article"]
        save = a["wire"]["save_visa_article_draft"]
        if (
            create["article_id"] != a["canonical_id"]
            or save["article_id"] != a["canonical_id"]
        ):
            raise ValueError("article_identity_mismatch")
        if save["locale"] != s["language"] or a["locale"] != s["language"]:
            raise ValueError("source_language_mismatch")
        if (
            digest(s["body_text"]) != s["body_sha256"]
            or s["body_sha256"] != a["body_sha256"]
        ):
            raise ValueError("source_body_hash")
        if s["publication_allowed"] is not False:
            raise ValueError("unsafe_source_approval")
        for section in a["wire"]["save_visa_article_draft"]["sections"]:
            for ref in section["evidence_refs"]:
                locator = re.search(r";chars=(\d+):(\d+)$", ref["locator"])
                if (
                    ref["snapshot_id"] != s["snapshot_id"]
                    or ref["claim_id"] is not None
                    or not ref["excerpt"]
                    or ref["excerpt"] not in s["body_text"]
                    or not locator
                ):
                    raise ValueError("citation_mapping")
                start, end = map(int, locator.groups())
                if (
                    not 0 <= start < end <= len(s["body_text"])
                    or ref["excerpt"] != s["body_text"][start : min(end, start + 4000)]
                ):
                    raise ValueError("citation_locator")
        # File hashes attest bytes, not the relationship between those bytes.
        # Reconstruct the loss-aware adapter from the original source so changed
        # text, omitted sections/references and forged catalog flags fail closed.
        ids = a["source_ids"]
        members = [by_source[i] for i in ids]
        if (
            not ids
            or len(set(ids)) != len(ids)
            or assigned.intersection(ids)
            or s["source_id"] not in ids
            or any(
                not m["complete_article_body"]
                or (
                    m["body_sha256"],
                    m["language"],
                    m["taxonomy"]["country_codes"],
                    m["taxonomy"]["pathway"],
                )
                != (
                    s["body_sha256"],
                    s["language"],
                    s["taxonomy"]["country_codes"],
                    s["taxonomy"]["pathway"],
                )
                for m in members
            )
        ):
            raise ValueError("source_group_mapping")
        assigned.update(ids)
        group = {
            "canonical_id": a["canonical_id"],
            "source_ids": sorted(ids),
            "source_urls": sorted(m["url"] for m in members),
            "country_code": s["taxonomy"]["country_code"],
            "country_codes": s["taxonomy"]["country_codes"],
            "pathway": s["taxonomy"]["pathway"],
            "topic": s["taxonomy"]["topic"],
            "conflicts": a["conflicts"],
        }
        expected = cms_payload(group, s, registry, catalog)
        quality = quality_by_source[s["source_id"]]
        expected["validation"]["blocking_errors"] = sorted(
            set(expected["validation"]["blocking_errors"] + quality["blocking_errors"])
        )
        expected["validation"]["warnings"] = sorted(
            set(expected["validation"]["warnings"] + quality["warnings"])
        )
        expected["validation"]["draft_payload_valid"] = not expected["validation"][
            "blocking_errors"
        ]
        if a != expected:
            raise ValueError("source_to_draft_semantic_mismatch")
    if "canonical_file" in package:
        identities_path = (root / package["identity_registry_file"]).resolve()
        if not identities_path.is_relative_to(root):
            raise ValueError("identity_registry_path_escape")
        if (
            hashlib.sha256(identities_path.read_bytes()).hexdigest()
            != package["identity_registry_sha256"]
        ):
            raise ValueError("identity_registry_hash")
        verify_graph(
            sources,
            read_jsonl(root / package["canonical_file"]),
            articles,
            json.loads(identities_path.read_text(encoding="utf8")),
        )
    return articles, by_source


def sqlite_import(connection, articles, sources):
    """Transactional content journal; does not stand in for Supabase/RLS verification."""
    connection.executescript("""CREATE TABLE IF NOT EXISTS plan3_documents(id TEXT PRIMARY KEY,url TEXT UNIQUE NOT NULL);
    CREATE TABLE IF NOT EXISTS plan3_snapshots(id TEXT PRIMARY KEY,document_id TEXT NOT NULL,hash TEXT NOT NULL,body TEXT NOT NULL,UNIQUE(document_id,hash));
    CREATE TABLE IF NOT EXISTS plan3_articles(id TEXT PRIMARY KEY,payload_hash TEXT NOT NULL,state TEXT NOT NULL CHECK(state='draft'));
    CREATE TABLE IF NOT EXISTS plan3_requests(key TEXT PRIMARY KEY,body_hash TEXT NOT NULL);""")
    stats = {"created": 0, "replayed": 0, "blocked": 0}
    with connection:
        for a in articles:
            if (
                a.get("publication_allowed") is not False
                or a.get("review_status") != "draft_not_reviewed"
            ):
                raise ValueError("draft_only_gate")
            if not a["validation"]["draft_payload_valid"]:
                stats["blocked"] += 1
                continue
            previous = connection.execute(
                "select payload_hash,state from plan3_articles where id=?",
                (a["canonical_id"],),
            ).fetchone()
            if previous and previous != (a["payload_sha256"], "draft"):
                raise ValueError("revision_conflict_requires_human_review")
            for endpoint, body in a["wire"].items():
                if endpoint not in ("create_visa_article", "save_visa_article_draft"):
                    raise ValueError("endpoint_allowlist")
                key = body["request_key"]
                body_hash = digest(body)
                old = connection.execute(
                    "select body_hash from plan3_requests where key=?", (key,)
                ).fetchone()
                if old and old[0] != body_hash:
                    raise ValueError("idempotency_conflict")
                connection.execute(
                    "insert or ignore into plan3_requests values(?,?)", (key, body_hash)
                )
            for sid in a["source_ids"]:
                s = sources[sid]
                old = connection.execute(
                    "select url from plan3_documents where id=?", (sid,)
                ).fetchone()
                if old and old[0] != s["url"]:
                    raise ValueError("source_identity_conflict")
                connection.execute(
                    "insert or ignore into plan3_documents values(?,?)", (sid, s["url"])
                )
                connection.execute(
                    "insert or ignore into plan3_snapshots values(?,?,?,?)",
                    (s["snapshot_id"], sid, s["body_sha256"], s["body_text"]),
                )
            connection.execute(
                "insert or ignore into plan3_articles values(?,?,?)",
                (a["canonical_id"], a["payload_sha256"], "draft"),
            )
            stats["replayed" if previous else "created"] += 1
    return stats


def sqlite_rehearsal(package_path, registry_path, db_path):
    articles, sources = load_import(package_path, registry_path)
    if db_path.exists():
        raise ValueError("rehearsal_requires_new_owned_database")
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with closing(sqlite3.connect(db_path)) as db:
        first = sqlite_import(db, articles, sources)
        before = {
            t: db.execute("select count(*) from " + t).fetchone()[0]
            for t in [
                "plan3_documents",
                "plan3_snapshots",
                "plan3_articles",
                "plan3_requests",
            ]
        }
        second = sqlite_import(db, articles, sources)
        after = {
            t: db.execute("select count(*) from " + t).fetchone()[0] for t in before
        }
        if before != after or second["created"] != 0:
            raise AssertionError("non_idempotent_replay")
    return {
        "backend": "SQLite journal only",
        "first": first,
        "second": second,
        "row_counts_unchanged_on_retry": before == after,
        "rows": after,
        "publication_writes": 0,
        "supabase_semantics_verified": False,
    }


def validate_runtime(db_url, marker, owner_checkout):
    p = urlsplit(db_url)
    if (
        p.scheme not in ("postgres", "postgresql")
        or p.hostname not in ("127.0.0.1", "localhost", "::1")
        or not p.port
        or p.query
        or p.fragment
        or p.path != "/postgres"
    ):
        raise ValueError("hosted_or_ambiguous_database_refused")
    identity = json.loads(marker.read_text(encoding="utf8"))
    if (
        identity["port"] != p.port
        or Path(identity["owner_checkout"]).resolve() != owner_checkout.resolve()
        or not identity["project"].startswith("rad_")
    ):
        raise ValueError("unowned_runtime")
    ports = json.loads(
        subprocess.check_output(
            [
                "docker",
                "inspect",
                "--format",
                "{{json .NetworkSettings.Ports}}",
                "supabase_db_" + identity["project"],
            ],
            text=True,
        )
    )
    if not any(int(x["HostPort"]) == p.port for x in ports.get("5432/tcp", [])):
        raise ValueError("container_port_owner_mismatch")
    return identity


def lit(value):
    return "'" + str(value).replace("'", "''") + "'"


def local_psql_environment(db_url):
    # libpq's PGHOSTADDR can override even an explicit URI host. Never inherit
    # service files, connection routing or session options from the host shell.
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith("PG")}
    env.update(
        PGCLIENTENCODING="UTF8",
        PGCONNECT_TIMEOUT="10",
        PGHOSTADDR="::1" if urlsplit(db_url).hostname == "::1" else "127.0.0.1",
    )
    return env


def postgres_rehearsal(
    package_path,
    registry_path,
    db_url,
    marker,
    psql,
    allow_disposable_write,
    limit=None,
):
    if not allow_disposable_write:
        raise ValueError("explicit_disposable_write_flag_required")
    root = Path(__file__).resolve().parents[2]
    identity = validate_runtime(db_url, marker, root)
    articles, sources = load_import(package_path, registry_path)
    articles = [a for a in articles if a["validation"]["draft_payload_valid"]]
    if limit is not None:
        articles = articles[:limit]
    if not articles:
        raise ValueError("no_valid_draft_payloads")
    # SQL runs only against the independently owned, loopback container checked above.
    command = [str(psql), "--dbname", db_url, "-XAtq", "-v", "ON_ERROR_STOP=1"]
    env = local_psql_environment(db_url)

    def sql(statement):
        p = subprocess.run(
            command,
            check=False,
            input=statement,
            capture_output=True,
            text=True,
            encoding="utf8",
            env=env,
            timeout=1800,
        )
        if p.returncode:
            # No database URL or credential is printed. SQL errors are local-only diagnostics.
            raise RuntimeError("owned_postgres_rehearsal_failed: " + p.stderr[-3500:])
        return p.stdout.strip()

    chosen = {sid: sources[sid] for a in articles for sid in a["source_ids"]}
    wanted = [
        {"id": s["source_id"], "url": s["url"], "hash": s["body_sha256"]}
        for s in chosen.values()
    ]
    existing = json.loads(
        sql(
            "begin transaction read only; select coalesce(jsonb_agg(jsonb_build_object('package_id',x.id,'id',d.id,'url',d.canonical_url,'snapshot_id',s.id,'body',s.normalized_text)),'[]'::jsonb) from jsonb_to_recordset("
            + lit(json.dumps(wanted))
            + "::jsonb) as x(id text,url text,hash text) join public.source_documents d on d.canonical_url=x.url or d.id=x.id::uuid left join public.source_snapshots s on s.document_id=d.id and s.content_hash=x.hash; commit;"
        )
    )
    mapping = {}
    for s in chosen.values():
        found = [v for v in existing if v["package_id"] == s["source_id"]]
        if len(found) > 1:
            raise ValueError("ambiguous_existing_source")
        prior = found[0] if found else None
        if prior and normalize_url(prior["url"]) != s["url"]:
            raise ValueError("source_identity_conflict")
        if prior and prior["snapshot_id"] and digest(prior["body"]) != s["body_sha256"]:
            raise ValueError("existing_snapshot_hash_mismatch")
        document_id = prior["id"] if prior else s["source_id"]
        snapshot_id = (
            prior["snapshot_id"]
            if prior and prior["snapshot_id"]
            else uid("snapshot:" + document_id + ":" + s["body_sha256"])
        )
        mapping[s["source_id"]] = {
            "document_id": document_id,
            "snapshot_id": snapshot_id,
        }
    statements = [
        "begin; set local standard_conforming_strings=on;",
        "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);",
        f"insert into auth.users(id,email) values('{ADMIN}','plan3-disposable-admin@example.invalid'),('{USER}','plan3-disposable-user@example.invalid');",
        f"update public.profiles set role='admin' where id='{ADMIN}';",
        "create temp table plan3_guard as select (select count(*) from public.feed_items) feed_count,(select count(*) from public.visa_article_revision_events where state='published') published_count;",
        "create temp table plan3_receipts(article_id uuid, first_result jsonb, replay_result jsonb);",
        "create temp table plan3_ai_guard(request jsonb, response jsonb);",
        "grant select,insert on plan3_guard,plan3_receipts to authenticated;",
    ]
    for locale in sorted({a["locale"] for a in articles}):
        example = next(a for a in articles if a["locale"] == locale)
        words = re.findall(r"[^\W\d_]{3,30}", example["title"])
        query = max(words, key=len) if words else "RAD"
        statements.append(
            "insert into plan3_ai_guard values("
            + lit(json.dumps({"query": query, "locale": locale}))
            + "::jsonb,public.retrieve_verified_official_claims("
            + lit(query)
            + ","
            + lit(locale)
            + ",null,null));"
        )
    for s in chosen.values():
        m = mapping[s["source_id"]]
        content_source_id = uid("content-source:" + s["url"])
        metadata = {
            "plan3_source_id": s["source_id"],
            "source_class": {
                "radvisa.com": "radvisa",
                "digivisa.ir": "digivisa",
                "radmohajer.ir": "radmohajer",
            }[s["domain"]],
            "verification_status": "unverified",
            "publication_allowed": False,
            "parser": s["parser_selector"],
        }
        # This legacy FK targets content_sources, not research_sources. Resolve an
        # existing exact URL first; never bind an article to an arbitrary host row.
        statements.append(
            "insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash) select "
            + ",".join(
                [
                    lit(content_source_id),
                    lit("RAD first-party source — unverified immigration content"),
                    lit("rad_official"),
                    lit(s["title"]),
                    lit(s["url"]),
                    lit(s["language"]),
                    lit(s["retrieved_at"]) + "::timestamptz",
                    lit(s["body_sha256"]),
                ]
            )
            + f" where not exists(select 1 from public.content_sources where url={lit(s['url'])}) on conflict(id) do nothing;"
        )
        statements.append(
            "insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash) values("
            + ",".join(
                [
                    lit(m["document_id"]),
                    lit(s["url"]),
                    f"(select id from public.content_sources where url={lit(s['url'])} order by created_at limit 1)",
                    lit("rad_official"),
                    lit(s["title"]),
                    lit(s["language"]),
                    lit(s["taxonomy"]["country_code"] or ""),
                    lit(s["body_sha256"]),
                ]
            )
            + ") on conflict(id) do nothing;"
        )
        statements.append(
            "insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata) values("
            + ",".join(
                [
                    lit(m["snapshot_id"]),
                    lit(m["document_id"]),
                    lit(s["body_sha256"]),
                    lit(s["body_text"]),
                    "200",
                    lit(s["retrieved_at"]),
                    lit(json.dumps(metadata, ensure_ascii=False)) + "::jsonb",
                ]
            )
            + ") on conflict(document_id,content_hash) do nothing;"
        )
        # First-party origin classification is descriptive URL provenance,
        # separate from inventory approval and official claim verification.
        statements.append(
            "select private.rad_classify_snapshot(" + lit(m["snapshot_id"]) + "::uuid);"
        )
    statements.extend(
        [
            "set local role authenticated;",
            f'select set_config(\'request.jwt.claims\',\'{{"role":"authenticated","sub":"{ADMIN}"}}\',true);',
        ]
    )
    for a in articles:
        create = copy.deepcopy(a["wire"]["create_visa_article"])
        save = copy.deepcopy(a["wire"]["save_visa_article_draft"])
        for section in save["sections"]:
            for ref in section["evidence_refs"]:
                ref["snapshot_id"] = mapping[a["primary_source_id"]]["snapshot_id"]
        # Rebinding an existing database snapshot is part of the deterministic wire input.
        save["request_key"] = uid(
            "resolved-draft:"
            + digest({k: v for k, v in save.items() if k != "request_key"})
        )
        c = lit(json.dumps(create, ensure_ascii=False))
        s = lit(json.dumps(save, ensure_ascii=False))
        statements.extend(
            [
                f"do $$ declare a jsonb;b jsonb;begin a:=public.create_visa_article({c}::jsonb);b:=public.create_visa_article({c}::jsonb);if a is null or a is distinct from b or a->'data'->>'article_id' is distinct from {lit(a['canonical_id'])} then raise exception 'create retry differs';end if;end $$;",
                f"insert into plan3_receipts values({lit(a['canonical_id'])},public.save_visa_article_draft({s}::jsonb),public.save_visa_article_draft({s}::jsonb));",
            ]
        )
    statements.append(
        "do $$ begin if exists(select 1 from plan3_receipts where first_result is null or first_result is distinct from replay_result or first_result->'data'->>'article_id' is distinct from article_id::text or first_result->'data'->>'revision' is distinct from '1' or coalesce(first_result->'data'->>'content_hash','') !~ '^[a-f0-9]{64}$' or first_result->'data'->>'editorial_state' is distinct from 'draft' or first_result->'data'->>'verification_state' is distinct from 'unverified') then raise exception 'draft or idempotency invariant failed';end if; end $$;"
    )
    # Read-only peer review found Plan 4's editor supplying this placeholder.
    # Prove the server rejects it; never relax the exact-revision/hash gate.
    statements.append(
        "do $$ declare result jsonb;begin select first_result->'data' into result from plan3_receipts order by article_id limit 1;begin perform public.submit_visa_article_review(jsonb_build_object('article_id',result->'article_id','revision_id',result->'revision_id','expected_revision',result->'revision','content_hash',repeat('0',64),'note','Synthetic disposable contract regression','request_key',"
        + lit(uid("plan3-placeholder-hash-negative-test"))
        + "));raise exception 'placeholder content hash accepted';exception when sqlstate 'PT409' then null;end;end $$;"
    )
    # Public search must not expose any of these unapproved drafts.
    for locale in sorted({a["locale"] for a in articles}):
        example = next(a for a in articles if a["locale"] == locale)
        words = re.findall(r"[^\W\d_]{3,30}", example["title"])
        request = {
            "query": max(words, key=len) if words else "RAD",
            "locale": locale,
            "country_codes": [],
            "pathway_slugs": [],
            "article_kind": None,
            "allow_locale_fallback": False,
            "cursor": None,
            "limit": 20,
        }
        statements.append(
            "do $$ declare response jsonb;begin response:=public.search_visa_articles("
            + lit(json.dumps(request))
            + "::jsonb);if exists(select 1 from jsonb_array_elements(response->'data'->'items')i join plan3_receipts r on r.article_id=(i->>'article_id')::uuid) then raise exception 'draft leaked through public search';end if;end $$;"
        )
    statements.extend(
        [
            f'select set_config(\'request.jwt.claims\',\'{{"role":"authenticated","sub":"{USER}"}}\',true);',
            "do $$ begin begin perform public.get_cms_article_draft("
            + lit(
                json.dumps(
                    {
                        "article_id": articles[0]["canonical_id"],
                        "locale": articles[0]["locale"],
                    }
                )
            )
            + "::jsonb);raise exception 'CMS draft leaked to ordinary user';exception when sqlstate 'PT403' then null;end;end $$;",
            "reset role;",
            "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);",
            "do $$ begin if exists(select 1 from plan3_ai_guard where response is distinct from public.retrieve_verified_official_claims(request->>'query',request->>'locale',null,null)) then raise exception 'draft affected public AI grounding';end if;end $$;",
            "do $$ begin if (select count(*) from public.feed_items)<>(select feed_count from plan3_guard) or (select count(*) from public.visa_article_revision_events where state='published')<>(select published_count from plan3_guard) or exists(select 1 from public.visa_article_heads h join plan3_receipts r on r.article_id=h.article_id where h.published_id is not null) then raise exception 'publication side effect';end if;end $$;",
            "select 'PLAN3_RESULT:'||jsonb_build_object('articles',count(*),'replayed_equal',bool_and(first_result=replay_result),'all_draft',bool_and(first_result->'data'->>'editorial_state'='draft'))::text from plan3_receipts;",
            "rollback;",
        ]
    )
    result = sql("\n".join(statements))
    line = next(
        result_line
        for result_line in result.splitlines()
        if result_line.startswith("PLAN3_RESULT:")
    )
    return {
        "backend": "owned Supabase/PostgreSQL",
        "runtime": identity,
        "result": json.loads(line.removeprefix("PLAN3_RESULT:")),
        "transaction_rolled_back": True,
        "ordinary_user_denied": True,
        "public_search_draft_isolation": True,
        "ai_grounding_unchanged": True,
        "placeholder_review_hash_rejected": True,
        "feed_and_publication_unchanged": True,
        "snapshot_rebinding": mapping,
        "source_documents_rehearsed": len(mapping),
        "first_party_origins_classified": True,
        "article_source_mapping": {
            a["canonical_id"]: {sid: mapping[sid] for sid in a["source_ids"]}
            for a in articles
        },
        "hosted_mutations": False,
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("mode", choices=["sqlite", "postgres"])
    p.add_argument("--package", type=Path, required=True)
    p.add_argument(
        "--registry", type=Path, default=Path("supabase/contracts/rad_v1.json")
    )
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--sqlite-db", type=Path)
    p.add_argument("--db-url")
    p.add_argument("--runtime-marker", type=Path)
    p.add_argument("--psql", type=Path, default=Path("psql"))
    p.add_argument("--allow-disposable-write", action="store_true")
    p.add_argument("--limit", type=int)
    a = p.parse_args()
    if a.mode == "sqlite":
        if a.sqlite_db is None:
            p.error("--sqlite-db required")
        result = sqlite_rehearsal(a.package, a.registry, a.sqlite_db)
    else:
        if not a.db_url or not a.runtime_marker:
            p.error("--db-url and --runtime-marker required")
        result = postgres_rehearsal(
            a.package,
            a.registry,
            a.db_url,
            a.runtime_marker,
            a.psql,
            a.allow_disposable_write,
            a.limit,
        )
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf8")
    print(
        json.dumps(
            {
                k: v
                for k, v in result.items()
                if k not in ("snapshot_rebinding", "article_source_mapping")
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
