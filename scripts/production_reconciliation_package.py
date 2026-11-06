"""Offline Production-specific additive draft preparation; never connects to a DB.

SQL rendering is offline and requires explicit isolated or future Production authorization.
Existing heads, revisions, authors and published pointers are never advanced.
The staging import RPC and its target marker are deliberately not used.
"""

import argparse
import copy
import gzip
import hashlib
import ipaddress
import json
import re
from collections import Counter
from pathlib import Path
from uuid import NAMESPACE_URL, UUID, uuid5

PROJECT = "inshddthftkhcdosoqcn"
COMMIT = "81f11ce176d9645ae0503e360e22ef6a414c355b"
RECEIPT_FIELDS = (
    "owner_authorization_sha256",
    "recovery_profile_sha256",
    "coordinated_backup_sha256",
    "restore_acceptance_sha256",
    "restore_endpoint_identity_sha256",
    "forward_package_sha256",
)
FORMAT = "RAD_PRODUCTION_ADDITIVE_DRAFT_PACKAGE_V3"
GENERATOR_AT_IMPORT = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
ADMIN_COMPAT_PATH = (
    Path(__file__).resolve().parents[1]
    / "supabase/migrations/20261102101305_rad_cms_detached_revision_allocator.sql"
)
ADMIN_COMPAT_BYTES = ADMIN_COMPAT_PATH.read_bytes()
ADMIN_COMPAT_SHA256 = hashlib.sha256(ADMIN_COMPAT_BYTES).hexdigest()
ADMIN_COMPAT_SQL = ADMIN_COMPAT_BYTES.decode("utf8")


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(value):
    return hashlib.sha256(
        value.encode("utf8") if isinstance(value, str) else value
    ).hexdigest()


def read_rows(path):
    with gzip.open(path, "rt", encoding="utf8") as stream:
        for line in stream:
            if line.strip():
                yield json.loads(line)


def write_rows(path, rows):
    with (
        path.open("wb") as raw,
        gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as stream,
    ):
        for row in rows:
            stream.write((canonical(row) + "\n").encode("utf8"))


def unique_rows(rows):
    result = {}
    for row in rows:
        key = (row["article_id"], row.get("locale", row.get("item", {}).get("locale")))
        if key in result:
            raise ValueError("duplicate_article_locale")
        result[key] = row
    return result


def make_operation(ready, current, operation_class, review_case=None):
    item = ready["item"]
    body = item["draft_request"]
    if (
        item.get("editorial_state") != "draft"
        or item.get("verification_state") != "unverified"
        or item.get("publication_allowed") is not False
        or item.get("published") is not False
        or item.get("reviewer_id") is not None
        or body.get("merge_manifest_id") is not None
        or body.get("related_article_ids") != []
        or body.get("expected_revision") != 0
        or body.get("article_id") != item["article_id"]
        or body.get("locale") != item["locale"]
    ):
        raise ValueError("draft_only_payload_required")
    UUID(item["article_id"])
    if item["locale"] not in ("fa", "en"):
        raise ValueError("draft_only_locale")
    actions = {
        "NEW_KEY_DRAFT_CANDIDATE": "INSERT_INITIAL_UNVERIFIED_DRAFT",
        "CORE_SEMANTIC_MATCH_RICH_PROJECTION_RECONCILIATION": "INSERT_DETACHED_UNVERIFIED_DRAFT",
        "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT": "PENDING_HUMAN_RECONCILIATION",
    }
    action = actions[operation_class]
    if (current is None) != (action == "INSERT_INITIAL_UNVERIFIED_DRAFT"):
        raise ValueError("current_head_class_mismatch")
    value = {"item": item, "sources": ready["sources"]}
    payload_sha = digest(canonical(value))
    op = {
        "article_id": item["article_id"],
        "locale": item["locale"],
        "action": action,
        "operation_class": operation_class,
        "payload_sha256": payload_sha,
        "provenance_sha256": digest(canonical(ready["sources"])),
        "rich_composition_sha256": digest(
            canonical({k: v for k, v in item.items() if k != "draft_request"})
        ),
        "expected_current": current,
        "advance_existing_head": False,
        "publication_allowed": False,
        "revision_id": str(
            uuid5(
                NAMESPACE_URL,
                "rad-production-detached:" + payload_sha + ":" + canonical(current),
            )
        ),
        "payload": value,
    }
    if review_case is not None:
        if (
            review_case.get("article_id") != item["article_id"]
            or review_case.get("locale") != item["locale"]
            or review_case.get("payload_sha256")
            != digest(json.dumps(value, ensure_ascii=False, sort_keys=True))
            or review_case.get("current_head") != (current or {}).get("head_id")
            or review_case.get("current_body_md5") != (current or {}).get("body_md5")
        ):
            raise ValueError("review_case_payload_or_head_binding_mismatch")
        case_bound = dict(review_case)
        case_sha = case_bound.pop("case_sha256", None)
        # Review cases deliberately retain their evidence producer's canonicalization.
        if (
            digest(json.dumps(case_bound, ensure_ascii=False, sort_keys=True))
            != case_sha
        ):
            raise ValueError("review_case_hash_mismatch")
        op["review_case"] = copy.deepcopy(review_case)
    op["operation_id"] = digest(
        canonical({k: v for k, v in op.items() if k != "payload"})
    )
    return op


def resolve_operation(operation, decision=None):
    op = copy.deepcopy(operation)
    if op["action"] != "PENDING_HUMAN_RECONCILIATION":
        if decision is not None:
            raise ValueError("unexpected_human_decision")
        return op
    if decision is None:
        return op
    current = op["expected_current"]
    if (
        decision.get("payload_sha256") != op["payload_sha256"]
        or decision.get("current_head") != current["head_id"]
        or decision.get("current_body_md5") != current["body_md5"]
        or not re.fullmatch("[a-f0-9]{64}", decision.get("review_receipt_sha256", ""))
    ):
        raise ValueError("decision_payload_binding_required")
    if "review_case" in op and (
        decision.get("case_sha256") != op["review_case"]["case_sha256"]
        or decision.get("review_payload_sha256") != op["review_case"]["payload_sha256"]
        or decision.get("desired_article_sha256")
        != op["review_case"]["desired_article_sha256"]
    ):
        raise ValueError("decision_review_case_binding_required")
    UUID(decision["reviewer_id"])
    if decision["decision"] not in ("create_detached_draft", "keep_current"):
        raise ValueError("decision_must_preserve_current_head")
    op["action"] = (
        "INSERT_DETACHED_UNVERIFIED_DRAFT"
        if decision["decision"] == "create_detached_draft"
        else "NOOP_KEEP_CURRENT"
    )
    op["human_decision"] = copy.deepcopy(decision)
    return op


def validate_authorization(
    auth, package_sha, execution_scope="approved_isolated_restore"
):
    endpoint = auth.get("restore_endpoint", {})
    production = execution_scope == "approved_production"
    valid_endpoint = False
    try:
        address = ipaddress.ip_address(endpoint.get("server_addr", ""))
        valid_endpoint = (
            not address.is_loopback if production else str(address) == "127.0.0.1"
        )
    except (ValueError, TypeError):
        pass
    valid = (
        auth.get("project_id") == PROJECT
        and auth.get("source_commit") == COMMIT
        and execution_scope in ("approved_isolated_restore", "approved_production")
        and auth.get("execution_scope") == execution_scope
        and auth.get("package_sha256") == package_sha
        and auth.get("actor_role") in ("admin", "super_admin")
        and all(
            isinstance(auth.get(f), str) and re.fullmatch("[a-f0-9]{64}", auth[f])
            for f in RECEIPT_FIELDS
        )
        and valid_endpoint
        and isinstance(endpoint.get("server_port"), int)
        and 1024 <= endpoint["server_port"] <= 65535
        and isinstance(endpoint.get("database"), str)
        and bool(endpoint["database"])
        and isinstance(endpoint.get("system_identifier"), str)
        and re.fullmatch("[0-9]{10,30}", endpoint.get("system_identifier", ""))
    )
    try:
        UUID(auth.get("actor_id", ""))
    except (ValueError, TypeError, AttributeError):
        valid = False
    if not valid:
        raise ValueError(
            "restore_authorization_required_exact_target_actor_package_recovery_and_owner"
        )
    if production:
        if (
            auth.get("recovery_evidence_kind") != "verified_real_production_checkpoint"
            or auth.get("authorization_kind") != "explicit_future_owner_approval"
            or auth.get("production_api_origin")
            != "https://" + PROJECT + ".supabase.co"
        ):
            raise ValueError(
                "production_real_checkpoint_and_explicit_owner_authorization_required"
            )
        if (
            auth.get("source_commit_role") != "historical_base"
            or auth.get("generator_sha256") != GENERATOR_AT_IMPORT
            or not isinstance(auth.get("final_candidate_commit"), str)
            or not re.fullmatch("[a-f0-9]{40}", auth["final_candidate_commit"])
            or auth["final_candidate_commit"] == COMMIT
        ):
            raise ValueError(
                "production_final_candidate_and_generator_binding_required"
            )
        for field in RECEIPT_FIELDS:
            receipt = auth.get("receipt_files", {}).get(field)
            if (
                not isinstance(receipt, str)
                or not Path(receipt).is_file()
                or digest(Path(receipt).read_bytes()) != auth[field]
            ):
                raise ValueError(
                    "production_receipt_file_hash_binding_required:" + field
                )
        delivery = auth.get("final_delivery_receipt_file")
        delivery_sha = auth.get("final_delivery_receipt_sha256", "")
        if (
            not isinstance(delivery, str)
            or not Path(delivery).is_file()
            or not isinstance(delivery_sha, str)
            or not re.fullmatch("[a-f0-9]{64}", delivery_sha)
            or digest(Path(delivery).read_bytes()) != delivery_sha
        ):
            raise ValueError("production_final_delivery_receipt_file_binding_required")
        try:
            delivered = json.loads(Path(delivery).read_text("utf8"))
        except (ValueError, UnicodeError):
            raise ValueError("production_final_delivery_json_required") from None
        if (
            delivered.get("head_sha") != auth["final_candidate_commit"]
            or delivered.get("project_id") != PROJECT
            or delivered.get("production_package_sha256") != package_sha
            or delivered.get("code_sha256", {}).get(
                "scripts/production_reconciliation_package.py"
            )
            != GENERATOR_AT_IMPORT
            or delivered.get("code_sha256", {}).get(
                "supabase/migrations/20261102101305_rad_cms_detached_revision_allocator.sql"
            )
            != ADMIN_COMPAT_SHA256
        ):
            raise ValueError("production_final_delivery_content_binding_required")


def seal_plan(plan, operations):
    """Bind the complete operations, including every expected-current guard."""
    plan = copy.deepcopy(plan)
    if digest(Path(__file__).read_bytes()) != GENERATOR_AT_IMPORT:
        raise ValueError("generator_changed_during_run")
    plan.update(format=FORMAT, project_id=PROJECT, source_commit=COMMIT)
    plan["source_commit_role"] = "historical_base"
    plan["generator_sha256"] = GENERATOR_AT_IMPORT
    plan["admin_revision_allocator_sql_sha256"] = ADMIN_COMPAT_SHA256
    plan["operation_bindings"] = [
        {k: v for k, v in o.items() if k != "payload"} for o in operations
    ]
    plan["package_sha256"] = digest(canonical(plan))
    return plan


