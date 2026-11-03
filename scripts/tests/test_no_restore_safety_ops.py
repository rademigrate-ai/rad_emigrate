"""Disposable native PostgreSQL tests for no-Restore safety operations."""

import unittest
from pathlib import Path

from scripts.tests import test_production_reconciliation_sql as native


class NoRestoreSafetyOpsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        native.ReconciliationSQLTest.setUpClass()
        cls.fixture = native.ReconciliationSQLTest
        cls.repo = Path(__file__).resolve().parents[2]
        try:
            cls.fixture.sql(
                (
                    cls.repo
                    / "supabase/migrations/20261102192642_rad_source_faithful_editorial_release.sql"
                ).read_text("utf8")
            )
            cls.fixture.sql(
                (
                    cls.repo
                    / "supabase/migrations/20261103114340_rad_corrected_source_editorial_admission.sql"
                ).read_text("utf8")
            )
            cls.fixture.sql(
                (
                    cls.repo
                    / "supabase/migrations/20261103120000_rad_no_restore_safety_ops.sql"
                ).read_text("utf8")
            )
        except BaseException:
            cls.fixture.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        cls.fixture.tearDownClass()

    @staticmethod
    def claims(actor=None, role="authenticated"):
        if actor is None:
            return '{"role":"' + role + '"}'
        return '{"role":"' + role + '","sub":"' + actor + '"}'

    def test_function_state_capture_restore_and_drift_refusal(self):
        actor = "b5100000-0000-4000-8000-000000000001"
        signatures = [
            "private.is_safe_public_https_url(text)",
            "private.prevent_profile_role_escalation()",
            "private.rad_article_verification(uuid)",
            "private.rad_claim_eligible(uuid)",
            "private.rad_evidence(jsonb,uuid)",
            "private.rad_page_position(jsonb,text)",
            "public.get_visa_article(jsonb)",
        ]
        sig_sql = "array[" + ",".join("'" + s + "'" for s in signatures) + "]"
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(role="service_role") + "';"
            f"insert into auth.users(id,email)values('{actor}','function-state-admin@example.invalid');"
            f"insert into public.profiles(id,role)values('{actor}','admin')on conflict(id)do update set role='admin';"
        )
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select private.rad_capture_function_state('4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282','reviewed_forward',"
            + sig_sql
            + ");"
        )
        before = self.fixture.sql(
            "select count(*)from private.rad_function_state_members;"
        )
        self.assertEqual(before, "7")
        receipt = self.fixture.sql(
            "select id::text from private.rad_function_state_receipts limit 1;"
        )
        original_hash = self.fixture.sql(
            "select definition_sha256 from private.rad_function_state_members where identity='private.rad_page_position(jsonb,text)';"
        )
        self.fixture.sql(
            "create or replace function private.rad_page_position(body jsonb,version text) returns jsonb language plpgsql set search_path='' as $$begin return null;end$$;"
        )
        changed = self.fixture.sql(
            "select encode(extensions.digest(pg_get_functiondef('private.rad_page_position(jsonb,text)'::regprocedure),'sha256'),'hex');"
        )
        self.assertNotEqual(changed, original_hash)
        # A management/service connection cannot restore privileged function state.
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(role="service_role") + "';"
            "select private.rad_restore_function_state("
            + receipt
            + ",'Unauthorized service-role restore must be refused.');",
            error="forbidden",
        )
        # Exact original pg_proc ACLs are immutable release preconditions.
        # Fail closed on changed grants instead of revoking/regranting incompletely.
        self.fixture.sql(
            "create role rad_acl_review_fixture;"
            "grant execute on function private.rad_page_position(jsonb,text)"
            " to rad_acl_review_fixture;"
        )
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select private.rad_restore_function_state("
            + receipt
            + ",'ACL drift must not be papered over by a restore.');",
            error="function_acl_or_owner_drift",
        )
        self.fixture.sql(
            "revoke execute on function private.rad_page_position(jsonb,text)"
            " from rad_acl_review_fixture;"
            "drop role rad_acl_review_fixture;"
        )
        result = self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select private.rad_restore_function_state("
            + receipt
            + ",'Independent PostgreSQL reviewer approves exact function restore.');"
        )
        self.assertIn('"restored_count": 7', result)
        restored_hash = self.fixture.sql(
            "select encode(extensions.digest(pg_get_functiondef('private.rad_page_position(jsonb,text)'::regprocedure),'sha256'),'hex');"
        )
        self.assertEqual(restored_hash, original_hash)
        dependents = self.fixture.sql(
            "select dependencies::text from private.rad_function_state_members m where identity='private.rad_page_position(jsonb,text)';"
        )
        # The function's table use is not a catalog dependency; captured
        # dependency evidence remains empty for this member and is reported as a
        # limitation rather than treated as proof of complete DDL inversion.
        self.assertEqual(dependents, "[]")
        self.fixture.sql(
            "delete from private.rad_function_state_members where identity='private.rad_page_position(jsonb,text)';",
            error="immutable_history",
        )

        self.fixture.sql(
            "create or replace function private.rad_page_position(body jsonb,version text) returns jsonb language plpgsql set search_path='' as $$begin return jsonb_build_object('offset',999);end$$;"
        )
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select private.rad_capture_function_state('4beb6ba711c5b0243d69be29b32a76c13f5ebcc47ce131e7ca406bcd67e6c282','reviewed_forward',array['private.rad_page_position(jsonb,text)']);",
            error="function_state_receipt_conflict",
        )
        # Leave the shared synthetic database unchanged for later regressions.
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select private.rad_restore_function_state("
            + receipt
            + ",'Restore the original function before later tests.');"
        )

    def test_standard_editorial_pointer_revocation_remains_supported(self):
        # The source-specific pointer guard must not change existing standard
        # editorial semantics. This disposable fixture rolls back entirely.
        self.fixture.sql(
            "begin;"
            "select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);"
            "insert into auth.users(id,email) values("
            "'b6200000-0000-4000-8000-000000000001','standard-pointer@example.invalid');"
            "insert into public.visa_articles(id,kind,country_code,pathway_slug,slug,created_by)"
            " values('b6200000-0000-4000-8000-000000000010','related','ZZ',"
            "'synthetic-standard','synthetic-standard',"
            "'b6200000-0000-4000-8000-000000000001');"
            "insert into public.visa_article_revisions(id,article_id,locale,revision,title,"
            "summary,content_hash,body,created_by) values("
            "'b6200000-0000-4000-8000-000000000011',"
            "'b6200000-0000-4000-8000-000000000010','en',1,"
            "'SYNTHETIC standard editorial','No immigration facts.',repeat('0',64),"
            '\'{"sections":[],"related_article_ids":[]}\','
            "'b6200000-0000-4000-8000-000000000001');"
            "insert into public.visa_article_heads(article_id,locale,head_id,published_id)"
            " values('b6200000-0000-4000-8000-000000000010','en',"
            "'b6200000-0000-4000-8000-000000000011',"
            "'b6200000-0000-4000-8000-000000000011');"
            "update public.visa_article_heads set published_id=null"
            " where article_id='b6200000-0000-4000-8000-000000000010';"
            "do $$ begin if exists(select 1 from public.visa_article_heads where"
            " article_id='b6200000-0000-4000-8000-000000000010' and published_id is not null)"
            " then raise exception 'standard pointer was not revoked'; end if; end $$;"
            "rollback;"
        )

    def test_unpublish_restores_null_pointer_and_projection(self):
        self.fixture.sql(
            (self.repo / "supabase/tests/source_editorial_release.sql")
            .read_text("utf8")
            .replace("rollback;", "commit;")
        )
        actor = "a4100000-0000-4000-8000-000000000001"
        batch = "a4100000-0000-4000-8000-000000000040"
        manifest_sha = self.fixture.sql(
            "select manifest_sha256 from private.rad_source_editorial_batches where id='"
            + batch
            + "';"
        )
        published_before = self.fixture.sql(
            "select count(*)from public.visa_article_heads where published_id is not null;"
        )
        self.assertEqual(published_before, "2")
        result = self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select public.unpublish_source_editorial_batch('"
            + batch
            + "','"
            + manifest_sha
            + "','Independent reversal after verified synthetic publication.');"
        )
        self.assertIn('"unpublished_count": 2', result)
        self.assertEqual(
            self.fixture.sql(
                "select count(*)from public.visa_article_heads where published_id is not null;"
            ),
            "0",
        )
        self.assertEqual(
            self.fixture.sql(
                "select count(*)from public.visa_article_search_documents where article_id='a4100000-0000-4000-8000-000000000010';"
            ),
            "0",
        )
        self.assertEqual(
            self.fixture.sql(
                "select count(*)from public.visa_article_revision_events where state='unpublished' and source_batch_id='"
                + batch
                + "';"
            ),
            "2",
        )
        # A publication-state conflict before the first unpublish event refuses
        # the transaction; a retry after the event remains idempotent.
        self.assertEqual(
            self.fixture.sql(
                "select count(*)from private.rad_source_unpublish_receipts where batch_id='"
                + batch
                + "';"
            ),
            "1",
        )
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select public.unpublish_source_editorial_batch('"
            + batch
            + "','"
            + manifest_sha
            + "','Independent reversal after verified synthetic publication.');"
        )
        # Exact retry is idempotent; a changed manifest or head is refused.
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select public.unpublish_source_editorial_batch('"
            + batch
            + "','"
            + "0" * 64
            + "','Independent reversal after verified synthetic publication.');",
            error="source_batch_actor_or_hash_conflict",
        )
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "update public.visa_article_heads set published_id=(select revision_id from private.rad_production_reconciliation_journal limit 1) where article_id='a4100000-0000-4000-8000-000000000010';",
            error="explicit_source_publication_operation_required",
        )
        # An old published event must not be replayable as permission to
        # repoint a previously unpublished article in a later transaction.
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "update public.visa_article_heads set published_id=("
            "select e.revision_id from public.visa_article_revision_events e "
            "join public.visa_article_revisions r on r.id=e.revision_id "
            "where e.state='published' and e.source_batch_id='"
            + batch
            + "' and r.article_id='a4100000-0000-4000-8000-000000000010' "
            "limit 1) where article_id='a4100000-0000-4000-8000-000000000010';",
            error="explicit_source_publication_operation_required",
        )
        # Anonymous access remains denied after unpublication; no projection row
        # is recreated by the reversal.
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(actor) + "';"
            "select private.rad_restore_function_state(999999,'Invalid receipt review should fail.');",
            error="function_state_receipt_not_found",
        )
        self.fixture.sql(
            "set request.jwt.claims='" + self.claims(role="anon") + "';"
            "set role anon;select public.get_editorial_article('a4100000-0000-4000-8000-000000000010','en',false);",
            error="article_or_translation_not_found",
        )


if __name__ == "__main__":
    unittest.main()
