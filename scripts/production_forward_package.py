"""Offline Production-targeted CMS/research forward review package.

This tool performs no SQL, network access, content import, history repair or
authority approval. Executable hosted application remains explicitly blocked.
"""

import argparse
import hashlib
import json
import re
from pathlib import Path

ROLES = ("PUBLIC", "anon", "authenticated", "service_role")
PRODUCTION_PROJECT = "inshddthftkhcdosoqcn"
ROOT_NAMES = [
    "get_editorial_article",
    "list_editorial_library",
    "list_editorial_articles",
    "list_editorial_relations",
    "list_country_visa_content",
    "list_visa_content_countries",
    "list_editorial_review_queue",
    "review_country_other_title",
    "list_related_visa_articles",
    "resolve_editorial_article_slug",
    "get_editorial_reference_links",
    "get_editorial_link_review",
    "get_editorial_source_snapshot",
    "get_visa_article",
    "search_visa_articles",
    "list_cms_articles",
    "get_cms_article_draft",
    "create_visa_article",
    "save_visa_article_draft",
    "submit_visa_article_review",
    "approve_visa_article_revision",
    "reject_visa_article_revision",
    "publish_visa_article_revision",
    "rollback_visa_article",
    "list_visa_article_revisions",
    "approve_visa_source_inventory",
    "propose_editorial_relations",
    "review_editorial_relation",
    "clear_editorial_revision",
    "list_official_authorities",
    "discover_official_authorities",
    "enqueue_research_refresh",
    "list_research_proposals",
    "get_research_proposal",
    "get_research_review_context",
    "get_research_review_context_v2",
    "review_research_proposal",
    "save_research_review",
    "save_structured_research_review",
    "propose_structured_research",
    "get_structured_article_context",
    "upsert_editorial_research_source",
    "create_official_refresh_binding",
    "get_bound_official_refresh_targets",
    "renew_bound_official_refresh_lease",
    "yield_bound_official_refresh",
    "ingest_bound_official_refresh",
    "claim_official_research_job",
    "get_official_research_job",
    "finish_official_research_job",
    "get_research_article_base",
    "record_official_source_change",
    "attach_editorial_reference_map",
]


def qi(s):
    return '"' + s.replace('"', '""') + '"'


def qn(s):
    return ".".join(qi(p) for p in s.split("."))


def lit(s):
    return "'" + s.replace("'", "''") + "'"


def name(o):
    return o["schema"] + "." + o["name"]


def fkey(o):
    return name(o) + "(" + o["identity"] + ")"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def refs(text):
    return set(re.findall(r"\b(?:public|private)\.[a-z_][a-z_0-9]*", text))


def norm(o):
    return json.dumps(o, sort_keys=True, separators=(",", ":"))


def indexes(cat):
    tables = {name(t): t for t in cat["tables"]}
    functions = {fkey(f): f for f in cat["functions"]}
    by_name = {}
    for k, f in functions.items():
        by_name.setdefault(name(f), set()).add(k)
    return tables, functions, by_name