def validate_package(plan, operations):
    bound = copy.deepcopy(plan)
    expected = bound.pop("package_sha256", None)
    if (
        plan.get("format") != FORMAT
        or plan.get("project_id") != PROJECT
        or plan.get("source_commit") != COMMIT
        or plan.get("generator_sha256") != digest(Path(__file__).read_bytes())
        or plan.get("admin_revision_allocator_sql_sha256")
        != digest(ADMIN_COMPAT_PATH.read_bytes())
        or digest(canonical(bound)) != expected
    ):
        raise ValueError("package_plan_hash_mismatch")
    unique_rows(operations)
    if plan.get("operation_bindings") != [
        {k: v for k, v in o.items() if k != "payload"} for o in operations
    ]:
        raise ValueError("package_operation_binding_mismatch")
    for op in operations:
        ready = op["payload"]
        rebuilt = make_operation(
            ready, op["expected_current"], op["operation_class"], op.get("review_case")
        )
        if rebuilt != op:
            raise ValueError("package_operation_integrity_mismatch")


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def dollar_tag(label, data):
    tag = "$rad" + label + digest(data)[:16] + "$"
    while tag in data:
        tag = tag[:-1] + "x$"
    return tag


ENGINE = r"""
-- All following guards and writes execute in the caller's one transaction.
-- GUCs are operator assertions; endpoint/backup evidence is bound externally.
set local search_path=pg_catalog;
set local standard_conforming_strings=on;
set local timezone='UTC';
set local lock_timeout='5s';
set local statement_timeout='600s';
lock table auth.users,public.profiles,public.visa_articles,public.visa_article_heads,
 public.visa_article_revisions,public.visa_article_sections,public.visa_article_revision_events,
 public.source_documents,public.source_snapshots,public.content_sources,
 private.rad_editorial_catalog,private.rad_editorial_rich_revisions,private.visa_source_origins in share row exclusive mode;
create temporary table rad_preserved(table_name text not null,row_data jsonb not null) on commit drop;
do $capture$ declare t text; begin
 foreach t in array array['auth.users','public.profiles','public.source_documents','public.source_snapshots',
 'public.content_sources','public.visa_articles','public.visa_article_revisions','public.visa_article_heads',
 'public.visa_article_sections','public.visa_article_revision_events',
 'private.rad_editorial_catalog','private.rad_editorial_rich_revisions','private.visa_source_origins'] loop
 execute format('insert into pg_temp.rad_preserved select %L,to_jsonb(t) from %s t',t,t);
 end loop;
end $capture$;
create table if not exists private.rad_production_reconciliation_journal(
 package_sha256 text not null,operation_id text not null,payload_sha256 text not null,
 article_id uuid not null,locale text not null,revision_id uuid not null references public.visa_article_revisions(id),
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default now(),
 primary key(package_sha256,operation_id));
alter table private.rad_production_reconciliation_journal enable row level security;
revoke all on private.rad_production_reconciliation_journal from public,anon,authenticated,service_role;
insert into pg_temp.rad_preserved select 'private.rad_production_reconciliation_journal',to_jsonb(j)
 from private.rad_production_reconciliation_journal j;
create table if not exists private.rad_production_reconciliation_created_rows(
 package_sha256 text not null,table_name text not null,row_key jsonb not null,row_sha256 text not null,
 primary key(package_sha256,table_name,row_key));
create table if not exists private.rad_production_reconciliation_fingerprints(
 package_sha256 text not null,table_name text not null,row_count bigint not null,row_sha256 text not null,
 primary key(package_sha256,table_name));
create table if not exists private.rad_production_reconciliation_applications(
 package_sha256 text primary key,actor_id uuid not null,human_decisions_sha256 text not null,catalog_sha256 text not null,created_at timestamptz not null default now());
create table if not exists private.rad_production_reconciliation_rollbacks(
 package_sha256 text primary key,actor_id uuid not null,authorization_sha256 text not null,
 deleted_rows bigint not null,created_at timestamptz not null default now());
alter table private.rad_production_reconciliation_created_rows enable row level security;
alter table private.rad_production_reconciliation_fingerprints enable row level security;
alter table private.rad_production_reconciliation_applications enable row level security;
alter table private.rad_production_reconciliation_rollbacks enable row level security;
revoke all on private.rad_production_reconciliation_created_rows,private.rad_production_reconciliation_fingerprints,
 private.rad_production_reconciliation_applications,private.rad_production_reconciliation_rollbacks from public,anon,authenticated,service_role;
"""

EVENT_CALLBACK_STATE = r"""encode(extensions.digest(jsonb_build_object(
 'evtname',e.evtname,'evtevent',e.evtevent,'enabled',e.evtenabled::text,'tags',e.evttags,
 'function_identity',fn.nspname||'.'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
 'function_source_md5',md5(p.prosrc),'function_settings',p.proconfig,'function_owner',owner.rolname,
 'security_definer',p.prosecdef,'function_language',lang.lanname)::text,'sha256'),'hex')"""


def validate_callback_policy(authorization, package_sha, operation):
    policy = authorization.get("approved_ddl_event_callbacks", [])
    if not isinstance(policy, list):
        raise ValueError("ddl_callback_policy_list_required")
    seen = set()
    for item in policy:
        if (
            not isinstance(item, dict)
            or set(item) != {"evtname", "callback_state_sha256"}
            or not isinstance(item["evtname"], str)
            or not item["evtname"]
            or len(item["evtname"]) > 63
            or item["evtname"] in seen
            or not isinstance(item["callback_state_sha256"], str)
            or not re.fullmatch("[a-f0-9]{64}", item["callback_state_sha256"])
        ):
            raise ValueError("ddl_callback_exact_state_policy_required")
        seen.add(item["evtname"])
    if not policy:
        return policy
    receipt = authorization.get("ddl_event_callback_review_receipt_file")
    expected = authorization.get("ddl_event_callback_review_receipt_sha256", "")
    if (
        not isinstance(receipt, str)
        or not Path(receipt).is_file()
        or not isinstance(expected, str)
        or not re.fullmatch("[a-f0-9]{64}", expected)
        or digest(Path(receipt).read_bytes()) != expected
    ):
        raise ValueError("ddl_callback_owner_review_receipt_file_required")
    reviewed = json.loads(Path(receipt).read_text("utf8"))
    required = {
        "schema_version": 1,
        "project_id": PROJECT,
        "package_sha256": package_sha,
        "generator_sha256": GENERATOR_AT_IMPORT,
        "reviewer_id": authorization["actor_id"],
        "operation": operation,
        "approved_policy_sha256": digest(canonical(policy)),
        "reviewed_no_external_row_mutation": True,
    }
    if any(reviewed.get(k) != v for k, v in required.items()):
        raise ValueError("ddl_callback_owner_review_content_binding_required")
    return policy


def callback_guard_sql(policy):
    return (
        "if exists(select 1 from pg_event_trigger e join pg_proc p on p.oid=e.evtfoid join pg_namespace fn on fn.oid=p.pronamespace join pg_roles owner on owner.oid=p.proowner join pg_language lang on lang.oid=p.prolang where e.evtenabled<>'D'and not exists(select 1 from jsonb_array_elements("
        + literal(canonical(policy))
        + "::jsonb)approved where approved->>'evtname'=e.evtname::text and approved->>'callback_state_sha256'="
        + EVENT_CALLBACK_STATE
        + "))then raise exception 'DDL_EVENT_TRIGGER_REVIEW_REQUIRED';end if;"
    )


CATALOG_QUERY = r"""
select encode(extensions.digest(coalesce(string_agg(component,E'\n' order by component),''),'sha256'),'hex')from(
 select 'trigger:'||pg_get_triggerdef(t.oid)||':'||t.tgenabled::text component from pg_trigger t join pg_class c on c.oid=t.tgrelid
 join pg_namespace n on n.oid=c.relnamespace where n.nspname not like 'pg_%' and n.nspname<>'information_schema'
 union all select 'rule:'||pg_get_ruledef(r.oid)||':'||r.ev_enabled::text from pg_rewrite r join pg_class c on c.oid=r.ev_class
 join pg_namespace n on n.oid=c.relnamespace where n.nspname not like 'pg_%' and n.nspname<>'information_schema'
 union all select 'function:'||pg_get_functiondef(p.oid)||':'||p.proowner::text||':'||coalesce(p.proacl::text,'')
 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.prokind in('f','p')and n.nspname not like 'pg_%' and n.nspname<>'information_schema'
 union all select 'constraint:'||n.nspname||'.'||c.relname||':'||k.conname||':'||pg_get_constraintdef(k.oid)
 from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace
 where n.nspname not like 'pg_%'and n.nspname<>'information_schema'
 union all select 'eventtrigger:'||e.evtname::text||':'||e.evtevent::text||':'||e.evtfoid::text||':'||e.evtenabled::text||':'||coalesce(e.evttags::text,'')from pg_event_trigger e)catalog_state
"""

DELETE_GUARD = r"""
 if exists(select 1 from pg_trigger t join pg_proc p on p.oid=t.tgfoid join pg_namespace pn on pn.oid=p.pronamespace
  join pg_language l on l.oid=p.prolang where not t.tgisinternal and t.tgenabled<>'D' and (t.tgtype::integer&8)<>0
  and t.tgrelid in(select distinct j.table_name::regclass from private.rad_production_reconciliation_created_rows j where j.package_sha256=pkg)
  and not exists(select 1 from(values
   ('public.visa_article_revision_events','visa_event_immutable','rad_immutable',27,false,'2423889fe70f234d5225ba638b15a545'),
   ('public.visa_article_revisions','visa_revision_immutable','rad_immutable',27,false,'2423889fe70f234d5225ba638b15a545'),
   ('public.visa_article_sections','visa_section_immutable','rad_immutable',27,false,'2423889fe70f234d5225ba638b15a545'),
   ('public.source_snapshots','rad_snapshot_immutable','rad_immutable',27,false,'2423889fe70f234d5225ba638b15a545'),
   ('private.visa_source_origins','visa_origins_immutable','rad_immutable',27,false,'2423889fe70f234d5225ba638b15a545'),
   ('public.content_sources','sources_audit','audit_content_change',29,true,'b6976ae9cc3d67304311bf39ff28ff11'),
   ('public.visa_article_heads','rad_article_deletion_search','rad_remove_article_search',9,true,'06620eab842202f9833c97381d872fdb'))
   g(table_name,trigger_name,function_name,event_type,security_definer,body_md5)
   where t.tgrelid=g.table_name::regclass and t.tgname=g.trigger_name and pn.nspname='private'and p.proname=g.function_name
   and t.tgtype=g.event_type and p.prosecdef=g.security_definer and md5(p.prosrc)=g.body_md5
   and l.lanname='plpgsql'and p.proconfig=array['search_path=""']::text[]and p.proowner=(select oid from pg_roles where rolname='postgres')
   and t.tgqual is null and octet_length(t.tgargs)=0))then raise exception 'COMPENSATION_UNTRUSTED_DELETE_TRIGGER';end if;
 if exists(select 1 from pg_rewrite r where r.ev_type='4'and r.ev_enabled<>'D'
  and r.ev_class in(select distinct j.table_name::regclass from private.rad_production_reconciliation_created_rows j where j.package_sha256=pkg))
 then raise exception 'COMPENSATION_UNTRUSTED_DELETE_RULE';end if;
 if exists(select 1 from pg_trigger t where not t.tgisinternal and t.tgenabled<>'D'
  and t.tgrelid in('public.admin_audit_logs'::regclass,'public.visa_article_search_documents'::regclass,'private.rad_search_version'::regclass))
 or exists(select 1 from pg_rewrite r where r.ev_enabled<>'D'and r.ev_type<>'1'
  and r.ev_class in('public.admin_audit_logs'::regclass,'public.visa_article_search_documents'::regclass,'private.rad_search_version'::regclass))
 then raise exception 'COMPENSATION_UNTRUSTED_CALLBACK_SIDE_EFFECT';end if;
"""


