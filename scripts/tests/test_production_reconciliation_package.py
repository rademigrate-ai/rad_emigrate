import copy
import importlib
import json
import tempfile
import unittest
from pathlib import Path


class ReconciliationPlanTest(unittest.TestCase):
    def module(self):
        spec = importlib.util.find_spec("scripts.production_reconciliation_package")
        self.assertIsNotNone(
            spec, "Production-specific additive preparation is missing"
        )
        return importlib.import_module("scripts.production_reconciliation_package")

    def fixture(self):
        return {
            "article_id": "11111111-1111-4111-8111-111111111111",
            "locale": "en",
            "item": {
                "article_id": "11111111-1111-4111-8111-111111111111",
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
                    "article_id": "11111111-1111-4111-8111-111111111111",
                    "locale": "en",
                    "title": "Draft",
                    "summary": "",
                    "sections": [],
                    "related_article_ids": [],
                    "merge_manifest_id": None,
                    "expected_revision": 0,
                    "request_key": "x",
                },
            },
            "sources": [],
        }

    def test_plan_preserves_current_heads_and_requires_per_row_divergent_decision(self):
        m = self.module()
        ready = self.fixture()
        binding = {
            "head_id": "22222222-2222-4222-8222-222222222222",
            "body_md5": "a" * 32,
            "revision": 1,
            "published_id": None,
        }
        op = m.make_operation(
            ready, binding, "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT"
        )
        self.assertEqual(op["action"], "PENDING_HUMAN_RECONCILIATION")
        self.assertFalse(op["advance_existing_head"])
        with self.assertRaisesRegex(ValueError, "decision_payload_binding"):
            m.resolve_operation(
                op, {"decision": "create_detached_draft", "payload_sha256": "b" * 64}
            )
        decision = {
            "decision": "create_detached_draft",
            "payload_sha256": op["payload_sha256"],
            "current_head": binding["head_id"],
            "current_body_md5": "a" * 32,
            "reviewer_id": "33333333-3333-4333-8333-333333333333",
            "review_receipt_sha256": "c" * 64,
        }
        self.assertEqual(
            m.resolve_operation(op, decision)["action"],
            "INSERT_DETACHED_UNVERIFIED_DRAFT",
        )

    def test_unsafe_payload_is_refused_before_artifact_generation(self):
        m = self.module()
        for field, value in [
            ("published", True),
            ("verification_state", "verified"),
            ("reviewer_id", "invented"),
        ]:
            ready = self.fixture()
            ready["item"][field] = value
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(ValueError, "draft_only"),
            ):
                m.make_operation(ready, None, "NEW_KEY_DRAFT_CANDIDATE")

    def test_missing_approval_or_wrong_target_cannot_render_executable_restore(self):
        m = self.module()
        with self.assertRaisesRegex(ValueError, "restore_authorization"):
            m.validate_authorization({}, "d" * 64)
        auth = {key: "e" * 64 for key in m.RECEIPT_FIELDS}
        auth.update(
            project_id="epolbumcfbohtmgvomki",
            execution_scope="approved_isolated_restore",
            actor_id="33333333-3333-4333-8333-333333333333",
            actor_role="admin",
            package_sha256="d" * 64,
            source_commit="81f11ce176d9645ae0503e360e22ef6a414c355b",
        )
        with self.assertRaisesRegex(ValueError, "restore_authorization"):
            m.validate_authorization(auth, "d" * 64)

    def test_duplicate_keys_fail_closed(self):
        m = self.module()
        row = self.fixture()
        with self.assertRaisesRegex(ValueError, "duplicate"):
            m.unique_rows([row, copy.deepcopy(row)])

    def authorization(self, m, plan):
        auth = {f: "a" * 64 for f in m.RECEIPT_FIELDS}
        auth.update(
            project_id=m.PROJECT,
            source_commit=m.COMMIT,
            execution_scope="approved_isolated_restore",
            package_sha256=plan["package_sha256"],
            actor_id="33333333-3333-4333-8333-333333333333",
            actor_role="admin",
            human_decisions_sha256=m.digest(m.canonical([])),
            restore_endpoint={
                "server_addr": "127.0.0.1",
                "server_port": 64938,
                "database": "postgres",
                "system_identifier": "1234567890123456789",
            },
        )
        return auth

    def test_operation_payload_and_bindings_cannot_be_substituted_after_plan_seal(self):
        m = self.module()
        op = m.make_operation(self.fixture(), None, "NEW_KEY_DRAFT_CANDIDATE")
        plan = m.seal_plan({"production_baseline": []}, [op])
        auth = self.authorization(m, plan)
        altered = copy.deepcopy(op)
        altered["payload"]["item"]["draft_request"]["title"] = "substitution"
        with self.assertRaisesRegex(ValueError, "operation_integrity"):
            m.render_sql(plan, [altered], auth)
        altered = copy.deepcopy(op)
        altered["revision_id"] = "44444444-4444-4444-8444-444444444444"
        with self.assertRaisesRegex(ValueError, "operation_binding"):
            m.render_sql(plan, [altered], auth)
        altered = copy.deepcopy(plan)
        altered["production_baseline"] = [{"injected": "head"}]
        with self.assertRaisesRegex(ValueError, "plan_hash"):
            m.render_sql(altered, [op], auth)

    def test_restore_cannot_render_for_remote_endpoint_actor_receipt_or_decision_change(
        self,
    ):
        m = self.module()
        op = m.make_operation(self.fixture(), None, "NEW_KEY_DRAFT_CANDIDATE")
        plan = m.seal_plan({"production_baseline": []}, [op])
        auth = self.authorization(m, plan)
        for field, value in [
            ("execution_scope", "production"),
            ("actor_role", "user"),
            ("actor_id", None),
            ("package_sha256", "0" * 64),
            ("owner_authorization_sha256", None),
            ("source_commit", "other"),
        ]:
            altered = copy.deepcopy(auth)
            altered[field] = value
            with (
                self.subTest(field=field),
                self.assertRaisesRegex(ValueError, "restore_authorization"),
            ):
                m.render_sql(plan, [op], altered)
        altered = copy.deepcopy(auth)
        altered["restore_endpoint"]["server_addr"] = "hosted.example"
        with self.assertRaisesRegex(ValueError, "restore_authorization"):
            m.render_sql(plan, [op], altered)
        altered = copy.deepcopy(auth)
        altered["human_decisions_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "exact_human_decisions"):
            m.render_sql(plan, [op], altered)

    def test_sql_data_tokens_quotes_and_dollar_delimiters_remain_literal(self):
        m = self.module()
        ready = self.fixture()
        ready["item"]["draft_request"]["title"] = "RAW_PAYLOAD O'Brien \\ $guard$"
        op = m.make_operation(ready, None, "NEW_KEY_DRAFT_CANDIDATE")
        plan = m.seal_plan({"production_baseline": []}, [op])
        sql = m.render_sql(plan, [op], self.authorization(m, plan))
        self.assertIn("RAW_PAYLOAD O''Brien", sql)
        self.assertIn("set local standard_conforming_strings=on;", sql)

    def test_pending_human_case_is_not_silently_executed(self):
        m = self.module()
        binding = {
            "head_id": "22222222-2222-4222-8222-222222222222",
            "body_md5": "a" * 32,
        }
        op = m.make_operation(
            self.fixture(),
            binding,
            "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT",
        )
        plan = m.seal_plan({"production_baseline": []}, [op])
        sql = m.render_sql(plan, [op], self.authorization(m, plan))
        self.assertNotIn("raw text :=", sql)
        self.assertIn("get_production_reconciliation_draft", sql)

    def test_offline_production_renderer_requires_real_checkpoint_file_and_final_candidate_bindings(
        self,
    ):
        m = self.module()
        op = m.make_operation(self.fixture(), None, "NEW_KEY_DRAFT_CANDIDATE")
        plan = m.seal_plan({"production_baseline": []}, [op])
        auth = self.authorization(m, plan)
        auth.update(
            execution_scope="approved_production",
            recovery_evidence_kind="verified_real_production_checkpoint",
            authorization_kind="explicit_future_owner_approval",
            production_api_origin="https://" + m.PROJECT + ".supabase.co",
            source_commit_role="historical_base",
            generator_sha256=m.GENERATOR_AT_IMPORT,
            final_candidate_commit="1" * 40,
        )
        auth["restore_endpoint"]["server_addr"] = "192.0.2.10"
        with tempfile.TemporaryDirectory() as tmp:
            auth["receipt_files"] = {}
            for field in m.RECEIPT_FIELDS:
                path = Path(tmp) / field
                path.write_text("SYNTHETIC UNIT FIXTURE: " + field, "utf8")
                auth[field] = m.digest(path.read_bytes())
                auth["receipt_files"][field] = str(path)
            delivery = Path(tmp) / "delivery.json"
            delivery.write_text(
                json.dumps(
                    {
                        "unit_fixture_only": True,
                        "head_sha": auth["final_candidate_commit"],
                        "project_id": m.PROJECT,
                        "production_package_sha256": plan["package_sha256"],
                        "code_sha256": {
                            "scripts/production_reconciliation_package.py": m.GENERATOR_AT_IMPORT,
                            "supabase/migrations/20261102101305_rad_cms_detached_revision_allocator.sql": m.ADMIN_COMPAT_SHA256,
                        },
                    }
                ),
                "utf8",
            )
            auth.update(
                final_delivery_receipt_file=str(delivery),
                final_delivery_receipt_sha256=m.digest(delivery.read_bytes()),
            )
            sql = m.render_sql(plan, [op], auth, execution_scope="approved_production")
            self.assertIn("'approved_production'", sql)
            self.assertIn("'192.0.2.10'", sql)
            with self.assertRaisesRegex(ValueError, "restore_authorization"):
                m.render_sql(plan, [op], auth)
            altered = copy.deepcopy(auth)
            altered["recovery_evidence_kind"] = "synthetic_isolated_restore"
            with self.assertRaisesRegex(ValueError, "production_real_checkpoint"):
                m.render_sql(plan, [op], altered, execution_scope="approved_production")
            altered = copy.deepcopy(auth)
            altered["final_candidate_commit"] = m.COMMIT
            with self.assertRaisesRegex(ValueError, "final_candidate"):
                m.render_sql(plan, [op], altered, execution_scope="approved_production")
            original = delivery.read_bytes()
            mismatched = json.loads(original)
            mismatched["production_package_sha256"] = "0" * 64
            delivery.write_text(json.dumps(mismatched), "utf8")
            altered = copy.deepcopy(auth)
            altered["final_delivery_receipt_sha256"] = m.digest(delivery.read_bytes())
            with self.assertRaisesRegex(ValueError, "final_delivery_content"):
                m.render_sql(plan, [op], altered, execution_scope="approved_production")
            delivery.write_bytes(original)
            Path(auth["receipt_files"]["coordinated_backup_sha256"]).write_text(
                "tampered", "utf8"
            )
            with self.assertRaisesRegex(ValueError, "receipt_file_hash"):
                m.render_sql(plan, [op], auth, execution_scope="approved_production")

    def test_review_case_binds_enriched_ready_payload_and_human_choice(self):
        m = self.module()
        ready = self.fixture()
        ready["item"]["source_capture_variants"] = [{"capture": "retained"}]
        binding = {
            "head_id": "22222222-2222-4222-8222-222222222222",
            "body_md5": "a" * 32,
        }
        case = {
            "article_id": ready["article_id"],
            "locale": "en",
            "current_head": binding["head_id"],
            "current_body_md5": binding["body_md5"],
            "desired_article_sha256": "f" * 64,
            "payload_sha256": m.digest(
                json.dumps(
                    {"item": ready["item"], "sources": ready["sources"]},
                    ensure_ascii=False,
                    sort_keys=True,
                )
            ),
        }
        case["case_sha256"] = m.digest(
            json.dumps(case, ensure_ascii=False, sort_keys=True)
        )
        op = m.make_operation(
            ready,
            binding,
            "DISTINCT_SECTIONS_REQUIRE_APPROVED_RECONCILED_NEW_DRAFT",
            case,
        )
        altered = copy.deepcopy(ready)
        altered["item"]["source_capture_variants"] = []
        with self.assertRaisesRegex(ValueError, "review_case_payload"):
            m.make_operation(altered, binding, op["operation_class"], case)
        decision = {
            "decision": "create_detached_draft",
            "payload_sha256": op["payload_sha256"],
            "current_head": binding["head_id"],
            "current_body_md5": binding["body_md5"],
            "reviewer_id": "33333333-3333-4333-8333-333333333333",
            "review_receipt_sha256": "c" * 64,
        }
        with self.assertRaisesRegex(ValueError, "review_case_binding"):
            m.resolve_operation(op, decision)
        decision.update(
            case_sha256=case["case_sha256"],
            review_payload_sha256=case["payload_sha256"],
            desired_article_sha256=case["desired_article_sha256"],
        )
        self.assertEqual(
            m.resolve_operation(op, decision)["action"],
            "INSERT_DETACHED_UNVERIFIED_DRAFT",
        )

    def test_compensation_requires_separate_explicit_owner_authorization(self):
        m = self.module()
        op = m.make_operation(self.fixture(), None, "NEW_KEY_DRAFT_CANDIDATE")
        plan = m.seal_plan({"production_baseline": []}, [op])
        auth = self.authorization(m, plan)
        self.assertIn(
            "COMPENSATION_OWNER_RECOVERY_ACTOR", m.render_rollback_sql(plan, [op])
        )
        wrong_operation = copy.deepcopy(auth)
        wrong_operation["operation"] = "compensating_rollback"
        with self.assertRaisesRegex(
            ValueError, "apply_operation_authorization_required"
        ):
            m.render_sql(plan, [op], wrong_operation)
        with self.assertRaisesRegex(ValueError, "explicit_compensating"):
            m.render_rollback_sql(plan, [op], auth)

    def test_callback_policy_requires_operation_specific_reviewed_file_content(self):
        m = self.module()
        op = m.make_operation(self.fixture(), None, "NEW_KEY_DRAFT_CANDIDATE")
        plan = m.seal_plan({"production_baseline": []}, [op])
        auth = self.authorization(m, plan)
        auth["approved_ddl_event_callbacks"] = [
            {"evtname": "synthetic_notice_only", "callback_state_sha256": "c" * 64}
        ]
        with self.assertRaisesRegex(ValueError, "owner_review_receipt_file"):
            m.render_sql(plan, [op], auth)
        with tempfile.TemporaryDirectory() as tmp:
            receipt = Path(tmp) / "synthetic_callback_review.json"
            data = {
                "unit_fixture_only": True,
                "schema_version": 1,
                "project_id": m.PROJECT,
                "package_sha256": plan["package_sha256"],
                "generator_sha256": m.GENERATOR_AT_IMPORT,
                "reviewer_id": auth["actor_id"],
                "operation": "apply_unverified_drafts",
                "approved_policy_sha256": m.digest(
                    m.canonical(auth["approved_ddl_event_callbacks"])
                ),
                "reviewed_no_external_row_mutation": True,
            }
            receipt.write_text(json.dumps(data), "utf8")
            auth.update(
                ddl_event_callback_review_receipt_file=str(receipt),
                ddl_event_callback_review_receipt_sha256=m.digest(receipt.read_bytes()),
            )
            self.assertIn(
                "DDL_EVENT_TRIGGER_REVIEW_REQUIRED", m.render_sql(plan, [op], auth)
            )
            altered = copy.deepcopy(data)
            altered["operation"] = "compensating_rollback"
            receipt.write_text(json.dumps(altered), "utf8")
            auth["ddl_event_callback_review_receipt_sha256"] = m.digest(
                receipt.read_bytes()
            )
            with self.assertRaisesRegex(ValueError, "owner_review_content_binding"):
                m.render_sql(plan, [op], auth)


if __name__ == "__main__":
    unittest.main()