def build_package(
    input_dir: Path, output_dir: Path, source_sha: str, *, roots=ROOT_NAMES
):
    if not re.fullmatch("[a-f0-9]{40}", source_sha):
        raise ValueError("An exact source commit SHA is required")
    INPUT, ROOT = Path(input_dir), Path(output_dir)
    ROOT.mkdir(parents=True, exist_ok=True)
    PROD = json.loads((INPUT / "production_catalog.json").read_text(encoding="utf-8"))
    CAND = json.loads((INPUT / "candidate_catalog.json").read_text(encoding="utf-8"))
    SCHEMAS = {
        r["name"]: r["schema"]
        for r in json.loads(
            (INPUT / "candidate_contract_schemas.json").read_text(encoding="utf-8")
        )
    }
    LIVE_SCHEMAS = {
        r["name"]: r["schema"]
        for r in json.loads(
            (INPUT / "production_contract_schemas.json").read_text(encoding="utf-8")
        )
    }
    SOURCE, ROOT_NAMES = source_sha, tuple(roots)
    PT, PF, _PN = indexes(PROD)
    CT, CF, CN = indexes(CAND)
    selected_f, selected_t, edges = set(), set(), set()
    pending = ["public." + s for s in ROOT_NAMES]
    missing_roots = [s for s in pending if s not in CN]
    if missing_roots:
        raise ValueError("Missing candidate roots: " + str(missing_roots))
    while pending:
        item = pending.pop()
        for fk in CN.get(item, set()):
            if fk in selected_f:
                continue
            selected_f.add(fk)
            for dep in refs(CF[fk]["definition"]) - {item}:
                edges.add((fk, dep))
                pending.append(dep)
        if item in CT and item not in selected_t:
            selected_t.add(item)
            t = CT[item]
            # FK dependencies matter when a relation/column/constraint is introduced.
            old = PT.get(item)
            text = norm(t)
            for dep in refs(text) - {item}:
                if dep in CN:
                    edges.add((item, dep))
                    pending.append(dep)
            if not old:
                for k in t["constraints"]:
                    if k["references"] and k["references"].split(".")[0] in (
                        "public",
                        "private",
                    ):
                        edges.add((item, k["references"]))
                        pending.append(k["references"])

    changes = {
        "extensions": [],
        "new_tables": [],
        "new_functions": [],
        "replaced_functions": [],
        "added_columns": [],
        "constraints": [],
        "indexes": [],
        "triggers": [],
        "policies": [],
        "acl_review": [],
        "retained_drift": [],
    }
    # A project GUC is an operator assertion, not proof of the network endpoint.
    # Require it AND the captured function baseline before the first mutation.
    # Hosted execution remains blocked by the review wrapper independently.
    guards = [
        "do $rad_forward_guard$ begin",
        "if current_setting('rad.expected_project',true) is distinct from "
        + lit(PRODUCTION_PROJECT)
        + " then raise exception 'FORWARD_TARGET_ASSERTION_REQUIRED'; end if;",
    ]
    for fk in sorted(selected_f):
        f, old = CF[fk], PF.get(fk)
        identity_match = (
            "n.nspname="
            + lit(f["schema"])
            + " and p.proname="
            + lit(f["name"])
            + " and pg_get_function_identity_arguments(p.oid)="
            + lit(f["identity"])
        )
        if old:
            predicate = (
                "not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where "
                + identity_match
                + " and md5(p.prosrc)="
                + lit(old["body_md5"])
                + ")"
            )
        else:
            predicate = (
                "exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where "
                + identity_match
                + ")"
            )
        guards.append(
            "if "
            + predicate
            + " then raise exception "
            + lit("FORWARD_BASELINE_MISMATCH: " + fk)
            + "; end if;"
        )
    for tn in sorted(selected_t - PT.keys()):
        guards.append(
            "if to_regclass("
            + lit(tn)
            + ") is not null then raise exception "
            + lit("FORWARD_BASELINE_MISMATCH: " + tn)
            + "; end if;"
        )
    guards.append("end $rad_forward_guard$;")
    ddl = [
        "-- Exact scope: explicit RPC roots and their qualified dependency closure; see manifest.json.",
        "-- No content import, authority seed, publication, provider toggle, or history repair.",
        *guards,
        "set local search_path=public,extensions,pg_catalog;",
        "set local check_function_bodies=off;",
        "set local lock_timeout='5s';",
        "set local statement_timeout='120s';",
        "create schema if not exists private authorization postgres;",
    ]
    if any(
        re.search(r"\b(?:gin|gist)_trgm_ops\b", norm(CT[tn])) for tn in selected_t
    ) and not any(e["name"] == "pg_trgm" for e in PROD["extensions"]):
        ddl.append("create extension if not exists pg_trgm with schema extensions;")
        changes["extensions"].append("pg_trgm")

    def column_sql(c, with_default=False):
        value = qi(c["name"]) + " " + c["type"]
        if c["identity"]:
            value += (
                " generated "
                + ("always" if c["identity"] == "a" else "by default")
                + " as identity"
            )
        elif c["generated"]:
            value += " generated always as (" + c["default"] + ") stored"
        elif with_default and c["default"]:
            value += " default " + c["default"]
        if c["not_null"]:
            value += " not null"
        return value

    new_columns = []
    # Generated columns are parsed immediately even with function-body checking off.
    # Install scalar helper definitions before relation creation; row-type signatures
    # wait until their relations exist. All DDL remains in one transaction.
    early_functions = set()
    for fk in sorted(selected_f):
        f = CF[fk]
        signature = f["arguments"] + " " + f["result"]
        # pg_get_function_arguments may dequalify a public composite type under
        # the capture search_path. Its relation must exist even when body checks
        # are disabled. Conservatively defer any matching new relation name.
        new_row_type = any(
            re.search(r"\b" + re.escape(CT[tn]["name"]) + r"\b", signature)
            for tn in selected_t - PT.keys()
        )
        if fk not in PF and not new_row_type:
            ddl.append(f["definition"].rstrip().rstrip(";") + ";")
            early_functions.add(fk)
    for tn in sorted(selected_t):
        t, old = CT[tn], PT.get(tn)
        if not old:
            ddl.append(
                "create table "
                + qn(tn)
                + "(\n "
                + ",\n ".join(column_sql(c) for c in t["columns"])
                + "\n);"
            )
            changes["new_tables"].append(tn)
            new_columns.extend((tn, c) for c in t["columns"])
        else:
            oc = {c["name"]: c for c in old["columns"]}
            for c in t["columns"]:
                if c["name"] not in oc:
                    ddl.append(
                        "alter table "
                        + qn(tn)
                        + " add column "
                        + column_sql(c, True)
                        + ";"
                    )
                    changes["added_columns"].append(tn + "." + c["name"])
                elif any(c[a] != oc[c["name"]][a] for a in ("type", "not_null")):
                    # Preserve existing NULL/legacy data; never invent validation.
                    changes["retained_drift"].append(
                        {
                            "column": tn + "." + c["name"],
                            "production": oc[c["name"]],
                            "candidate": c,
                            "action": "retain existing definition; independent data disposition required before tightening",
                        }
                    )

    for fk in sorted(selected_f):
        f, old = CF[fk], PF.get(fk)
        same_definition = old and f["definition"] == old["definition"]
        same_acl = old and norm([g for g in f["grants"] if g["role"] in ROLES]) == norm(
            [g for g in old["grants"] if g["role"] in ROLES]
        )
        if same_definition and same_acl and f["owner"] == old["owner"]:
            continue
        if not same_definition and fk not in early_functions:
            ddl.append(f["definition"].rstrip().rstrip(";") + ";")
        target = qn(name(f)) + "(" + f["identity"] + ")"
        ddl.append("alter function " + target + " owner to " + qi(f["owner"]) + ";")
        ddl.append(
            "revoke all on function " + target + " from " + ",".join(ROLES) + ";"
        )
        for grant in f["grants"]:
            if grant["role"] in ROLES:
                role = grant["role"] if grant["role"] == "PUBLIC" else qi(grant["role"])
                ddl.append(
                    "grant execute on function "
                    + target
                    + " to "
                    + role
                    + (" with grant option" if grant["grantable"] else "")
                    + ";"
                )
        changes["replaced_functions" if old else "new_functions"].append(
            {
                "key": fk,
                "old_body_md5": old["body_md5"] if old else None,
                "new_body_md5": f["body_md5"],
            }
        )

    for tn, c in new_columns:
        if c["default"] and not c["identity"] and not c["generated"]:
            ddl.append(
                "alter table "
                + qn(tn)
                + " alter column "
                + qi(c["name"])
                + " set default "
                + c["default"]
                + ";"
            )

    constraint_additions = []
    for tn in sorted(selected_t):
        t, old = CT[tn], PT.get(tn)
        if t["rls"]:
            ddl.append("alter table " + qn(tn) + " enable row level security;")
        if t["force_rls"]:
            ddl.append("alter table " + qn(tn) + " force row level security;")
        for group in ("constraints", "indexes", "triggers", "policies"):
            before = {v["name"]: v for v in old[group]} if old else {}
            for obj in t[group]:
                prev = before.get(obj["name"])
                if prev == obj or (group == "indexes" and obj["constraint"]):
                    continue
                if group == "constraints":
                    if prev:
                        changes["retained_drift"].append(
                            {
                                "constraint": tn + "." + obj["name"],
                                "production": prev,
                                "candidate": obj,
                                "action": "retain existing constraint; semantic/data review required",
                            }
                        )
                        continue
                    constraint_additions.append((obj["type"] == "f", tn, obj))
                    changes[group].append(tn + "." + obj["name"])
                elif group == "indexes":
                    if prev:
                        changes["retained_drift"].append(
                            {
                                "index": tn + "." + obj["name"],
                                "action": "retain existing name collision; definition review required",
                            }
                        )
                        continue
                    ddl.append(obj["definition"] + ";")
                    changes[group].append(tn + "." + obj["name"])
                elif group == "triggers":
                    if prev:
                        ddl.append(
                            "drop trigger " + qi(obj["name"]) + " on " + qn(tn) + ";"
                        )
                    ddl.append(obj["definition"] + ";")
                    changes[group].append(tn + "." + obj["name"])
                else:
                    if prev:
                        ddl.append(
                            "drop policy " + qi(obj["name"]) + " on " + qn(tn) + ";"
                        )
                    command = {
                        "*": "ALL",
                        "r": "SELECT",
                        "a": "INSERT",
                        "w": "UPDATE",
                        "d": "DELETE",
                    }[obj["command"]]
                    roles = ",".join(
                        r if r == "PUBLIC" else qi(r) for r in obj["roles"]
                    )
                    policy = (
                        "create policy "
                        + qi(obj["name"])
                        + " on "
                        + qn(tn)
                        + " as "
                        + ("permissive" if obj["permissive"] else "restrictive")
                        + " for "
                        + command
                        + " to "
                        + roles
                    )
                    if obj["using"]:
                        policy += " using (" + obj["using"] + ")"
                    if obj["check"]:
                        policy += " with check (" + obj["check"] + ")"
                    ddl.append(policy + ";")
                    changes[group].append(tn + "." + obj["name"])
        old_app_grants = [g for g in old["grants"] if g["role"] in ROLES] if old else []
        new_app_grants = [g for g in t["grants"] if g["role"] in ROLES]
        if not old or norm(old_app_grants) != norm(new_app_grants):
            changes["acl_review"].append(
                {"table": tn, "old": old_app_grants, "candidate": new_app_grants}
            )
            ddl.append(
                "revoke all on table " + qn(tn) + " from " + ",".join(ROLES) + ";"
            )
            for g in new_app_grants:
                ddl.append(
                    "grant "
                    + g["privilege"]
                    + " on table "
                    + qn(tn)
                    + " to "
                    + (g["role"] if g["role"] == "PUBLIC" else qi(g["role"]))
                    + (" with grant option" if g["grantable"] else "")
                    + ";"
                )

    # Referenced functions exist before CHECK constraints. Primary/unique keys must
    # precede FKs; all constraints apply to the restored-data rehearsal before GO.
    for _, tn, c in sorted(
        constraint_additions, key=lambda v: (v[0], v[1], v[2]["name"])
    ):
        ddl.append(
            "alter table "
            + qn(tn)
            + " add constraint "
            + qi(c["name"])
            + " "
            + c["definition"]
            + ";"
        )

    required_schemas = set()
    for fk in selected_f:
        f = CF[fk]
        for base in [f["name"], *re.findall(r"'(\w+)'", f["definition"])]:
            for suffix in ("_request", "_response"):
                if base + suffix in SCHEMAS:
                    required_schemas.add(base + suffix)
    for _ in range(len(SCHEMAS)):
        expanded = {
            ref.split("/")[-1]
            for n in required_schemas
            for ref in re.findall(r'"\$ref":\s*"([^"]+)"', json.dumps(SCHEMAS[n]))
        }
        prior = len(required_schemas)
        required_schemas.update(expanded & SCHEMAS.keys())
        if len(required_schemas) == prior:
            break
    if "private.rad_contract_schemas" in selected_t:
        for sn in sorted(required_schemas):
            if sn in LIVE_SCHEMAS:
                if SCHEMAS[sn] != LIVE_SCHEMAS[sn]:
                    changes["retained_drift"].append(
                        {
                            "schema_definition": sn,
                            "action": "retain current configuration; explicit schema compatibility review required",
                        }
                    )
                continue
            ddl.append(
                "insert into private.rad_contract_schemas(name,schema) values("
                + lit(sn)
                + ","
                + lit(json.dumps(SCHEMAS[sn], ensure_ascii=False))
                + "::jsonb) on conflict(name) do nothing;"
            )
    ddl += ["notify pgrst,'reload schema';"]
    body = "\n".join(ddl) + "\n"
    (ROOT / "forward_body.sql").write_text(body, encoding="utf-8", newline="\n")
    review = (
        "-- REVIEW ONLY: no current approved Production backup/restore exists.\nbegin;\ndo $$begin raise exception 'REVIEW_ONLY_RECOVERY_AND_OWNER_AUTHORIZATION_REQUIRED';end$$;\n"
        + body
        + "rollback;\n"
    )
    (ROOT / "FORWARD_REVIEW_ONLY.sql").write_text(
        review, encoding="utf-8", newline="\n"
    )
    manifest = {
        "source_sha": SOURCE,
        "production_project": PRODUCTION_PROJECT,
        "execution_allowed": False,
        "scope": "Explicit RPC roots and conservative qualified SQL dependency closure; no historical replay/data import/authority seed",
        "roots": ROOT_NAMES,
        "selected_functions": sorted(selected_f),
        "selected_tables": sorted(selected_t),
        "dependency_edges": sorted(edges),
        "changes": changes,
        "contract_schemas": sorted(required_schemas),
        "limitations": [
            "Static lexical closure supplements catalog dependencies, not proof of every dynamic SQL branch.",
            "Only application roles PUBLIC/anon/authenticated/service_role are reconciled; managed-role grants are preserved.",
            "Existing data/nullability/name-collision drift retained explicitly; no invented validation classifications.",
            "Synthetic catalog reconstruction is not a Production backup/restore or existing-data compatibility proof.",
            "rad.expected_project is a required operator assertion, not independently verified endpoint identity; review wrapper always refuses execution.",
            "Function guards check captured body hashes and new-object absence; fresh full catalog/ACL/data comparison remains required before any hosted execution.",
            "Legacy column-level grants are preserved; table-level ACL review does not certify column-level authorization.",
        ],
        "constraint_gates": [
            {
                "column": d["column"],
                "action": "BLOCK_NULLABILITY_TIGHTENING_PENDING_EXPLICIT_DATA_DISPOSITION",
                "preserve_existing_nulls": True,
            }
            for d in changes["retained_drift"]
            if d.get("column") == "public.source_documents.validation_status"
        ],
        "inputs": {
            f: sha(INPUT / f)
            for f in (
                "production_catalog.json",
                "candidate_catalog.json",
                "candidate_contract_schemas.json",
                "production_contract_schemas.json",
                "production_preconditions.json",
            )
        },
        "forward_body_sha256": sha(ROOT / "forward_body.sql"),
        "review_file_sha256": sha(ROOT / "FORWARD_REVIEW_ONLY.sql"),
    }
    (ROOT / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inputs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-sha", required=True)
    args = parser.parse_args()
    result = build_package(args.inputs, args.output, args.source_sha)
    print(
        json.dumps(
            {
                "execution_allowed": result["execution_allowed"],
                "changes": {k: len(v) for k, v in result["changes"].items()},
                "forward_sha256": result["forward_body_sha256"],
            }
        )
    )


if __name__ == "__main__":
    main()