FINALIZE_SQL = r"""
do $rad_finalize$ declare pkg text:=PACKAGE_HASH;t text;keys text[];ct bigint;fingerprint text;begin
 if exists(select 1 from private.rad_production_reconciliation_rollbacks where package_sha256=pkg) then raise exception 'PACKAGE_PREVIOUSLY_ROLLED_BACK';end if;
 if not exists(select 1 from private.rad_production_reconciliation_journal where package_sha256=pkg)then return;end if;
 if exists(select 1 from private.rad_production_reconciliation_applications where package_sha256=pkg
  and (actor_id<>ACTOR_ID::uuid or human_decisions_sha256<>DECISION_HASH)) then raise exception 'APPLICATION_DECISION_SET_CONFLICT';end if;
 if exists(select 1 from private.rad_production_reconciliation_applications where package_sha256=pkg)then return;end if;
 foreach t in array array['public.content_sources','public.source_documents','public.source_snapshots',
  'public.visa_articles','public.visa_article_revisions','public.visa_article_heads','public.visa_article_sections',
  'public.visa_article_revision_events','private.rad_editorial_catalog','private.rad_editorial_rich_revisions','private.visa_source_origins',
  'private.rad_production_reconciliation_journal']loop
  select array_agg(a.attname order by u.ordinality) into keys from pg_index i
   cross join lateral unnest(i.indkey)with ordinality u(attnum,ordinality)
   join pg_attribute a on a.attrelid=i.indrelid and a.attnum=u.attnum where i.indrelid=t::regclass and i.indisprimary;
  if keys is null then raise exception 'COMPENSATION_PRIMARY_KEY_REQUIRED: %',t;end if;
  execute format('insert into private.rad_production_reconciliation_created_rows select $1,%L,
   (select jsonb_object_agg(k,to_jsonb(x)->k) from unnest($2)k),encode(extensions.digest(to_jsonb(x)::text,''sha256''),''hex'')
   from %s x where not exists(select 1 from pg_temp.rad_preserved b where b.table_name=%L and b.row_data=to_jsonb(x))
   on conflict do nothing',t,t,t)using pkg,keys;
 end loop;
 -- Conservative compensation: any later application write or new reference
 -- changes a global fingerprint and blocks deletion, even if unrelated.
 for t in select format('%I.%I',n.nspname,c.relname)from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in('public','private')and c.relkind in('r','p')and not(n.nspname='private'and c.relname in('rad_production_reconciliation_journal','rad_production_reconciliation_created_rows','rad_production_reconciliation_fingerprints','rad_production_reconciliation_applications','rad_production_reconciliation_rollbacks')) order by 1 loop
  execute format('lock table %s in share row exclusive mode',t);
  execute format('select count(*),encode(extensions.digest(coalesce(string_agg(v,E''\n'' order by v),''''),''sha256''),''hex'')
   from(select to_jsonb(x)::text v from %s x)q',t)into ct,fingerprint;
  insert into private.rad_production_reconciliation_fingerprints values(pkg,t,ct,fingerprint)on conflict do nothing;
 end loop;
 insert into private.rad_production_reconciliation_applications(package_sha256,actor_id,human_decisions_sha256,catalog_sha256)
 values(pkg,ACTOR_ID::uuid,DECISION_HASH,(CATALOG_QUERY))on conflict do nothing;
end $rad_finalize$;
"""

ROLLBACK_SQL = r"""
do $rad_compensate$ declare pkg text:=PACKAGE_HASH;t text;ct bigint;fingerprint text;expected record;own record;
 constraint_row record;join_condition text;child_table text;parent_table text;unowned_reference boolean;
 total bigint:=0;changed bigint;table_count bigint:=0;begin
 if exists(select 1 from private.rad_production_reconciliation_rollbacks where package_sha256=pkg
  and actor_id=ACTOR_ID::uuid and authorization_sha256=ROLLBACK_AUTH_HASH)then return;end if;
 if not exists(select 1 from private.rad_production_reconciliation_applications where package_sha256=pkg
  and actor_id=ACTOR_ID::uuid and human_decisions_sha256=DECISION_HASH)then raise exception 'COMPENSATION_APPLICATION_BINDING_REQUIRED';end if;
 for t in select format('%I.%I',n.nspname,c.relname)from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname in('public','private')and c.relkind in('r','p')and not(n.nspname='private'and c.relname in('rad_production_reconciliation_journal','rad_production_reconciliation_created_rows','rad_production_reconciliation_fingerprints','rad_production_reconciliation_applications','rad_production_reconciliation_rollbacks')) order by 1 loop
  execute format('lock table %s in share row exclusive mode',t);table_count:=table_count+1;
  execute format('select count(*),encode(extensions.digest(coalesce(string_agg(v,E''\n'' order by v),''''),''sha256''),''hex'')
   from(select to_jsonb(x)::text v from %s x)q',t)into ct,fingerprint;
  select * into expected from private.rad_production_reconciliation_fingerprints f where f.package_sha256=pkg and f.table_name=t;
  if not found or expected.row_count<>ct or expected.row_sha256<>fingerprint then raise exception 'COMPENSATION_LATER_WRITE_OR_REFERENCE: %',t;end if;
 end loop;
 if table_count<>(select count(*)from private.rad_production_reconciliation_fingerprints where package_sha256=pkg)
 then raise exception 'COMPENSATION_TABLE_SET_CHANGED';end if;
 if exists(select 1 from pg_constraint fk join pg_class child on child.oid=fk.conrelid
  join pg_namespace ns on ns.oid=child.relnamespace where fk.contype='f' and (ns.nspname not in('public','private')or (ns.nspname='private' and child.relname in('rad_production_reconciliation_created_rows','rad_production_reconciliation_fingerprints','rad_production_reconciliation_applications','rad_production_reconciliation_rollbacks')))
  and fk.confrelid in(select distinct j.table_name::regclass from private.rad_production_reconciliation_created_rows j where j.package_sha256=pkg))
 then raise exception 'COMPENSATION_EXTERNAL_FK_BOUNDARY';end if;
 DELETE_GUARD
 if (CATALOG_QUERY) is distinct from (select catalog_sha256 from private.rad_production_reconciliation_applications where package_sha256=pkg)
 then raise exception 'COMPENSATION_CATALOG_DRIFT';end if;
 -- Check actual referencing rows, including preexisting NOT VALID/replica
 -- orphans that became valid when this package inserted their parent.
 for constraint_row in select k.* from pg_constraint k where k.contype='f'and k.confrelid in(
  select distinct j.table_name::regclass from private.rad_production_reconciliation_created_rows j where j.package_sha256=pkg)loop
  child_table:=constraint_row.conrelid::regclass::text;parent_table:=constraint_row.confrelid::regclass::text;
  select string_agg(format('child.%I=parent.%I',ca.attname,pa.attname),' and 'order by ck.position)into join_condition
   from unnest(constraint_row.conkey)with ordinality ck(attnum,position)
   join pg_attribute ca on ca.attrelid=constraint_row.conrelid and ca.attnum=ck.attnum
   join pg_attribute pa on pa.attrelid=constraint_row.confrelid and pa.attnum=constraint_row.confkey[ck.position::integer];
  if join_condition is null then raise exception 'COMPENSATION_FK_KEY_UNRESOLVED';end if;
  execute format('select exists(select 1 from %s child join %s parent on %s
   join private.rad_production_reconciliation_created_rows owned_parent
    on owned_parent.package_sha256=$1 and owned_parent.table_name=$2 and to_jsonb(parent)@>owned_parent.row_key
   where not exists(select 1 from private.rad_production_reconciliation_created_rows owned_child
    where owned_child.package_sha256=$1 and owned_child.table_name=$3 and to_jsonb(child)@>owned_child.row_key
     and encode(extensions.digest(to_jsonb(child)::text,''sha256''),''hex'')=owned_child.row_sha256))',
   child_table,parent_table,join_condition)into unowned_reference using pkg,parent_table,child_table;
  if unowned_reference then raise exception 'COMPENSATION_UNOWNED_FK_REFERENCE: %',constraint_row.conname;end if;
 end loop;
 for own in select * from private.rad_production_reconciliation_created_rows where package_sha256=pkg loop
  execute format('select count(*)from %s x where to_jsonb(x)@>$1 and encode(extensions.digest(to_jsonb(x)::text,''sha256''),''hex'')=$2',own.table_name)
   into ct using own.row_key,own.row_sha256;
  if ct<>1 then raise exception 'COMPENSATION_OWNED_ROW_CHANGED';end if;
 end loop;
 -- These five append-only guards are disabled only inside this locked,
 -- exact-state compensating transaction and restored before commit.
 if exists(select 1 from(values('public.visa_article_revision_events','visa_event_immutable'),
  ('public.visa_article_revisions','visa_revision_immutable'),('public.visa_article_sections','visa_section_immutable'),
  ('public.source_snapshots','rad_snapshot_immutable'),('private.visa_source_origins','visa_origins_immutable'))g(table_name,trigger_name)
  left join pg_trigger t on t.tgrelid=g.table_name::regclass and t.tgname=g.trigger_name
  where t.oid is null or t.tgfoid<>'private.rad_immutable()'::regprocedure or t.tgenabled<>'O')
 then raise exception 'COMPENSATION_IMMUTABILITY_GUARD_CHANGED';end if;
 alter table public.visa_article_revision_events disable trigger visa_event_immutable;
 alter table public.visa_article_revisions disable trigger visa_revision_immutable;
 alter table public.visa_article_sections disable trigger visa_section_immutable;
 alter table public.source_snapshots disable trigger rad_snapshot_immutable;
 alter table private.visa_source_origins disable trigger visa_origins_immutable;
 foreach t in array array['private.rad_production_reconciliation_journal','public.visa_article_heads','public.visa_article_revision_events','public.visa_article_sections',
  'private.rad_editorial_rich_revisions','private.rad_editorial_catalog','public.visa_article_revisions','public.visa_articles',
  'private.visa_source_origins','public.source_snapshots','public.source_documents','public.content_sources']loop
  execute format('delete from %s x using private.rad_production_reconciliation_created_rows j
   where j.package_sha256=$1 and j.table_name=%L and to_jsonb(x)@>j.row_key
   and encode(extensions.digest(to_jsonb(x)::text,''sha256''),''hex'')=j.row_sha256',t,t)using pkg;
  get diagnostics changed=row_count;total:=total+changed;
 end loop;
 if total<>(select count(*)from private.rad_production_reconciliation_created_rows where package_sha256=pkg)
 then raise exception 'COMPENSATION_OWNED_DELETE_COUNT_CONFLICT';end if;
 alter table public.visa_article_revision_events enable trigger visa_event_immutable;
 alter table public.visa_article_revisions enable trigger visa_revision_immutable;
 alter table public.visa_article_sections enable trigger visa_section_immutable;
 alter table public.source_snapshots enable trigger rad_snapshot_immutable;
 alter table private.visa_source_origins enable trigger visa_origins_immutable;
 insert into private.rad_production_reconciliation_rollbacks(package_sha256,actor_id,authorization_sha256,deleted_rows)
 values(pkg,ACTOR_ID::uuid,ROLLBACK_AUTH_HASH,total);
end $rad_compensate$;
"""

