"""The new release contract is executed on an owned native PostgreSQL fixture."""

import json
import tempfile
import unittest
from pathlib import Path

from scripts import production_mechanical_decisions as mechanical
from scripts import production_reconciliation_package as original
from scripts.tests import test_production_reconciliation_sql as native
from scripts.visa_release_audit import file_sha
from tools.production_body_review import digest as review_digest


class SourceEditorialSQLTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        native.ReconciliationSQLTest.setUpClass()
        cls.fixture = native.ReconciliationSQLTest
        try:
            cls.fixture.sql(
                (
                    Path(__file__).resolve().parents[2]
                    / "supabase/migrations/20261102192642_rad_source_faithful_editorial_release.sql"
                ).read_text("utf8")
            )
        except BaseException:
            cls.fixture.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        cls.fixture.tearDownClass()

    def test_source_release_keeps_verification_acl_history_and_exact_body(self):
        sql = (
            Path(__file__).resolve().parents[2]
            / "supabase/tests/source_editorial_release.sql"
        )
        self.fixture.sql(sql.read_text("utf8"))

    def test_mechanical_adapter_executes_detached_draft_and_exact_retry(self):
        actor = "b4200000-0000-4000-8000-000000000001"
        article = "b4200000-0000-4000-8000-000000000002"
        head = "b4200000-0000-4000-8000-000000000003"
        ready = native.ReconciliationSQLTest().ready(article)
        before = {
            k: v
            for k, v in ready["item"]["draft_request"].items()
            if k != "request_key"
        } | {"sections": []}
        self.fixture.sql(
            "set request.jwt.claims='{" + '"role":"service_role"' + "}';"
            f"insert into auth.users(id,email)values('{actor}','mechanical-fixture@example.invalid');"
            f"insert into public.profiles(id,role)values('{actor}','admin')on conflict(id)do update set role='admin';"
            f"insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)values('{article}','related',null,'topic-{article.replace('-', '')}','editorial-{article}','{actor}');"
            f"insert into public.visa_article_revisions(id,article_id,locale,revision,title,summary,content_hash,body,created_by)values('{head}','{article}','en',1,'Candidate','',repeat('b',64),{original.literal(original.canonical(before))}::jsonb,'{actor}');"
            f"insert into public.visa_article_heads values('{article}','en','{head}',null);"
        )
        current = json.loads(
            self.fixture.sql(
                f"select jsonb_build_object('article_id',h.article_id,'locale',h.locale,'head_id',h.head_id,'published_id',h.published_id,'revision',r.revision,'body_md5',md5(r.body::text),'actor_id_md5',md5(r.created_by::text),'created_at',r.created_at,'stored_content_hash',r.content_hash,'sections_md5',md5('[]'),'title_summary_md5',md5(jsonb_build_object('title',r.title,'summary',r.summary)::text))from public.visa_article_heads h join public.visa_article_revisions r on r.id=h.head_id where h.article_id='{article}';"
            )
        )
        case = {
            "case_id": "MECHANICAL-NATIVE",
            "article_id": article,
            "locale": "en",
            "payload_sha256": review_digest(ready),
            "current_head": head,
            "current_body_md5": current["body_md5"],
            "current_body_sha256": review_digest(before),
            "delta": mechanical.independent_delta(
                before,
                {
                    k: v
                    for k, v in ready["item"]["draft_request"].items()
                    if k != "request_key"
                },
            ),
            "source_review_status": "PASS_EXACT_MECHANICAL_SOURCE_INTEGRITY",
            "source_review_errors": [],
        }
        case["case_sha256"] = review_digest(case)
        op = original.make_operation(
            ready,
            current,
            "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT",
            case,
        )
        plan = original.seal_plan({"production_baseline": [current]}, [op])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            capture = root / "production-full-body-0.json"
            capture.write_text(
                json.dumps({"rows": [current | {"body": before}]}), encoding="utf8"
            )
            (root / "receipt.json").write_text(
                json.dumps({"inputs": {str(capture): file_sha(capture)}}),
                encoding="utf8",
            )
            decisions = mechanical.prepare(
                plan,
                [op],
                root,
                {
                    "project_id": original.PROJECT,
                    "head_bindings": [current],
                    "observed_at": "fixture",
                    "approved_revisions": 0,
                    "published_heads": 0,
                },
            )
        auth = {f: "2" * 64 for f in original.RECEIPT_FIELDS}
        auth.update(
            project_id=original.PROJECT,
            source_commit=original.COMMIT,
            execution_scope="approved_isolated_restore",
            actor_id=actor,
            actor_role="admin",
            package_sha256=plan["package_sha256"],
            human_decisions_sha256=original.digest(original.canonical([])),
            mechanical_decisions_sha256=decisions["decision_package_sha256"],
            mechanical_adapter_sha256=file_sha(Path(mechanical.__file__)),
            restore_endpoint={
                "server_addr": "127.0.0.1",
                "server_port": 64938,
                "database": "postgres",
                "system_identifier": self.fixture.sql(
                    "select system_identifier from pg_control_system();"
                ),
            },
        )
        settings = {
            "rad.expected_project": original.PROJECT,
            "rad.execution_scope": "approved_isolated_restore",
            "rad.package_sha256": plan["package_sha256"],
            "rad.actor_id": actor,
            "rad.human_decisions_sha256": auth["human_decisions_sha256"],
            "rad.mechanical_decisions_sha256": auth["mechanical_decisions_sha256"],
        }
        settings.update(
            {"rad." + field: auth[field] for field in original.RECEIPT_FIELDS}
        )
        prefix = "".join(
            "set " + key + "=" + original.literal(value) + ";"
            for key, value in settings.items()
        )
        prefix += (
            "set request.jwt.claims="
            + original.literal(json.dumps({"sub": actor, "role": "authenticated"}))
            + ";"
        )
        sql = mechanical.render(plan, [op], decisions, auth)
        self.fixture.sql(prefix + sql)
        self.fixture.sql(prefix + sql)
        self.assertEqual(
            self.fixture.sql(
                f"select count(*)from public.visa_article_revisions where article_id='{article}';"
            ),
            "2",
        )
        self.assertEqual(
            self.fixture.sql(
                f"select head_id::text||':'||(published_id is null)::text from public.visa_article_heads where article_id='{article}';"
            ),
            head + ":true",
        )


if __name__ == "__main__":
    unittest.main()
