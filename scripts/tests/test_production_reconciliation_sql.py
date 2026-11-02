"""Real PostgreSQL tests on a new owned loopback cluster, never a hosted restore."""

import copy
import gzip
import hashlib
import json
import os
import subprocess
import unittest
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

from scripts import production_reconciliation_package as package


class ReconciliationSQLTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo = Path(__file__).resolve().parents[2]
        cls.evidence = (
            cls.repo.parent / "_audit/RAD_MASTER_CONVERGENCE_20261031/db_forward_review"
        )
        cls.bin = Path("C:/Program Files/PostgreSQL/17/bin")
        if not cls.bin.exists():
            raise unittest.SkipTest("PostgreSQL17 local runtime not installed")
        if not all(
            (cls.evidence / f).is_file()
            for f in ("synthetic-production-catalog.sql", "forward_body.sql")
        ):
            raise unittest.SkipTest(
                "sealed local synthetic Production fixtures not available"
            )
        cls.root = cls.evidence / (
            "production_reconciliation_sql_rehearsal_"
            + datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
            + "_"
            + uuid4().hex[:8]
        )
        cls.root.mkdir()
        cls.data = cls.root / "data"
        cls.started = False
        cls.start_attempted = False
        (cls.root / "ownership.json").write_text(
            json.dumps(
                {
                    "owner": "production_reconciliation_sql_test",
                    "data_directory": str(cls.data.resolve()),
                    "port": 64938,
                    "synthetic_only": True,
                },
                indent=2,
            ),
            "utf8",
        )
        cls.env = {
            k: v for k, v in os.environ.items() if not k.upper().startswith("PG")
        }
        cls.env.update(
            PGHOSTADDR="127.0.0.1", PGCONNECT_TIMEOUT="5", PGCLIENTENCODING="UTF8"
        )
        try:
            cls.command(
                "initdb.exe",
                [
                    "-D",
                    str(cls.data),
                    "-U",
                    "postgres",
                    "-A",
                    "trust",
                    "--no-locale",
                    "-E",
                    "UTF8",
                ],
            )
            cls.start_attempted = True
            cls.command(
                "pg_ctl.exe",
                [
                    "-D",
                    str(cls.data),
                    "-l",
                    str(cls.root / "postgres.log"),
                    "-o",
                    "-h 127.0.0.1 -p 64938 -c max_connections=10 -c shared_buffers=16MB",
                    "-w",
                    "start",
                ],
            )
            cls.started = True
            cls.sql(
                "create role anon;create role authenticated;create role service_role;create role supabase_auth_admin;create role supabase_admin;"
            )
            cls.sql(
                (cls.evidence / "synthetic-production-catalog.sql").read_text("utf8")
            )
            cls.sql(
                "begin;set local rad.expected_project='inshddthftkhcdosoqcn';"
                + (cls.evidence / "forward_body.sql").read_text("utf8")
                + "commit;"
            )
        except BaseException:
            cls.tearDownClass()
            raise

    @classmethod
    def command(cls, exe, args, sql=None):
        if exe == "pg_ctl.exe":
            # Windows descendants may inherit pipes. A real log file lets the
            # startup command finish while its server remains in this process job.
            with (cls.root / "pg_ctl.log").open("a+", encoding="utf8") as log:
                p = subprocess.run(
                    [str(cls.bin / exe), *args],
                    stdout=log,
                    stderr=log,
                    env=cls.env,
                    timeout=45,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                )
                log.seek(0)
                output = log.read()
            if p.returncode:
                raise RuntimeError(output[-3000:])
            return output
        p = subprocess.run(
            [str(cls.bin / exe), *args],
            input=sql,
            text=True,
            encoding="utf8",
            capture_output=True,
            env=cls.env,
            timeout=180,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        if p.returncode:
            raise RuntimeError(p.stderr[-3000:] + p.stdout[-1000:])
        return p.stdout.strip()

    @classmethod
    def sql(cls, sql, error=None):
        args = [
            "-XAtqw",
            "-h",
            "127.0.0.1",
            "-p",
            "64938",
            "-U",
            "postgres",
            "-d",
            "postgres",
            "-v",
            "ON_ERROR_STOP=1",
        ]
        if error:
            p = subprocess.run(
                [str(cls.bin / "psql.exe"), *args],
                input=sql,
                text=True,
                encoding="utf8",
                capture_output=True,
                env=cls.env,
                timeout=60,
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
            if p.returncode == 0 or error not in p.stderr:
                raise AssertionError((error, p.returncode, p.stderr[-3000:]))
            return p.stderr
        return cls.command("psql.exe", args, sql)

    @classmethod
    def tearDownClass(cls):
        stopped = not getattr(cls, "start_attempted", False)
        if getattr(cls, "start_attempted", False):
            marker = json.loads((cls.root / "ownership.json").read_text("utf8"))
            if (
                marker["data_directory"] != str(cls.data.resolve())
                or marker["port"] != 64938
            ):
                raise AssertionError("owned_cluster_marker_mismatch")

            def status():
                return subprocess.run(
                    [str(cls.bin / "pg_ctl.exe"), "-D", str(cls.data), "status"],
                    capture_output=True,
                    env=cls.env,
                    timeout=15,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                ).returncode

            current = status()
            if current == 0:
                cls.command(
                    "pg_ctl.exe", ["-D", str(cls.data), "-m", "fast", "-w", "stop"]
                )
            stopped = status() == 3
            cls.started = not stopped
        if hasattr(cls, "root"):
            (cls.root / "shutdown-receipt.json").write_text(
                json.dumps(
                    {
                        "owned_data_directory": str(cls.data),
                        "server_stopped": stopped,
                        "start_attempted": getattr(cls, "start_attempted", False),
                        "port": 64938,
                        "retained_for_review": True,
                    },
                    indent=2,
                ),
                "utf8",
            )
        if not stopped:
            raise AssertionError("owned_cluster_shutdown_not_verified")

    def ready(self, article, text="Exact source paragraph"):
        source = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        snapshot = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        return {
            "item": {
                "article_id": article,
                "locale": "en",
                "editorial_state": "draft",
                "verification_state": "unverified",
                "publication_allowed": False,
                "published": False,
                "reviewer_id": None,
                "content_class": "editorial",
                "category": "general-guide",
                "country_codes": [],
                "draft_request": {
                    "article_id": article,
                    "locale": "en",
                    "title": "Candidate",
                    "summary": "",
                    "expected_revision": 0,
                    "merge_manifest_id": None,
                    "related_article_ids": [],
                    "request_key": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
                    "sections": [
                        {
                            "id": "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
                            "anchor": "content-1",
                            "heading": "Title",
                            "order": 0,
                            "blocks": [
                                {
                                    "id": "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
                                    "type": "paragraph",
                                    "text": text,
                                    "items": [],
                                }
                            ],
                            "evidence_refs": [
                                {
                                    "snapshot_id": snapshot,
                                    "claim_id": None,
                                    "excerpt": text,
                                    "locator": "source-block:0:0:22",
                                }
                            ],
                        }
                    ],
                },
            },
            "sources": [
                {
                    "source_id": source,
                    "snapshot_id": snapshot,
                    "content_source_id": "ffffffff-ffff-4fff-8fff-ffffffffffff",
                    "url": "https://radvisa.com/test-reconciliation/",
                    "title": "Source",
                    "language": "en",
                    "retrieved_at": "2026-10-01T00:00:00Z",
                    "body_text": text,
                    "body_sha256": hashlib.sha256(text.encode()).hexdigest(),
                    "raw_html_sha256": "a" * 64,
                }
            ],
        }

    def test_execution_guards_atomic_import_retry_and_immutable_old_rows(self):
        actor = "33333333-3333-4333-8333-333333333333"
        article = "11111111-1111-4111-8111-111111111111"
        existing = "22222222-2222-4222-8222-222222222222"
        oldrev = "99999999-9999-4999-8999-999999999999"
        self.sql(
            'set request.jwt.claims=\'{"role":"service_role"}\';insert into auth.users(id,email)values(\''
            + actor
            + "','synthetic-reconciliation@example.invalid');"
            "insert into public.profiles(id,role)values('" + actor + "','admin');"
            "insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)values('"
            + existing
            + "','related',null,'topic-22222222222242228222222222222222','editorial-"
            + existing
            + "','"
            + actor
            + "');"
            "insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)values('"
            + oldrev
            + "','"
            + existing
            + "','en',1,'Original','',repeat('a',64),'{\"sections\":[]}', '"
            + actor
            + "');"
            "insert into public.visa_article_heads(article_id,locale,head_id,published_id)values('"
            + existing
            + "','en','"
            + oldrev
            + "',null);"
        )
        current = json.loads(
            self.sql(
                "select jsonb_build_object('article_id',h.article_id,'locale',h.locale,'head_id',h.head_id,'published_id',h.published_id,'revision',r.revision,'body_md5',md5(r.body::text),'actor_id_md5',md5(r.created_by::text),'stored_content_hash',r.content_hash,'sections_md5',md5('[]'),'title_summary_md5',md5(jsonb_build_object('title',r.title,'summary',r.summary)::text))from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id;"
            )
        )
        new = package.make_operation(
            self.ready(article), None, "NEW_KEY_DRAFT_CANDIDATE"
        )
        detached = package.make_operation(
            self.ready(existing),
            current,
            "CORE_SEMANTIC_MATCH_RICH_PROJECTION_RECONCILIATION",
        )
        baseline_helper_definition = self.sql(
            "select pg_get_functiondef('private.rad_save_article(jsonb)'::regprocedure);"
        )
        baseline_helper_md5 = self.sql(
            "select md5(prosrc)from pg_proc where oid='private.rad_save_article(jsonb)'::regprocedure;"
        )
        plan = package.seal_plan({"production_baseline": [current]}, [new, detached])
        auth = {f: "2" * 64 for f in package.RECEIPT_FIELDS}
        auth.update(
            project_id=package.PROJECT,
            source_commit=package.COMMIT,
            execution_scope="approved_isolated_restore",
            actor_id=actor,
            actor_role="admin",
            package_sha256=plan["package_sha256"],
            human_decisions_sha256=package.digest(package.canonical([])),
            restore_endpoint={
                "server_addr": "127.0.0.1",
                "server_port": 64938,
                "database": "postgres",
                "system_identifier": self.sql(
                    "select system_identifier from pg_control_system();"
                ),
            },
        )

        def context(authorization):
            values = {
                "rad.expected_project": package.PROJECT,
                "rad.execution_scope": "approved_isolated_restore",
                "rad.package_sha256": authorization["package_sha256"],
                "rad.actor_id": authorization["actor_id"],
                "rad.human_decisions_sha256": authorization["human_decisions_sha256"],
            }
            values.update(
                {"rad." + k: authorization[k] for k in package.RECEIPT_FIELDS}
            )
            if authorization.get("approved_ddl_event_callbacks"):
                values["rad.approved_ddl_event_callbacks_sha256"] = package.digest(
                    package.canonical(authorization["approved_ddl_event_callbacks"])
                )
                values["rad.ddl_event_callback_review_receipt_sha256"] = authorization[
                    "ddl_event_callback_review_receipt_sha256"
                ]
            return (
                "".join(
                    "set " + k + "=" + package.literal(v) + ";"
                    for k, v in values.items()
                )
                + "set request.jwt.claims="
                + package.literal(
                    json.dumps(
                        {"sub": authorization["actor_id"], "role": "authenticated"}
                    )
                )
                + ";"
            )

        prefix = context(auth)
        self.sql(
            "create schema compensation_existing;create table compensation_existing.human_notes(id integer primary key,note text);"
            "insert into compensation_existing.human_notes values(1,'original human row');"
        )
        external_before = self.sql(
            "select md5(to_jsonb(x)::text)from compensation_existing.human_notes x where id=1;"
        )
        self.sql(
            "create function compensation_existing.ddl_effect()returns event_trigger language plpgsql as $$begin update compensation_existing.human_notes set note='ddl side effect'where id=1;end$$;"
            "create event trigger compensation_ddl_hook on ddl_command_end when tag in('ALTER TABLE')execute function compensation_existing.ddl_effect();alter event trigger compensation_ddl_hook disable;"
        )
        self.sql(
            "create function compensation_existing.safe_notice()returns event_trigger language plpgsql as $$begin return;end$$;"
            "create event trigger safe_ddl_hook on ddl_command_end execute function compensation_existing.safe_notice();alter event trigger safe_ddl_hook disable;"
        )
        state_query = (
            "select "
            + package.EVENT_CALLBACK_STATE
            + " from pg_event_trigger e join pg_proc p on p.oid=e.evtfoid join pg_namespace fn on fn.oid=p.pronamespace join pg_roles owner on owner.oid=p.proowner join pg_language lang on lang.oid=p.prolang where e.evtname='safe_ddl_hook';"
        )
        safe_state = self.sql(
            "begin;alter event trigger safe_ddl_hook enable;"
            + state_query
            + "rollback;"
        )
        policy = [{"evtname": "safe_ddl_hook", "callback_state_sha256": safe_state}]

        def callback_authorization(base, operation):
            value = copy.deepcopy(base)
            value["approved_ddl_event_callbacks"] = policy
            receipt = self.root / ("synthetic_callback_" + operation + ".json")
            reviewed = {
                "synthetic_only": True,
                "schema_version": 1,
                "project_id": package.PROJECT,
                "package_sha256": plan["package_sha256"],
                "generator_sha256": package.GENERATOR_AT_IMPORT,
                "reviewer_id": actor,
                "operation": operation,
                "approved_policy_sha256": package.digest(package.canonical(policy)),
                "reviewed_no_external_row_mutation": True,
            }
            receipt.write_text(json.dumps(reviewed), "utf8")
            value.update(
                ddl_event_callback_review_receipt_file=str(receipt),
                ddl_event_callback_review_receipt_sha256=package.digest(
                    receipt.read_bytes()
                ),
            )
            return value

        rollback_auth = copy.deepcopy(auth)
        rollback_auth.update(
            operation="compensating_rollback",
            compensating_rollback_authorization_sha256="3" * 64,
        )
        rollback_prefix = (
            prefix
            + "set rad.compensating_rollback_authorization_sha256='"
            + "3" * 64
            + "';"
        )
        rollback_sql = package.render_rollback_sql(plan, [new, detached], rollback_auth)
        malicious_trigger = "create function compensation_existing.side_effect()returns trigger language plpgsql as $$begin update compensation_existing.human_notes set note='changed'where id=1;return old;end$$;create trigger human_side_effect after delete on public.visa_articles for each row execute function compensation_existing.side_effect();"
        self.sql(
            package.render_sql(plan, [new, detached]),
            error="REVIEW_ONLY_APPROVED_RESTORE",
        )
        sql = package.render_sql(plan, [new, detached], auth)
        self.sql(sql, error="RESTORE_CONTEXT_ASSERTION_REQUIRED")
        self.sql(
            "begin;alter event trigger safe_ddl_hook enable;" + prefix + sql,
            error="DDL_EVENT_TRIGGER_REVIEW_REQUIRED",
        )
        approved_apply = callback_authorization(auth, "apply_unverified_drafts")
        approved_rollback = callback_authorization(
            rollback_auth, "compensating_rollback"
        )
        callback_apply_sql = package.render_sql(plan, [new, detached], approved_apply)
        callback_rollback_sql = package.render_rollback_sql(
            plan, [new, detached], approved_rollback
        )
        positive = self.sql(
            "begin;alter event trigger safe_ddl_hook enable;"
            + context(approved_apply)
            + callback_apply_sql.rsplit("commit;", 1)[0]
            + context(approved_rollback)
            + "set rad.compensating_rollback_authorization_sha256='"
            + "3" * 64
            + "';"
            + callback_rollback_sql.rsplit("commit;", 1)[0]
            + "select count(*)from public.visa_article_revisions;rollback;"
        )
        self.assertEqual(positive, "1")
        (self.root / "synthetic-callback-policy-positive.json").write_text(
            json.dumps(
                {
                    "synthetic_only": True,
                    "real_callback_approval": False,
                    "approved_fixture_policy": policy,
                    "apply_and_compensation_passed": True,
                    "blank_policy_refused_before_import_ddl": True,
                    "transaction_rolled_back": True,
                },
                indent=2,
            ),
            "utf8",
        )
        # A differing existing candidate is omitted until an exact human choice.
        pending = package.make_operation(
            self.ready(existing),
            current,
            "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT",
        )
        pending_plan = package.seal_plan({"production_baseline": [current]}, [pending])
        pending_auth = copy.deepcopy(auth)
        pending_auth["package_sha256"] = pending_plan["package_sha256"]
        self.sql(
            context(pending_auth)
            + package.render_sql(pending_plan, [pending], pending_auth)
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        decision = {
            "article_id": existing,
            "locale": "en",
            "decision": "keep_current",
            "payload_sha256": pending["payload_sha256"],
            "current_head": oldrev,
            "current_body_md5": current["body_md5"],
            "reviewer_id": actor,
            "review_receipt_sha256": "c" * 64,
        }
        pending_auth["human_decisions_sha256"] = package.digest(
            package.canonical([decision])
        )
        self.sql(
            context(pending_auth)
            + package.render_sql(pending_plan, [pending], pending_auth, [decision])
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        decision["decision"] = "create_detached_draft"
        pending_auth["human_decisions_sha256"] = package.digest(
            package.canonical([decision])
        )
        reviewed_sql = package.render_sql(
            pending_plan, [pending], pending_auth, [decision]
        )
        self.sql(
            context(pending_auth) + reviewed_sql.rsplit("commit;", 1)[0] + "rollback;"
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        # A source hash mismatch in the second row must revert the first row too.
        broken = copy.deepcopy(detached)
        broken["payload"]["sources"][0]["body_sha256"] = "0" * 64
        broken = package.make_operation(
            broken["payload"], current, broken["operation_class"]
        )
        badplan = package.seal_plan({"production_baseline": [current]}, [new, broken])
        badauth = copy.deepcopy(auth)
        badauth["package_sha256"] = badplan["package_sha256"]
        self.sql(
            context(badauth) + package.render_sql(badplan, [new, broken], badauth),
            error="SOURCE_PAYLOAD_CONFLICT",
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        for field in package.RECEIPT_FIELDS:
            self.sql(
                prefix + "set rad." + field + "='" + "0" * 64 + "';" + sql,
                error="RESTORE_CONTEXT_ASSERTION_REQUIRED",
            )
        for field, value in [
            ("system_identifier", "0" * 19),
            ("server_port", 64939),
            ("database", "wrong_restore"),
        ]:
            badauth = copy.deepcopy(auth)
            badauth["restore_endpoint"][field] = value
            self.sql(
                prefix + package.render_sql(plan, [new, detached], badauth),
                error="RESTORE_ENDPOINT_IDENTITY_MISMATCH",
            )
        self.sql(
            prefix + 'set request.jwt.claims=\'{"role":"service_role"}\';' + sql,
            error="forbidden",
        )
        # A harmful trigger present before import must be refused even when
        # its catalog state was captured by the initial application receipt.
        self.sql(
            "begin;"
            + malicious_trigger
            + prefix
            + sql.rsplit("commit;", 1)[0]
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_UNTRUSTED_DELETE_TRIGGER",
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        self.sql(
            "begin;create table public.preexisting_human_cascade(id integer primary key,article_id uuid);"
            "insert into public.preexisting_human_cascade values(1,'" + article + "');"
            "alter table public.preexisting_human_cascade add constraint preexisting_human_fk foreign key(article_id)references public.visa_articles(id)on delete cascade not valid;"
            + prefix
            + sql.rsplit("commit;", 1)[0]
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_UNOWNED_FK_REFERENCE",
        )
        self.sql(prefix + sql)
        ordinary_save = copy.deepcopy(self.ready(existing)["item"]["draft_request"])
        ordinary_save.update(
            expected_revision=1,
            request_key="60000000-0000-4000-8000-000000000001",
            title="Actual Admin next draft",
        )
        red_error = self.sql(
            "begin;"
            + baseline_helper_definition
            + ";"
            + prefix
            + "set local role authenticated;select public.save_visa_article_draft("
            + package.literal(package.canonical(ordinary_save))
            + "::jsonb);",
            error="duplicate_section_or_revision",
        )
        (self.root / "admin-save-detached-red.json").write_text(
            json.dumps(
                {
                    "actual_rpc": "public.save_visa_article_draft(jsonb)",
                    "observed_failure": "duplicate_section_or_revision",
                    "head_revision": 1,
                    "detached_revision": 2,
                    "red_helper_prosrc_md5": baseline_helper_md5,
                    "current_helper_prosrc_md5": self.sql(
                        "select md5(prosrc)from pg_proc where oid='private.rad_save_article(jsonb)'::regprocedure;"
                    ),
                    "stderr": red_error,
                    "synthetic_only": True,
                },
                indent=2,
            ),
            "utf8",
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "3"
        )
        # Real granted Admin RPCs: retained head r1 remains the concurrency
        # guard, detached r2 is skipped, normal save/ordinary rollback allocate r3/r4.
        human_edit = copy.deepcopy(detached["payload"]["item"]["draft_request"])
        human_edit.update(
            expected_revision=1,
            request_key=str(uuid4()),
            title="Human edit after detached candidate",
        )
        rollback_request = {
            "article_id": existing,
            "locale": "en",
            "from_revision_id": detached["revision_id"],
            "expected_revision": 3,
            "reason": "Synthetic ordinary Admin rollback",
            "request_key": str(uuid4()),
        }
        save_rpc = (
            "select public.save_visa_article_draft("
            + package.literal(package.canonical(human_edit))
            + "::jsonb);"
        )
        rollback_rpc = (
            "select public.rollback_visa_article("
            + package.literal(package.canonical(rollback_request))
            + "::jsonb);"
        )
        green = self.sql(
            prefix
            + "begin;set local role authenticated;"
            + save_rpc
            + rollback_rpc
            + "rollback;"
        ).splitlines()
        self.assertEqual([json.loads(v)["data"]["revision"] for v in green], [3, 4])
        stale = copy.deepcopy(human_edit)
        stale["request_key"] = str(uuid4())
        self.sql(
            prefix
            + "begin;set local role authenticated;"
            + save_rpc
            + "select public.save_visa_article_draft("
            + package.literal(package.canonical(stale))
            + "::jsonb);",
            error="revision_conflict",
        )
        self.sql(
            prefix
            + "begin;set local role authenticated;"
            + save_rpc
            + "reset role;"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_LATER_WRITE_OR_REFERENCE",
        )
        self.assertEqual(
            self.sql(
                "select head_id from public.visa_article_heads where article_id='"
                + existing
                + "'and locale='en';"
            ),
            oldrev,
        )
        (self.root / "admin-save-rollback-green.json").write_text(
            json.dumps(
                {
                    "synthetic_only": True,
                    "actual_database_role": "authenticated",
                    "actual_fixture_profile": "admin",
                    "normal_save_revision": 3,
                    "ordinary_rollback_revision": 4,
                    "head_after_transaction_rollback": oldrev,
                    "stale_head_revision_refused": True,
                    "compensation_refused_later_actual_admin_save": True,
                    "helper_prosrc_md5": self.sql(
                        "select md5(prosrc)from pg_proc where oid='private.rad_save_article(jsonb)'::regprocedure;"
                    ),
                },
                indent=2,
            ),
            "utf8",
        )
        # Provenance metadata and timestamps are immutable on exact retry too.
        for assignment in [
            "metadata=jsonb_set(metadata,'{raw_html_sha256}',to_jsonb(repeat('0',64)))",
            "fetched_at=fetched_at+interval '1 second'",
        ]:
            self.sql(
                "begin;alter table public.source_snapshots disable trigger rad_snapshot_immutable;"
                "update public.source_snapshots set "
                + assignment
                + ";alter table public.source_snapshots enable trigger rad_snapshot_immutable;"
                + prefix
                + sql,
                error="RETRY_SOURCE_CONFLICT",
            )
        self.sql(
            "begin;alter table public.visa_article_sections disable trigger visa_section_immutable;"
            "update public.visa_article_sections set heading='later edit';alter table public.visa_article_sections enable trigger visa_section_immutable;"
            + prefix
            + sql,
            error="RETRY_SECTIONS_CONFLICT",
        )
        self.sql(
            "begin;create or replace function public.list_production_reconciliation_drafts(p_package_sha256 text,p_after_operation_id text default '',p_limit integer default 50)returns jsonb language sql security definer as $$select '{}'::jsonb$$;"
            + prefix
            + sql,
            error="READER_RPC_COLLISION",
        )
        self.assertEqual(
            self.sql(
                "select head_id from public.visa_article_heads where article_id='"
                + existing
                + "';"
            ),
            oldrev,
        )
        self.assertEqual(
            self.sql(
                "select count(*)from public.visa_article_heads where published_id is not null;"
            ),
            "0",
        )
        self.sql(prefix + sql)
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "3"
        )
        for field, value in [
            ("body_md5", "0" * 32),
            ("actor_id_md5", "0" * 32),
            ("title_summary_md5", "0" * 32),
            ("sections_md5", "0" * 32),
            ("stored_content_hash", "0" * 64),
            ("revision", 4),
            ("published_id", oldrev),
            ("head_id", new["revision_id"]),
        ]:
            changed = copy.deepcopy(current)
            changed[field] = value
            badplan = package.seal_plan(
                {"production_baseline": [changed]}, [new, detached]
            )
            badauth = copy.deepcopy(auth)
            badauth["package_sha256"] = badplan["package_sha256"]
            self.sql(
                context(badauth)
                + package.render_sql(badplan, [new, detached], badauth),
                error="BASELINE_HEAD_BODY_ACTOR_CONFLICT",
            )
        # Admin discovers the detached revision and reads its entire candidate body.
        for kind, error in [
            ("snapshots", "BASELINE_LEGACY_SNAPSHOT_ROW_CONFLICT"),
            ("documents", "BASELINE_LEGACY_DOCUMENT_ROW_CONFLICT"),
        ]:
            badplan = package.seal_plan(
                {
                    "production_baseline": [current],
                    "production_legacy_fullrows": {
                        kind: [
                            {
                                "id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
                                if kind == "snapshots"
                                else "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                                "row_sha256": "0" * 64,
                            }
                        ]
                    },
                },
                [new, detached],
            )
            badauth = copy.deepcopy(auth)
            badauth["package_sha256"] = badplan["package_sha256"]
            self.sql(
                context(badauth)
                + package.render_sql(badplan, [new, detached], badauth),
                error=error,
            )
        query = (
            "select public.list_production_reconciliation_drafts('"
            + plan["package_sha256"]
            + "','',100);"
        )
        queue = json.loads(self.sql(prefix + query))
        self.assertEqual(len(queue["items"]), 2)
        self.assertEqual(sum(x["detached"] for x in queue["items"]), 1)
        reader = (
            "select public.get_production_reconciliation_draft('"
            + plan["package_sha256"]
            + "','"
            + detached["operation_id"]
            + "','"
            + detached["payload_sha256"]
            + "');"
        )
        draft = json.loads(self.sql(prefix + reader))
        self.assertEqual(
            draft["body"],
            {
                k: v
                for k, v in detached["payload"]["item"]["draft_request"].items()
                if k != "request_key"
            },
        )
        self.assertEqual(draft["current_head_id"], oldrev)
        self.sql(
            prefix + reader.replace(detached["payload_sha256"], "0" * 64),
            error="not_found",
        )
        self.sql(prefix + "set role anon;" + query, error="permission denied")
        self.sql(prefix + "set role service_role;" + query, error="permission denied")
        user = "77777777-7777-4777-8777-777777777777"
        nonadmin_setup = (
            'set request.jwt.claims=\'{"role":"service_role"}\';insert into auth.users(id,email) values(\''
            + user
            + "','non-admin@example.invalid');insert into public.profiles(id,role)values('"
            + user
            + "','user');"
        )
        self.sql(
            "begin;"
            + nonadmin_setup
            + "set role authenticated;set request.jwt.claims="
            + package.literal(json.dumps({"sub": user, "role": "authenticated"}))
            + ";"
            + query,
            error="forbidden",
        )
        # An Admin under the granted role can use both functions; private journal stays hidden.
        self.sql(prefix + "set role authenticated;" + reader)
        self.sql(
            prefix
            + "set role authenticated;select * from private.rad_production_reconciliation_journal;",
            error="permission denied",
        )
        scheduler = (
            self.evidence.parent / "research-activation-final/SCHEDULER_REVIEW_ONLY.sql"
        )
        if scheduler.is_file():
            before = self.sql(
                "select md5(coalesce(jsonb_agg(to_jsonb(h) order by h.article_id,h.locale),'[]'::jsonb)::text) from public.visa_article_heads h;"
            )
            guard = self.sql(
                scheduler.read_text("utf8"),
                error="REVIEW_ONLY_RECOVERY_OWNER_AND_ACTIVATION_RECEIPTS_REQUIRED",
            )
            after = self.sql(
                "select md5(coalesce(jsonb_agg(to_jsonb(h) order by h.article_id,h.locale),'[]'::jsonb)::text) from public.visa_article_heads h;"
            )
            self.assertEqual(before, after)
            (self.root / "research-scheduler-negative-guard.json").write_text(
                json.dumps(
                    {
                        "sql_sha256": package.digest(scheduler.read_bytes()),
                        "refused_before_writes": True,
                        "heads_before_md5": before,
                        "heads_after_md5": after,
                        "stderr": guard,
                        "synthetic_only": True,
                    },
                    indent=2,
                ),
                "utf8",
            )
        review_path = self.root / "FULL_REVIEW_ONLY.sql.gz"
        core = (
            self.evidence.parent / "release-final-20261102/CORE_FORWARD_REVIEW_ONLY.sql"
        )
        if core.is_file():
            before = self.sql(
                "select md5(coalesce(jsonb_agg(to_jsonb(h) order by h.article_id,h.locale),'[]'::jsonb)::text)from public.visa_article_heads h;"
            )
            stderr = self.sql(
                core.read_text("utf8"),
                error="REVIEW_ONLY_CURRENT_RECOVERY_ACTOR_ENDPOINT_AND_OWNER_REQUIRED",
            )
            after = self.sql(
                "select md5(coalesce(jsonb_agg(to_jsonb(h) order by h.article_id,h.locale),'[]'::jsonb)::text)from public.visa_article_heads h;"
            )
            self.assertEqual(before, after)
            (self.root / "core-forward-negative-guard.json").write_text(
                json.dumps(
                    {
                        "sql_sha256": package.digest(core.read_bytes()),
                        "heads_before_md5": before,
                        "heads_after_md5": after,
                        "refused_before_writes": True,
                        "synthetic_only": True,
                        "stderr": stderr,
                    },
                    indent=2,
                ),
                "utf8",
            )
        review_receipt = package.write_review_sql(review_path, plan, [new, detached])
        self.assertEqual(review_receipt["selected_insert_operations"], 2)
        self.sql(
            gzip.decompress(review_path.read_bytes()).decode("utf8"),
            error="PRODUCTION_REVIEW_ONLY_APPROVED_CHECKPOINT_ACTOR_ENDPOINT_AND_OWNER_REQUIRED",
        )
        # Committed compensation is stricter than import retry: any later app
        # write/reference/publication blocks it, and external FK schemas block it.
        rollback_auth = copy.deepcopy(auth)
        rollback_auth.update(
            operation="compensating_rollback",
            compensating_rollback_authorization_sha256="3" * 64,
        )
        rollback_prefix = (
            prefix
            + "set rad.compensating_rollback_authorization_sha256='"
            + "3" * 64
            + "';"
        )
        rollback_sql = package.render_rollback_sql(plan, [new, detached], rollback_auth)
        self.sql(
            package.render_rollback_sql(plan, [new, detached]),
            error="COMPENSATION_OWNER_RECOVERY_ACTOR_AND_PACKAGE_REQUIRED",
        )
        self.sql(prefix + rollback_sql, error="COMPENSATION_CONTEXT_ASSERTION_REQUIRED")
        self.sql(
            "begin;update public.content_sources set title='later human write';"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_LATER_WRITE_OR_REFERENCE",
        )
        self.sql(
            "begin;set local session_replication_role=replica;update public.visa_article_heads set published_id=head_id where article_id='"
            + article
            + "';set local session_replication_role=origin;"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_LATER_WRITE_OR_REFERENCE",
        )
        self.sql(
            "begin;create schema compensation_external;create table compensation_external.human_ref(id uuid primary key,article_id uuid references public.visa_articles(id)on delete cascade);"
            "insert into compensation_external.human_ref values(gen_random_uuid(),'"
            + article
            + "');"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_EXTERNAL_FK_BOUNDARY",
        )
        self.sql(
            "begin;" + malicious_trigger + rollback_prefix + rollback_sql,
            error="COMPENSATION_UNTRUSTED_DELETE_TRIGGER",
        )
        self.sql(
            "begin;create or replace function private.rad_remove_article_search()returns trigger language plpgsql security definer set search_path=''as $$begin update compensation_existing.human_notes set note='changed'where id=1;return old;end$$;"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_UNTRUSTED_DELETE_TRIGGER",
        )
        self.sql(
            "begin;create rule human_delete_rule as on delete to public.visa_articles do also update compensation_existing.human_notes set note='changed'where id=1;"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_UNTRUSTED_DELETE_RULE",
        )
        self.sql(
            "begin;create function compensation_existing.unrelated()returns integer language sql as $$select 1$$;"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_CATALOG_DRIFT",
        )
        self.sql(
            "begin;alter event trigger compensation_ddl_hook enable;"
            + rollback_prefix
            + rollback_sql,
            error="DDL_EVENT_TRIGGER_REVIEW_REQUIRED",
        )
        # A new public table must stay outside the original compensation receipt
        # even if the importer is retried after that table appears.
        self.sql(
            "begin;create table public.later_human_table(id integer primary key);"
            + prefix
            + sql.rsplit("commit;", 1)[0]
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_LATER_WRITE_OR_REFERENCE",
        )
        self.sql(
            "begin;create table private.rad_production_reconciliation_human_notes(id uuid primary key,article_id uuid references public.visa_articles(id)on delete cascade);"
            "insert into private.rad_production_reconciliation_human_notes values(gen_random_uuid(),'"
            + article
            + "');"
            + rollback_prefix
            + rollback_sql,
            error="COMPENSATION_LATER_WRITE_OR_REFERENCE",
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "3"
        )
        self.sql("set timezone='Asia/Tehran';" + rollback_prefix + rollback_sql)
        external_after = self.sql(
            "select md5(to_jsonb(x)::text)from compensation_existing.human_notes x where id=1;"
        )
        self.assertEqual(external_before, external_after)
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_heads;"), "1"
        )
        self.assertEqual(self.sql("select count(*)from public.source_snapshots;"), "0")
        self.assertEqual(self.sql("select count(*)from public.source_documents;"), "0")
        self.assertEqual(self.sql("select count(*)from public.content_sources;"), "0")
        self.assertEqual(
            self.sql("select count(*)from private.visa_source_origins;"), "0"
        )
        self.assertEqual(
            self.sql(
                "select head_id from public.visa_article_heads where article_id='"
                + existing
                + "';"
            ),
            oldrev,
        )
        self.sql(rollback_prefix + rollback_sql)
        self.sql(prefix + sql, error="PACKAGE_PREVIOUSLY_ROLLED_BACK")
        self.assertEqual(
            self.sql("select count(*)from public.visa_article_revisions;"), "1"
        )
        receipt = {
            "synthetic_only": True,
            "baseline_heads": 1,
            "result_heads": 2,
            "result_revisions": 3,
            "old_head_preserved": True,
            "publication_writes": 0,
            "idempotent_retry": True,
            "default_refusal": True,
            "endpoint_guard": True,
            "all_recovery_receipt_guards": True,
            "atomic_source_failure": True,
            "old_body_author_title_revision_hash_pointer_guards": True,
            "admin_queue_and_body_reader": True,
            "anon_service_role_nonadmin_denied": True,
            "exact_provenance_metadata_timestamp_retry_guards": True,
            "committed_compensation_preserves_original_rows": True,
            "compensation_later_write_publication_external_fk_refusal": True,
            "compensation_idempotency_and_reimport_refusal": True,
            "full_review_sql_first_refusal": True,
            "preexisting_and_postapply_unknown_delete_trigger_rule_refusal": True,
            "callback_function_and_catalog_drift_refusal": True,
            "ddl_event_trigger_catalog_and_enabled_hook_refusal": True,
            "synthetic_operation_scoped_callback_policy_positive": True,
            "actual_authenticated_admin_save_and_ordinary_rollback_after_detached": True,
            "preexisting_not_valid_fk_human_row_refused_before_delete": True,
            "external_human_row_before_md5": external_before,
            "external_human_row_after_md5": external_after,
            "package_sha256": plan["package_sha256"],
        }
        (self.root / "safety-cases.json").write_text(
            json.dumps(receipt, indent=2), "utf8"
        )


if __name__ == "__main__":
    unittest.main()