# These readers expose only revisions created by this package, after the same
# profile-based human Admin check as the existing CMS. They never adopt a head.
READERS_SQL = r"""
create or replace function public.list_production_reconciliation_drafts(
 p_package_sha256 text,p_after_operation_id text default '',p_limit integer default 50)
returns jsonb language plpgsql security definer set search_path='' as $queue$
declare items jsonb;begin
 perform private.rad_require_admin();
 if p_package_sha256 is null or p_package_sha256 !~ '^[a-f0-9]{64}$'
 or p_after_operation_id is null or p_after_operation_id !~ '^([a-f0-9]{64})?$'
 or p_limit is null or p_limit<1 or p_limit>100 then raise exception 'invalid_request' using errcode='PT422';end if;
 select coalesce(jsonb_agg(to_jsonb(q) order by q.operation_id),'[]'::jsonb) into items from(
 select j.operation_id,j.payload_sha256,j.article_id,j.locale,j.revision_id,r.revision,r.title,
  private.rad_article_state(r.id) as editorial_state,private.rad_article_verification(r.id) as verification_state,
  h.head_id as current_head_id,h.published_id,(h.head_id is distinct from r.id) as detached
 from private.rad_production_reconciliation_journal j join public.visa_article_revisions r on r.id=j.revision_id
 left join public.visa_article_heads h on h.article_id=j.article_id and h.locale=j.locale
 where j.package_sha256=p_package_sha256 and j.operation_id>p_after_operation_id
 order by j.operation_id limit p_limit)q;
 return jsonb_build_object('items',items,'next_after_operation_id',case when jsonb_array_length(items)=p_limit then items->-1->>'operation_id' else null end);
end $queue$;
create or replace function public.get_production_reconciliation_draft(
 p_package_sha256 text,p_operation_id text,p_payload_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $reader$
declare result jsonb;begin
 perform private.rad_require_admin();
 if p_package_sha256 is null or p_package_sha256 !~ '^[a-f0-9]{64}$'
 or p_operation_id is null or p_operation_id !~ '^[a-f0-9]{64}$'
 or p_payload_sha256 is null or p_payload_sha256 !~ '^[a-f0-9]{64}$' then raise exception 'invalid_request' using errcode='PT422';end if;
 select jsonb_build_object('operation_id',j.operation_id,'payload_sha256',j.payload_sha256,
  'revision_id',r.id,'article_id',r.article_id,'locale',r.locale,'revision',r.revision,'title',r.title,
  'summary',r.summary,'body',r.body,'composition',rr.composition,'created_by',r.created_by,
  'current_head_id',h.head_id,'published_id',h.published_id,
  'editorial_state',private.rad_article_state(r.id),'verification_state',private.rad_article_verification(r.id)) into result
 from private.rad_production_reconciliation_journal j join public.visa_article_revisions r on r.id=j.revision_id
 join private.rad_editorial_rich_revisions rr on rr.revision_id=r.id
 left join public.visa_article_heads h on h.article_id=r.article_id and h.locale=r.locale
 where j.package_sha256=p_package_sha256 and j.operation_id=p_operation_id and j.payload_sha256=p_payload_sha256;
 if result is null then raise exception 'not_found' using errcode='PT404';end if;
 return result;
end $reader$;
revoke all on function public.list_production_reconciliation_drafts(text,text,integer) from public,anon,authenticated,service_role;
revoke all on function public.get_production_reconciliation_draft(text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.list_production_reconciliation_drafts(text,text,integer) to authenticated;
grant execute on function public.get_production_reconciliation_draft(text,text,text) to authenticated;
"""

ROW_SQL = r"""
do $ROW_DELIMITER$ declare
 raw text := RAW_PAYLOAD; p jsonb; item jsonb; draft_body jsonb; s jsonb; sec jsonb; e jsonb;
 current_row jsonb:=nullif(CURRENT_BINDING::jsonb,'null'::jsonb); old public.visa_article_revisions;
 a uuid:=ARTICLE_ID::uuid; loc text:=LOCALE; rid uuid:=REVISION_ID::uuid;
 actor uuid:=ACTOR_ID::uuid; pkg text:=PACKAGE_HASH; op text:=OPERATION_ID;
 doc uuid; snap uuid; cs uuid; rev integer; identity jsonb; existing_identity jsonb;
begin
 if encode(extensions.digest(raw,'sha256'),'hex')<>PAYLOAD_HASH then raise exception 'PAYLOAD_HASH_MISMATCH';end if;
 p:=raw::jsonb;item:=p->'item';draft_body:=item->'draft_request';
 if exists(select 1 from private.rad_production_reconciliation_journal j where j.package_sha256=pkg and j.operation_id=op) then
  if not exists(select 1 from private.rad_production_reconciliation_journal j join public.visa_article_revisions r on r.id=j.revision_id
   join private.rad_editorial_rich_revisions rr on rr.revision_id=r.id
   where j.package_sha256=pkg and j.operation_id=op and j.payload_sha256=PAYLOAD_HASH and j.actor_id=actor
   and r.id=rid and r.article_id=a and r.locale=loc and r.created_by=actor
   and r.title=draft_body->>'title' and r.summary=draft_body->>'summary'
   and r.content_hash=encode(extensions.digest((draft_body-'request_key'-'expected_revision')::text,'sha256'),'hex')
   and r.body=draft_body-'request_key' and rr.composition=item-'draft_request'
   and private.rad_article_state(r.id)='draft' and private.rad_article_verification(r.id)='unverified') then raise exception 'RETRY_STATE_CONFLICT';end if;
  if current_row is null and not exists(select 1 from public.visa_article_heads h
   where h.article_id=a and h.locale=loc and h.head_id=rid and h.published_id is null)
   then raise exception 'RETRY_HEAD_CONFLICT';end if;
  if (select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'anchor',x.anchor,'heading',x.heading,
   'order',x.position,'blocks',x.blocks,'evidence_refs',x.evidence_refs) order by x.position),'[]'::jsonb)
   from public.visa_article_sections x where x.revision_id=rid) is distinct from draft_body->'sections'
   then raise exception 'RETRY_SECTIONS_CONFLICT';end if;
  for s in select value from jsonb_array_elements(p->'sources') loop
   if not exists(select 1 from public.source_snapshots x join public.source_documents d on d.id=x.document_id
    join public.content_sources c on c.id=d.source_id and c.url=s->>'url'
    where x.id=(s->>'snapshot_id')::uuid and d.id=(s->>'source_id')::uuid and d.canonical_url=s->>'url'
    and d.language_code=loc and d.source_authority='rad_official' and x.content_hash=s->>'body_sha256'
    and x.normalized_text=s->>'body_text' and x.metadata->>'raw_html_sha256'=s->>'raw_html_sha256'
    and x.fetched_at=(s->>'retrieved_at')::timestamptz) then raise exception 'RETRY_SOURCE_CONFLICT';end if;
  end loop;
  return;
 end if;
 if item->>'editorial_state' is distinct from 'draft' or item->>'verification_state' is distinct from 'unverified'
 or item->'publication_allowed' is distinct from 'false'::jsonb or item->'published' is distinct from 'false'::jsonb
 or item->>'reviewer_id' is not null or draft_body->>'article_id' is distinct from a::text or draft_body->>'locale' is distinct from loc
 or draft_body->'expected_revision' is distinct from '0'::jsonb
 or draft_body->>'merge_manifest_id' is not null or draft_body->'related_article_ids' is distinct from '[]'::jsonb then
 raise exception 'DRAFT_ONLY_CONTRACT_REQUIRED';end if;
 perform private.rad_assert_request('save_visa_article_draft',draft_body);
 if current_row is not null then
  select r.* into old from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id
  where h.article_id=a and h.locale=loc and h.head_id=(current_row->>'head_id')::uuid
  and h.published_id is not distinct from (current_row->>'published_id')::uuid;
  if old.id is null or md5(old.body::text) is distinct from current_row->>'body_md5'
   or old.revision is distinct from (current_row->>'revision')::integer
   or md5(old.created_by::text) is distinct from current_row->>'actor_id_md5'
   or old.content_hash is distinct from current_row->>'stored_content_hash'
   or md5(jsonb_build_object('title',old.title,'summary',old.summary)::text) is distinct from current_row->>'title_summary_md5' then
   raise exception 'CURRENT_HEAD_BODY_ACTOR_CONFLICT';end if;
 else
  if exists(select 1 from public.visa_article_heads h where h.article_id=a and h.locale=loc) then
   raise exception 'EXPECTED_MISSING_HEAD_CONFLICT';end if;
 end if;
 -- Never mutate an existing article identity; only absent identities are inserted.
 identity:=jsonb_build_object('kind',case when item->>'content_class'='canonical' then 'main' else 'related' end,
 'country_code',case when jsonb_array_length(item->'country_codes')=1 then item->'country_codes'->>0 else null end,
 'pathway_slug',case when item->>'content_class'='canonical' then item->>'visa_category' else 'topic-'||replace(a::text,'-','') end,
 'slug','editorial-'||a::text);
 select jsonb_build_object('kind',v.kind,'country_code',v.country_code,'pathway_slug',v.pathway_slug,'slug',v.slug)
 into existing_identity from public.visa_articles v where v.id=a;
 if existing_identity is not null and existing_identity<>identity then raise exception 'IMMUTABLE_ARTICLE_IDENTITY_CONFLICT';end if;
 for s in select value from jsonb_array_elements(p->'sources') loop
  if s->>'url'!~'^https://(radvisa[.]com|digivisa[.]ir|radmohajer[.]ir)/'
   or s->>'language' is distinct from loc or s->>'body_sha256' is distinct from encode(extensions.digest(s->>'body_text','sha256'),'hex')
   or s->>'retrieved_at' is null or (s->>'retrieved_at')::timestamptz>now()+interval '5 minutes'
   then raise exception 'SOURCE_PAYLOAD_CONFLICT';end if;
  cs:=(s->>'content_source_id')::uuid;doc:=(s->>'source_id')::uuid;snap:=(s->>'snapshot_id')::uuid;
  if exists(select 1 from public.source_documents d where (d.canonical_url=s->>'url' and d.id<>doc)
   or (d.id=doc and (d.canonical_url is distinct from s->>'url' or d.language_code is distinct from loc
    or d.source_authority is distinct from 'rad_official'
    or not exists(select 1 from public.content_sources c where c.id=d.source_id and c.url=s->>'url'))))
   then raise exception 'DISTINCT_LEGACY_DOCUMENT_CONFLICT';end if;
  if exists(select 1 from public.source_snapshots x where (x.id=snap and
   (x.document_id is distinct from doc or x.content_hash is distinct from s->>'body_sha256'
    or x.normalized_text is distinct from s->>'body_text' or x.metadata->>'raw_html_sha256' is distinct from s->>'raw_html_sha256'
    or x.fetched_at is distinct from (s->>'retrieved_at')::timestamptz))
   or (x.document_id=doc and x.content_hash=s->>'body_sha256' and x.id<>snap))
   then raise exception 'DISTINCT_LEGACY_SNAPSHOT_CONFLICT';end if;
  if exists(select 1 from public.content_sources c where c.id=cs and c.url<>s->>'url') then raise exception 'SOURCE_IDENTITY_CONFLICT';end if;
  insert into public.content_sources(id,publisher,source_type,title,url,language_code,retrieved_at,content_hash)
  select cs,'RAD first-party editorial source, not legal verification','rad_official',s->>'title',s->>'url',loc,
  (s->>'retrieved_at')::timestamptz,s->>'body_sha256' where not exists(select 1 from public.content_sources c where c.url=s->>'url');
  select c.id into cs from public.content_sources c where c.url=s->>'url' order by c.created_at,c.id limit 1;
  insert into public.source_documents(id,canonical_url,source_id,source_authority,title,language_code,jurisdiction,last_content_hash,validation_status)
  values(doc,s->>'url',cs,'rad_official',s->>'title',loc,'',s->>'body_sha256','candidate') on conflict(id) do nothing;
  insert into public.source_snapshots(id,document_id,content_hash,normalized_text,http_status,fetched_at,metadata)
  values(snap,doc,s->>'body_sha256',s->>'body_text',200,(s->>'retrieved_at')::timestamptz,
  jsonb_build_object('production_reconciliation_package',pkg,'raw_html_sha256',s->'raw_html_sha256','factual_verification','not_verified'))
  on conflict(id) do nothing;
  -- Classify only genuinely new sources; no legacy classification is substituted.
  if not exists(select 1 from pg_temp.rad_preserved x where x.table_name='public.source_snapshots' and x.row_data->>'id'=snap::text) then
   perform private.rad_classify_snapshot(snap);
  end if;
 end loop;
 for sec in select value from jsonb_array_elements(draft_body->'sections') loop
  for e in select value from jsonb_array_elements(sec->'evidence_refs') loop
   if e->>'claim_id' is not null or not exists(select 1 from jsonb_array_elements(p->'sources') src(value)
    join public.source_snapshots x on x.id=(src.value->>'snapshot_id')::uuid
    where src.value->>'snapshot_id'=e->>'snapshot_id' and position(e->>'excerpt' in x.normalized_text)>0)
    then raise exception 'UNVERIFIED_SOURCE_EXCERPT_REQUIRED';end if;
  end loop;
 end loop;
 insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)
 values(a,identity->>'kind',identity->>'country_code',identity->>'pathway_slug',identity->>'slug',actor) on conflict(id) do nothing;
 select coalesce(max(r.revision),0)+1 into rev from public.visa_article_revisions r where r.article_id=a and r.locale=loc;
 insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)
 values(rid,a,loc,rev,draft_body->>'title',draft_body->>'summary',encode(extensions.digest((draft_body-'request_key'-'expected_revision')::text,'sha256'),'hex'),draft_body-'request_key',actor);
 for sec in select value from jsonb_array_elements(draft_body->'sections') loop
  insert into public.visa_article_sections values(rid,(sec->>'id')::uuid,sec->>'anchor',sec->>'heading',(sec->>'order')::integer,sec->'blocks',sec->'evidence_refs');
 end loop;
 insert into public.visa_article_revision_events(revision_id,state,actor_id,note)
 values(rid,'draft',actor,'Additive unverified Production reconciliation; no approval or publication');
 insert into private.rad_editorial_rich_revisions(revision_id,composition) values(rid,item-'draft_request')
 on conflict(revision_id) do nothing;
 if not exists(select 1 from private.rad_editorial_rich_revisions rr where rr.revision_id=rid and rr.composition=item-'draft_request')
 then raise exception 'RICH_PROJECTION_CONFLICT';end if;
 if current_row is null then
  insert into public.visa_article_heads(article_id,locale,head_id,published_id) values(a,loc,rid,null);
 end if;
 -- Catalog is only new metadata. Existing article/locale revisions keep their heads.
 insert into private.rad_editorial_catalog(article_id,content_class,category,country_codes,source_publishers,source_snapshot_ids,composition,active)
 values(a,item->>'content_class',item->>'category',array(select jsonb_array_elements_text(item->'country_codes')),
 array(select distinct coalesce(src.value->>'publisher',substring(src.value->>'url' from '^https://([^/]+)')) from jsonb_array_elements(p->'sources') src(value)),
 array(select (src.value->>'snapshot_id')::uuid from jsonb_array_elements(p->'sources') src(value)),item-'draft_request',current_row is null)
 on conflict(article_id) do nothing;
 insert into private.rad_production_reconciliation_journal(package_sha256,operation_id,payload_sha256,article_id,locale,revision_id,actor_id)
 values(pkg,op,PAYLOAD_HASH,a,loc,rid,actor);
end $ROW_DELIMITER$;
"""

PRESERVE_SQL = r"""
do $preserve$ declare t text;begin
 foreach t in array array['auth.users','public.profiles','public.source_documents','public.source_snapshots',
 'public.content_sources','public.visa_articles','public.visa_article_revisions','public.visa_article_heads',
 'public.visa_article_sections','public.visa_article_revision_events',
 'private.rad_editorial_catalog','private.rad_editorial_rich_revisions','private.visa_source_origins'] loop
 execute format('select exists(select row_data from pg_temp.rad_preserved where table_name=%L except select to_jsonb(x) from %s x)',t,t) into strict rad_changed;
 end loop;
end $preserve$;
""".replace("declare t text;", "declare t text;rad_changed boolean;").replace(
    "into strict rad_changed;",
    "into strict rad_changed; if rad_changed then raise exception 'PRESERVATION_FAILED: %',t;end if;",
)


def render_sql(
    plan,
    operations,
    authorization=None,
    decisions=None,
    execution_scope="approved_isolated_restore",
):
    """Return review SQL by default; only verified restore authorization opens it."""
    if authorization is None:
        return "begin;do $$begin raise exception 'REVIEW_ONLY_APPROVED_RESTORE_ACTOR_RECOVERY_AND_OWNER_REQUIRED';end $$;rollback;\n"
    if (
        authorization.get("operation", "apply_unverified_drafts")
        != "apply_unverified_drafts"
    ):
        raise ValueError("apply_operation_authorization_required")
    validate_package(plan, operations)
    package_sha = plan["package_sha256"]
    validate_authorization(authorization, package_sha, execution_scope)
    decisions = unique_rows(decisions or [])
    decision_sha = digest(
        canonical(
            sorted(decisions.values(), key=lambda d: (d["article_id"], d["locale"]))
        )
    )
    if authorization.get("human_decisions_sha256") != decision_sha:
        raise ValueError("exact_human_decisions_authorization_required")
    keys = {
        (o["article_id"], o["locale"])
        for o in operations
        if o["action"] == "PENDING_HUMAN_RECONCILIATION"
    }
    if decisions.keys() - keys:
        raise ValueError("unknown_or_nondivergent_decision")
    ops = [
        resolve_operation(o, decisions.get((o["article_id"], o["locale"])))
        for o in operations
    ]
    # Pending rows remain explicitly absent from executable statements.
    selected = [o for o in ops if o["action"].startswith("INSERT_")]
    guards = authorization_guards(
        plan, authorization, execution_scope, decision_sha, list(decisions.values())
    )
    guards.extend(
        plan_statements(
            plan, selected, literal(authorization["actor_id"]), literal(decision_sha)
        )
    )
    guards.append("commit;")
    return "\n".join(guards) + "\n"


def authorization_guards(
    plan,
    authorization,
    execution_scope,
    decision_sha,
    decisions,
    operation="apply_unverified_drafts",
):
    package_sha = plan["package_sha256"]
    policy = validate_callback_policy(authorization, package_sha, operation)
    guard_tag = dollar_tag("guard", canonical(authorization) + canonical(decisions))
    guards = [
        "begin;",
        "set local standard_conforming_strings=on;",
        "set local timezone='UTC';",
        "set local search_path=pg_catalog;",
        "set local lock_timeout='5s';",
        "set local statement_timeout='600s';",
        "do " + guard_tag + " begin",
    ]
    assertions = [
        ("rad.expected_project", PROJECT),
        ("rad.execution_scope", execution_scope),
        ("rad.package_sha256", package_sha),
        ("rad.actor_id", authorization["actor_id"]),
        ("rad.human_decisions_sha256", decision_sha),
    ]
    assertions.extend(
        ("rad." + field, authorization[field]) for field in RECEIPT_FIELDS
    )
    if execution_scope == "approved_production":
        assertions.extend(
            ("rad." + field, authorization[field])
            for field in (
                "generator_sha256",
                "final_candidate_commit",
                "final_delivery_receipt_sha256",
                "production_api_origin",
                "recovery_evidence_kind",
            )
        )
    for key, value in assertions:
        guards.append(
            "if current_setting("
            + literal(key)
            + ",true) is distinct from "
            + literal(value)
            + " then raise exception 'RESTORE_CONTEXT_ASSERTION_REQUIRED';end if;"
        )
    endpoint = authorization["restore_endpoint"]
    guards.append(
        "if host(inet_server_addr()) is distinct from "
        + literal(endpoint["server_addr"])
        + " or inet_server_port() is distinct from "
        + str(endpoint["server_port"])
        + " or current_database() is distinct from "
        + literal(endpoint["database"])
        + " or (select system_identifier::text from pg_control_system()) is distinct from "
        + literal(endpoint["system_identifier"])
        + " then raise exception 'RESTORE_ENDPOINT_IDENTITY_MISMATCH';end if;"
    )
    guards.append(
        "if private.rad_require_admin() is distinct from "
        + literal(authorization["actor_id"])
        + "::uuid then raise exception 'APPROVED_ACTOR_SESSION_REQUIRED';end if;"
    )
    guards.append(
        "if not exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id="
        + literal(authorization["actor_id"])
        + "::uuid and p.role::text="
        + literal(authorization["actor_role"])
        + ") then raise exception 'EXISTING_APPROVED_ACTOR_REQUIRED';end if;"
    )
    if policy:
        assertions_for_policy = [
            ("rad.approved_ddl_event_callbacks_sha256", digest(canonical(policy))),
            (
                "rad.ddl_event_callback_review_receipt_sha256",
                authorization["ddl_event_callback_review_receipt_sha256"],
            ),
        ]
        for key, value in assertions_for_policy:
            guards.append(
                "if current_setting("
                + literal(key)
                + ",true)is distinct from "
                + literal(value)
                + "then raise exception 'DDL_CALLBACK_REVIEW_CONTEXT_REQUIRED';end if;"
            )
    guards.append(callback_guard_sql(policy))
    for decision in decisions:
        guards.append(
            "if not exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id="
            + literal(decision["reviewer_id"])
            + "::uuid and p.role::text in ('admin','super_admin')) then raise exception 'EXISTING_HUMAN_REVIEWER_REQUIRED';end if;"
        )
    guards.append("end " + guard_tag + ";")
    return guards


def plan_statements(plan, selected, actor_expression, decision_expression=None):
    """Shared concrete SQL for executable isolated and unconditionally refused review."""
    package_sha = plan["package_sha256"]
    yield ENGINE
    yield ADMIN_COMPAT_SQL
    yield baseline_sql(plan)
    for op in selected:
        raw = canonical(op["payload"])
        delimiter = "radrow" + op["operation_id"][:16]
        while "$" + delimiter + "$" in canonical(op):
            delimiter += "x"
        replacements = {
            "RAW_PAYLOAD": literal(raw),
            "CURRENT_BINDING": literal(canonical(op["expected_current"])),
            "ARTICLE_ID": literal(op["article_id"]),
            "LOCALE": literal(op["locale"]),
            "REVISION_ID": literal(op["revision_id"]),
            "ACTOR_ID": actor_expression,
            "PACKAGE_HASH": literal(package_sha),
            "OPERATION_ID": literal(op["operation_id"]),
            "PAYLOAD_HASH": literal(op["payload_sha256"]),
            "ROW_DELIMITER": delimiter,
        }
        row = ROW_SQL
        # Substitute tokens once: data containing a token must never be rewritten.
        row = re.sub(
            r"\b(?:" + "|".join(map(re.escape, replacements)) + r")\b",
            lambda hit, values=replacements: values[hit.group()],
            row,
        )
        yield row
    yield reader_collision_sql()
    yield READERS_SQL
    yield PRESERVE_SQL
    yield substitute(
        FINALIZE_SQL,
        {
            "PACKAGE_HASH": literal(package_sha),
            "ACTOR_ID": actor_expression,
            "DECISION_HASH": decision_expression or literal(digest(canonical([]))),
            "CATALOG_QUERY": CATALOG_QUERY,
        },
    )


def substitute(sql, bindings):
    return re.sub(
        r"\b(?:" + "|".join(map(re.escape, bindings)) + r")\b",
        lambda hit: bindings[hit.group()],
        sql,
    )


def reader_collision_sql():
    checks = []
    for name, signature, tag in [
        ("list_production_reconciliation_drafts", "text,text,integer", "queue"),
        ("get_production_reconciliation_draft", "text,text,text", "reader"),
    ]:
        body = READERS_SQL.split("$" + tag + "$")[1]
        checks.append(
            "if exists(select 1 from pg_proc p join pg_language l on l.oid=p.prolang where p.oid=to_regprocedure("
            + literal("public." + name + "(" + signature + ")")
            + ") and (md5(p.prosrc)<>"
            + literal(hashlib.md5(body.encode()).hexdigest())
            + " or not p.prosecdef or l.lanname<>'plpgsql' or p.proowner<>(select oid from pg_roles where rolname=current_user))) then raise exception 'READER_RPC_COLLISION';end if;"
        )
    return (
        "do $rad_reader_collision$ begin "
        + "".join(checks)
        + "end $rad_reader_collision$;"
    )


def render_rollback_sql(
    plan, operations, authorization=None, execution_scope="approved_isolated_restore"
):
    if authorization is None:
        return "begin;do $$begin raise exception 'COMPENSATION_OWNER_RECOVERY_ACTOR_AND_PACKAGE_REQUIRED';end $$;rollback;\n"
    validate_package(plan, operations)
    validate_authorization(authorization, plan["package_sha256"], execution_scope)
    receipt = authorization.get("compensating_rollback_authorization_sha256", "")
    if (
        authorization.get("operation") != "compensating_rollback"
        or not isinstance(receipt, str)
        or not re.fullmatch("[a-f0-9]{64}", receipt)
    ):
        raise ValueError("explicit_compensating_rollback_authorization_required")
    if execution_scope == "approved_production":
        path = authorization.get("compensating_rollback_authorization_file")
        if (
            not isinstance(path, str)
            or not Path(path).is_file()
            or digest(Path(path).read_bytes()) != receipt
        ):
            raise ValueError("compensating_rollback_receipt_file_binding_required")
    decision_sha = authorization.get("human_decisions_sha256", "")
    if not isinstance(decision_sha, str) or not re.fullmatch(
        "[a-f0-9]{64}", decision_sha
    ):
        raise ValueError("compensation_decision_set_binding_required")
    parts = authorization_guards(
        plan,
        authorization,
        execution_scope,
        decision_sha,
        [],
        operation="compensating_rollback",
    )
    parts.append(
        "do $$begin if current_setting('rad.compensating_rollback_authorization_sha256',true) is distinct from "
        + literal(receipt)
        + " then raise exception 'COMPENSATION_CONTEXT_ASSERTION_REQUIRED';end if;end $$;"
    )
    parts.append(
        substitute(
            ROLLBACK_SQL,
            {
                "PACKAGE_HASH": literal(plan["package_sha256"]),
                "ACTOR_ID": literal(authorization["actor_id"]),
                "DECISION_HASH": literal(decision_sha),
                "ROLLBACK_AUTH_HASH": literal(receipt),
                "CATALOG_QUERY": CATALOG_QUERY,
                "DELETE_GUARD": DELETE_GUARD,
            },
        )
    )
    parts.append("commit;")
    return "\n".join(parts) + "\n"


BASELINE_SQL = r"""
do $BASELINE_TAG$ declare baseline jsonb:=BASELINE_PAYLOAD::jsonb; snapshot_baseline jsonb:=SNAPSHOT_PAYLOAD::jsonb;
 legacy jsonb:=LEGACY_PAYLOAD::jsonb;
 p jsonb;rev public.visa_article_revisions;section_hash text;actual_identity jsonb;begin
 for p in select value from jsonb_array_elements(baseline) loop
  select v.* into rev from public.visa_article_heads h join public.visa_article_revisions v on v.id=h.head_id
  where h.article_id=(p->>'article_id')::uuid and h.locale=p->>'locale' and h.head_id=(p->>'head_id')::uuid
   and h.published_id is not distinct from (p->>'published_id')::uuid;
  select md5(coalesce(jsonb_agg(jsonb_build_object('anchor',x.anchor,'heading',x.heading,'position',x.position,
   'blocks',x.blocks,'evidence_refs',x.evidence_refs) order by x.position,x.id),'[]'::jsonb)::text) into section_hash
  from public.visa_article_sections x where x.revision_id=rev.id;
  if rev.id is null or rev.revision is distinct from (p->>'revision')::integer
   or md5(rev.body::text) is distinct from p->>'body_md5' or md5(rev.created_by::text) is distinct from p->>'actor_id_md5'
   or rev.content_hash is distinct from p->>'stored_content_hash'
   or md5(jsonb_build_object('title',rev.title,'summary',rev.summary)::text) is distinct from p->>'title_summary_md5'
   or section_hash is distinct from p->>'sections_md5' then raise exception 'BASELINE_HEAD_BODY_ACTOR_CONFLICT';end if;
  if p ? 'created_at' and rev.created_at is distinct from (p->>'created_at')::timestamptz then raise exception 'BASELINE_CREATED_AT_CONFLICT';end if;
  if p ? 'kind' then
   select jsonb_build_object('kind',v.kind,'country_code',v.country_code,'pathway_slug',v.pathway_slug,'slug',v.slug)
    into actual_identity from public.visa_articles v where v.id=rev.article_id;
   if actual_identity is distinct from jsonb_build_object('kind',p->'kind','country_code',p->'country_code',
    'pathway_slug',p->'pathway_slug','slug',p->'slug') then raise exception 'BASELINE_ARTICLE_IDENTITY_CONFLICT';end if;
  end if;
 end loop;
 for p in select value from jsonb_array_elements(snapshot_baseline) loop
  if not exists(select 1 from public.source_snapshots x join public.source_documents d on d.id=x.document_id
   where x.id=(p->>'id')::uuid and x.document_id=(p->>'document_id')::uuid
   and x.content_hash=p->>'content_hash' and md5(x.normalized_text)=p->>'normalized_text_md5'
   and md5(d.canonical_url)=p->>'canonical_url_md5') then raise exception 'BASELINE_SOURCE_PROVENANCE_CONFLICT';end if;
 end loop;
 for p in select value from jsonb_array_elements(coalesce(legacy->'snapshots','[]'::jsonb))loop
  if not exists(select 1 from public.source_snapshots x where x.id=(p->>'id')::uuid
   and encode(extensions.digest(to_jsonb(x)::text,'sha256'),'hex')=p->>'row_sha256')
  then raise exception 'BASELINE_LEGACY_SNAPSHOT_ROW_CONFLICT';end if;
 end loop;
 for p in select value from jsonb_array_elements(coalesce(legacy->'documents','[]'::jsonb))loop
  if not exists(select 1 from public.source_documents x where x.id=(p->>'id')::uuid
   and encode(extensions.digest(to_jsonb(x)::text,'sha256'),'hex')=p->>'row_sha256')
  then raise exception 'BASELINE_LEGACY_DOCUMENT_ROW_CONFLICT';end if;
 end loop;
 if legacy ? 'snapshots' and exists(select 1 from public.source_snapshots x where not exists(
  select 1 from jsonb_array_elements(legacy->'snapshots')v where (v->>'id')::uuid=x.id)
  and not exists(select 1 from private.rad_production_reconciliation_created_rows j where j.package_sha256=PACKAGE_HASH
   and j.table_name='public.source_snapshots' and j.row_key->>'id'=x.id::text))then raise exception 'BASELINE_UNBOUND_SOURCE_SNAPSHOT';end if;
 if legacy ? 'documents' and exists(select 1 from public.source_documents x where not exists(
  select 1 from jsonb_array_elements(legacy->'documents')v where (v->>'id')::uuid=x.id)
  and not exists(select 1 from private.rad_production_reconciliation_created_rows j where j.package_sha256=PACKAGE_HASH
   and j.table_name='public.source_documents' and j.row_key->>'id'=x.id::text))then raise exception 'BASELINE_UNBOUND_SOURCE_DOCUMENT';end if;
 if exists(select 1 from public.visa_article_heads h where not exists(select 1 from jsonb_array_elements(baseline)pb(value)
  where h.article_id=(pb.value->>'article_id')::uuid and h.locale=pb.value->>'locale')
  and not exists(select 1 from private.rad_production_reconciliation_journal j where j.package_sha256=PACKAGE_HASH
   and j.article_id=h.article_id and j.locale=h.locale and j.revision_id=h.head_id and h.published_id is null))
 then raise exception 'UNBOUND_BASELINE_HEAD';end if;
end $BASELINE_TAG$;
"""


def baseline_sql(plan):
    baseline = canonical(plan["production_baseline"])
    snapshots = canonical(plan.get("production_snapshot_baseline", []))
    legacy = canonical(plan.get("production_legacy_fullrows", {}))
    replacements = {
        "BASELINE_TAG": dollar_tag("baseline", baseline + snapshots + legacy).strip(
            "$"
        ),
        "BASELINE_PAYLOAD": literal(baseline),
        "SNAPSHOT_PAYLOAD": literal(snapshots),
        "PACKAGE_HASH": literal(plan["package_sha256"]),
    }
    replacements["LEGACY_PAYLOAD"] = literal(legacy)
    return re.sub(
        r"\b(?:" + "|".join(replacements) + r")\b",
        lambda hit: replacements[hit.group()],
        BASELINE_SQL,
    )


def write_review_sql(path, plan, operations):
    """Stream a complete, deliberately non-executable SQL review artifact."""
    validate_package(plan, operations)
    selected = [o for o in operations if o["action"].startswith("INSERT_")]
    raw_sha = hashlib.sha256()
    raw_size = 0
    refusal = """-- Production-specific schema/data REVIEW ONLY; no actor or endpoint is invented.
-- The first exception aborts this single transaction before DDL/DML; final ROLLBACK.
-- Unknown future operator actor is an unevaluated setting, never an authorization.
begin;
set local standard_conforming_strings=on;
do $rad_review_refusal$ begin
 raise exception 'PRODUCTION_REVIEW_ONLY_APPROVED_CHECKPOINT_ACTOR_ENDPOINT_AND_OWNER_REQUIRED';
end $rad_review_refusal$;
"""
    with (
        path.open("xb") as raw,
        gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as zipped,
    ):
        for statement in [refusal]:
            value = (statement + "\n").encode("utf8")
            zipped.write(value)
            raw_sha.update(value)
            raw_size += len(value)
        for statement in plan_statements(
            plan,
            selected,
            "nullif(current_setting('rad.future_approved_actor_id',true),'')",
        ):
            value = (statement + "\n").encode("utf8")
            zipped.write(value)
            raw_sha.update(value)
            raw_size += len(value)
        value = b"rollback;\n"
        zipped.write(value)
        raw_sha.update(value)
        raw_size += len(value)
    return {
        "sql_sha256": raw_sha.hexdigest(),
        "gzip_sha256": digest(path.read_bytes()),
        "sql_bytes": raw_size,
        "selected_insert_operations": len(selected),
        "pending_human_operations_omitted": sum(
            o["action"] == "PENDING_HUMAN_RECONCILIATION" for o in operations
        ),
        "mandatory_first_refusal": True,
        "final_statement": "rollback",
        "actor_supplied": False,
        "endpoint_supplied": False,
        "hosted_execution_supported": False,
        "package_sha256": plan["package_sha256"],
    }


def prepare(
    compositions,
    evidence,
    output,
    review_cases_path=None,
    ready_payloads=None,
    current_production_capture=None,
):
    """Seal 1100 payloads and per-row operations from verified local evidence."""
    current = unique_rows(
        json.loads(
            (evidence / "production_revision_hash_capture_20261101.json").read_text(
                "utf8"
            )
        )["rows"]
    )
    dispositions = unique_rows(
        read_rows(evidence / "production-desired-reconciled-dispositions.jsonl.gz")
    )
    review_cases = (
        unique_rows(read_rows(review_cases_path))
        if review_cases_path is not None
        else {}
    )
    if len(review_cases) != 657:
        raise ValueError("exact_657_bound_body_review_cases_required")
    review_receipt_path = review_cases_path.parent / "receipt.json"
    review_receipt = json.loads(review_receipt_path.read_text("utf8"))
    if review_receipt.get("outputs", {}).get(review_cases_path.name) != digest(
        review_cases_path.read_bytes()
    ) or review_receipt.get("source_integrity") != {
        "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY": 657
    }:
        raise ValueError("complete_body_review_receipt_required")
    if not ready_payloads:
        raise ValueError("sealed_canonical_ready_payloads_required")
    output.mkdir(parents=True, exist_ok=False)
    inputs = {
        str(review_receipt_path): digest(review_receipt_path.read_bytes()),
        str(ADMIN_COMPAT_PATH): ADMIN_COMPAT_SHA256,
    }
    operations = []
    desired_keys = set()
    for directory in compositions:
        manifest = json.loads((directory / "manifest.json").read_text("utf8"))
        for filename in ("articles.jsonl.gz", "sources.jsonl.gz"):
            observed = digest((directory / filename).read_bytes())
            if manifest["files"][filename] != observed:
                raise ValueError("composition_seal_mismatch")
            inputs[str(directory / filename)] = observed
        inputs[str(directory / "manifest.json")] = digest(
            (directory / "manifest.json").read_bytes()
        )
        for article in read_rows(directory / "articles.jsonl.gz"):
            key = (article["article_id"], article["locale"])
            if key in desired_keys:
                raise ValueError("duplicate_desired_article")
            desired_keys.add(key)
            d = dispositions[key]
            # Source article digests use the pre-existing canonical sort-key format.
            if (
                digest(json.dumps(article, ensure_ascii=False, sort_keys=True))
                != d["desired_article_sha256"]
            ):
                raise ValueError("desired_article_binding_mismatch:" + str(key))
    for payload_path in ready_payloads:
        observed = digest(payload_path.read_bytes())
        if review_receipt["inputs"].get(str(payload_path.resolve())) != observed:
            raise ValueError("canonical_ready_payload_review_seal_mismatch")
        inputs[str(payload_path)] = observed
        for ready in read_rows(payload_path):
            item = ready["item"]
            key = (item["article_id"], item["locale"])
            if ready.get("status") != "technical_draft_only" or key not in desired_keys:
                raise ValueError("canonical_ready_payload_desired_binding_required")
            d = dispositions[key]
            case = review_cases.get(key)
            if (
                d["operation_class"]
                != "CORE_SEMANTIC_MATCH_RICH_PROJECTION_RECONCILIATION"
            ):
                if (
                    case is None
                    or case.get("desired_article_sha256") != d["desired_article_sha256"]
                ):
                    raise ValueError("desired_article_review_case_required")
            elif case is not None:
                raise ValueError("unexpected_semantic_match_review_case")
            operations.append(
                make_operation(ready, current.get(key), d["operation_class"], case)
            )
    operations.sort(key=lambda o: (o["article_id"], o["locale"]))
    if (
        len(unique_rows(operations)) != 1100
        or set(unique_rows(operations)) != dispositions.keys()
    ):
        raise ValueError("exact_1100_desired_keys_required")
    for filename in (
        "production_revision_hash_capture_20261101.json",
        "production-desired-reconciled-dispositions.jsonl.gz",
        "production_snapshot_provenance_20261101.json",
        "production_freshness_20261101.json",
        "manifest.json",
        "forward_body.sql",
        "production-legacy-fullrow-hashes-20261102.json",
        "production-all745-freshness-20261102.json",
    ):
        inputs[str(evidence / filename)] = digest((evidence / filename).read_bytes())
    inputs[str(review_cases_path)] = digest(review_cases_path.read_bytes())
    if len(current) != 745 or len(current.keys() - dispositions.keys()) != 51:
        raise ValueError("exact_745_existing_and_51_outside_required")
    expected_counts = {
        "INSERT_INITIAL_UNVERIFIED_DRAFT": 406,
        "INSERT_DETACHED_UNVERIFIED_DRAFT": 443,
        "PENDING_HUMAN_RECONCILIATION": 251,
    }
    if dict(Counter(o["action"] for o in operations)) != expected_counts:
        raise ValueError("exact_production_operation_classes_required")
    if current_production_capture is None:
        raise ValueError("current_atomic_production_capture_required")
    fresh = json.loads(current_production_capture.read_text("utf8"))
    legacy = fresh["legacy_provenance"]
    fields = [
        "article_id",
        "locale",
        "head_id",
        "published_id",
        "revision",
        "body_md5",
        "actor_id_md5",
        "stored_content_hash",
        "title_summary_md5",
    ]
    binding = "\n".join(
        "|".join(str(r[k]) if r[k] is not None else "NULL" for k in fields)
        for r in sorted(current.values(), key=lambda r: (r["article_id"], r["locale"]))
    )
    if (
        fresh.get("project_id") != PROJECT
        or fresh.get("heads") != 745
        or fresh.get("published_heads") != 0
        or fresh.get("all745_binding_md5") != hashlib.md5(binding.encode()).hexdigest()
    ):
        raise ValueError("current_atomic_745_head_binding_required")
    for kind in ("snapshots", "documents"):
        rows = legacy.get(kind, [])
        if not rows or len({r["id"] for r in rows}) != len(rows):
            raise ValueError("current_legacy_inventory_required")
        for row in rows:
            UUID(row["id"])
            if not re.fullmatch("[a-f0-9]{64}", row["row_sha256"]):
                raise ValueError("current_legacy_row_hash_required")
    inputs[str(current_production_capture)] = digest(
        current_production_capture.read_bytes()
    )
    plan = {
        "format": FORMAT,
        "project_id": PROJECT,
        "source_commit": COMMIT,
        "generator_sha256": digest(Path(__file__).read_bytes()),
        "inputs": inputs,
        "operation_counts": dict(Counter(o["action"] for o in operations)),
        "production_baseline": list(current.values()),
        "production_snapshot_baseline": json.loads(
            (evidence / "production_snapshot_provenance_20261101.json").read_text(
                "utf8"
            )
        )["rows"],
        "production_legacy_fullrows": legacy,
        "current_production_capture_observed_at": fresh["observed_at"],
        "current_legacy_snapshot_count": len(legacy["snapshots"]),
        "current_legacy_document_count": len(legacy["documents"]),
        "production_offline_render_supported": True,
        "compensating_rollback_supported": True,
        "baseline_heads": 745,
        "preserve_outside_desired": 51,
        "existing_heads_never_advanced": 694,
        "published_pointer_writes": 0,
        "hosted_execution_supported": False,
        "operation_bindings": [
            {k: v for k, v in o.items() if k != "payload"} for o in operations
        ],
    }
    plan = seal_plan(plan, operations)
    write_rows(output / "operations.jsonl.gz", operations)
    (output / "plan.json").write_text(
        json.dumps(plan, ensure_ascii=False, indent=2) + "\n", "utf8"
    )
    (output / "REVIEW_ONLY.sql").write_text(render_sql(plan, operations), "utf8")
    review_sql_receipt = write_review_sql(
        output / "PRODUCTION_REVIEW_ONLY.sql.gz", plan, operations
    )
    (output / "review-sql-receipt.json").write_text(
        json.dumps(review_sql_receipt, indent=2) + "\n", "utf8"
    )
    template = {f: None for f in RECEIPT_FIELDS}
    template.update(
        project_id=PROJECT,
        source_commit=COMMIT,
        source_commit_role="historical_base",
        execution_scope="approved_isolated_restore",
        operation="apply_unverified_drafts",
        actor_id=None,
        actor_role=None,
        package_sha256=plan["package_sha256"],
        human_decisions_sha256=digest(canonical([])),
        approved_ddl_event_callbacks=[],
        ddl_event_callback_review_receipt_file=None,
        ddl_event_callback_review_receipt_sha256=None,
        restore_endpoint={
            "server_addr": "127.0.0.1",
            "server_port": None,
            "database": None,
            "system_identifier": None,
        },
    )
    callback_template = {
        "schema_version": 1,
        "project_id": PROJECT,
        "package_sha256": plan["package_sha256"],
        "generator_sha256": GENERATOR_AT_IMPORT,
        "reviewer_id": None,
        "operation": None,
        "approved_policy_sha256": None,
        "reviewed_no_external_row_mutation": False,
    }
    (output / "ddl-event-callback-review.template.json").write_text(
        json.dumps(callback_template, indent=2) + "\n", "utf8"
    )
    (output / "restore-authorization.template.json").write_text(
        json.dumps(template, indent=2) + "\n", "utf8"
    )
    production_template = copy.deepcopy(template)
    production_template.update(
        execution_scope="approved_production",
        authorization_kind=None,
        recovery_evidence_kind=None,
        production_api_origin="https://" + PROJECT + ".supabase.co",
        generator_sha256=GENERATOR_AT_IMPORT,
        final_candidate_commit=None,
        final_delivery_receipt_file=None,
        final_delivery_receipt_sha256=None,
        receipt_files={f: None for f in RECEIPT_FIELDS},
    )
    production_template["restore_endpoint"]["server_addr"] = None
    (output / "production-authorization.template.json").write_text(
        json.dumps(production_template, indent=2) + "\n", "utf8"
    )
    rollback_template = copy.deepcopy(template)
    rollback_template.update(
        operation="compensating_rollback",
        compensating_rollback_authorization_sha256=None,
        compensating_rollback_authorization_file=None,
    )
    (output / "compensating-rollback-authorization.template.json").write_text(
        json.dumps(rollback_template, indent=2) + "\n", "utf8"
    )
    write_rows(
        output / "human-decisions.template.jsonl.gz",
        [
            {
                "article_id": o["article_id"],
                "locale": o["locale"],
                "decision": None,
                "payload_sha256": o["payload_sha256"],
                "current_head": o["expected_current"]["head_id"],
                "current_body_md5": o["expected_current"]["body_md5"],
                "case_sha256": o["review_case"]["case_sha256"],
                "review_payload_sha256": o["review_case"]["payload_sha256"],
                "desired_article_sha256": o["review_case"]["desired_article_sha256"],
                "reviewer_id": None,
                "review_receipt_sha256": None,
            }
            for o in operations
            if o["action"] == "PENDING_HUMAN_RECONCILIATION"
        ],
    )
    (output / "README.md").write_text(
        """# Production-specific additive draft review package

Exactly 1100 desired keys: 406 new unverified draft candidates, 443 detached rich candidates for semantic matches, 251 differing existing keys awaiting individual human choices. Preserve all 745 existing heads, all existing revisions/authors/publication pointers, and all 51 outside desired keys. No existing head is adopted or advanced. A separately hash-bound compatibility supplement preserves optimistic concurrency on the locked current head while allocating MAX(revision)+1 across existing and detached revisions; ordinary Admin save and rollback continue working.

PRODUCTION_REVIEW_ONLY.sql.gz is the complete concrete 849-operation SQL, with real 745-head, relational-section and current captured snapshot/document row guards. Its mandatory first exception aborts the single transaction before any DDL/DML; it ends ROLLBACK. The remaining 251 choices are omitted. No actor or endpoint is fabricated. review-sql-receipt.json seals both plain and compressed SQL. REVIEW_ONLY.sql is the short refusing entrypoint.

Copy all authorization, decision and callback-review templates to separate private files before completing them. Editing sealed originals invalidates artifact seals.

Every enabled database event callback is refused before the first import or compensation DDL unless separately owner-reviewed for that exact operation. An optional approved_ddl_event_callbacks list binds each event name to a complete metadata/function-source-MD5/config/owner/security-state SHA. The separate review receipt must bind exact policy hash, project/package/generator, actual reviewer actor and operation and explicitly attest reviewed_no_external_row_mutation=true. The initial application catalog fingerprint must still match at compensation. Blank policies approve nothing. Current managed callbacks remain an owner secure-review dependency; no callback source is exported or approved by name/hash alone.

This tool only reads local files and writes SQL; it never connects or executes. render-approved-restore permits explicitly approved isolated loopback rehearsal. render-approved-production is an OFFLINE future-owner gate, requiring explicit future owner approval, verified real Production checkpoint declarations, exact bytes of all six recovery/owner/forward receipt files, final delivery receipt and final candidate commit, exact package/generator hashes, real endpoint/server identity and an existing human Admin actor. Both enforce exact runtime assertions and physical Postgres address/port/database/system identifier and actual JWT/profile actor. Blank templates are invalid. No active Production authorization or real checkpoint proof is supplied here. Hashes and typed declarations are assertions; an independent owner must verify the referenced recovery/restore evidence.

source_commit 81f11ce176d9645ae0503e360e22ef6a414c355b is historical_base, not the final code candidate. Generator SHA and a separately approved final delivery/commit receipt bind new code without a circular self-commit.

Every differing-key choice binds exact candidate payload, review-case SHA, current head/body, actual existing Admin reviewer and review receipt. Choices keep_current/create_detached_draft never approve, verify, adopt or publish. Source provenance is not legal or factual verification. The initial application locks its actor and exact decision-set hash; exact retries cannot expand that initial receipt or claim later human rows/tables.

Narrow Admin-only list_production_reconciliation_drafts and get_production_reconciliation_draft discover package drafts and read complete body plus pinned rich composition. Existing RPC collisions refuse. Anonymous, service-role and authenticated non-Admin callers cannot read these bodies. No staging import RPC is reused.

render-compensating-rollback requires separate explicit owner/recovery/actor/package authorization. The journal identifies only newly created unchanged rows. It refuses any later public/private application write, publication, table-set change, modified owned row, changed append-only guard, or inbound foreign key from an external schema. It locks the application tables and temporarily disables only the five known append-only guards inside the exact-state deletion transaction, restoring them before commit. It removes only own unchanged drafts/heads/catalog/provenance; existing rows/heads/authors/publication pointers survive. Rollback audit fingerprints/tombstones and reader functions remain. Exact compensation retries are no-ops; an already compensated package cannot be imported again. This intentionally conservative immediate compensation may refuse after unrelated application activity; coordinated database/Storage/Auth checkpoint recovery remains separate.

Rebuild from repository root with python -m scripts.production_reconciliation_package prepare and rebuild_arguments in reproducibility.json. No browser, paid calls, hosted writes, approval, legal verification, publication or deployment is performed.
""",
        "utf8",
    )
    (output / "reproducibility.json").write_text(
        json.dumps(
            {
                "project_id": PROJECT,
                "source_commit": COMMIT,
                "source_commit_role": "historical_base",
                "generator_sha256": plan["generator_sha256"],
                "package_sha256": plan["package_sha256"],
                "operation_counts": plan["operation_counts"],
                "production_baseline_heads": len(current),
                "outside_desired_preserved": len(current.keys() - dispositions.keys()),
                "body_review_cases": len(review_cases),
                "current_legacy_snapshot_count": len(legacy["snapshots"]),
                "current_legacy_document_count": len(legacy["documents"]),
                "human_decisions_supplied": 0,
                "hosted_execution_supported": False,
                "execution_performed": False,
                "inputs": inputs,
                "rebuild_arguments": {
                    "composition": [str(p) for p in compositions],
                    "evidence": str(evidence),
                    "review_cases": str(review_cases_path),
                    "ready_payloads": [str(p) for p in ready_payloads],
                    "current_production_capture": str(current_production_capture),
                },
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        "utf8",
    )
    if digest(Path(__file__).read_bytes()) != GENERATOR_AT_IMPORT:
        raise ValueError("generator_changed_during_run")
    for filename, expected in inputs.items():
        if digest(Path(filename).read_bytes()) != expected:
            raise ValueError("input_changed_during_run:" + filename)
    seal = {p.name: digest(p.read_bytes()) for p in output.iterdir() if p.is_file()}
    (output / "artifact-seals.json").write_text(
        json.dumps(seal, indent=2) + "\n", "utf8"
    )
    return plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("prepare")
    create.add_argument("--composition", action="append", type=Path, required=True)
    create.add_argument("--evidence", type=Path, required=True)
    create.add_argument("--output", type=Path, required=True)
    create.add_argument("--review-cases", type=Path, required=True)
    create.add_argument("--ready-payloads", type=Path, action="append", required=True)
    create.add_argument("--current-production-capture", type=Path, required=True)
    for command in (
        "render-approved-restore",
        "render-approved-production",
        "render-compensating-rollback",
    ):
        render = sub.add_parser(command)
        render.add_argument("--package", type=Path, required=True)
        render.add_argument("--authorization", type=Path, required=True)
        render.add_argument("--decisions", type=Path)
        render.add_argument("--output", type=Path, required=True)
        if command == "render-compensating-rollback":
            render.add_argument(
                "--execution-scope",
                choices=["approved_isolated_restore", "approved_production"],
                default="approved_isolated_restore",
            )
    args = parser.parse_args()
    if args.command == "prepare":
        plan = prepare(
            args.composition,
            args.evidence,
            args.output,
            args.review_cases,
            args.ready_payloads,
            args.current_production_capture,
        )
        print(
            json.dumps(
                {
                    k: plan[k]
                    for k in ("project_id", "package_sha256", "operation_counts")
                }
            )
        )
    else:
        seals = json.loads((args.package / "artifact-seals.json").read_text("utf8"))
        for filename, expected in seals.items():
            if digest((args.package / filename).read_bytes()) != expected:
                raise ValueError("package_artifact_tampered:" + filename)
        plan = json.loads((args.package / "plan.json").read_text("utf8"))
        bound = dict(plan)
        expected = bound.pop("package_sha256")
        if digest(canonical(bound)) != expected:
            raise ValueError("package_plan_hash_mismatch")
        auth = json.loads(args.authorization.read_text("utf8"))
        decisions = list(read_rows(args.decisions)) if args.decisions else []
        operations = list(read_rows(args.package / "operations.jsonl.gz"))
        if args.command == "render-compensating-rollback":
            if decisions:
                raise ValueError("compensation_uses_initial_journal_decision_set")
            sql = render_rollback_sql(plan, operations, auth, args.execution_scope)
        else:
            scope = (
                "approved_production"
                if args.command == "render-approved-production"
                else "approved_isolated_restore"
            )
            sql = render_sql(plan, operations, auth, decisions, scope)
        with args.output.open("x", encoding="utf8", newline="\n") as stream:
            stream.write(sql)
        print(
            json.dumps(
                {
                    "sql_sha256": digest(args.output.read_bytes()),
                    "execution_performed": False,
                }
            )
        )


if __name__ == "__main__":
    main()
