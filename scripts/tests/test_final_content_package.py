"""Corrected versions preserve old evidence and keep unsupported content held."""

import copy
import json
import tempfile
import unittest
from pathlib import Path

from scripts import final_content_package as final
from scripts import production_reconciliation_package as original
from scripts.tests import test_production_reconciliation_sql as native
from tools.content_completion.source_delivery_forensics import (
    propose_dubai_country_correction,
)


class CorrectedPackageTest(unittest.TestCase):
    def ready(self, article="11111111-1111-4111-8111-111111111111"):
        ready = native.ReconciliationSQLTest().ready(article, "Dubai is in the UAE.")
        ready["item"].update(
            title="Dubai study",
            sections=[],
            conflicts=[],
            composition_policy="RAD_CONTENT_PRECEDENCE_V4.1",
        )
        return ready

    def operation(self, ready):
        return original.make_operation(ready, None, "NEW_KEY_DRAFT_CANDIDATE")

    def correction(self, parent, root):
        asset = root / "official-page.json"
        asset.write_text("Official Dubai geography reference", encoding="utf8")
        ref = {
            "url": "https://www.moet.gov.ae/en/web/guest/emirates-of-the-uae",
            "captured_page_asset": str(asset),
            "captured_page_sha256": final.file_sha(asset),
        }
        payload = propose_dubai_country_correction(
            parent["payload"],
            parent["payload"]["sources"][0]["source_id"],
            "Dubai is in the UAE.",
            ref,
        )
        return {
            "original_operation_id": parent["operation_id"],
            "original_payload_sha256": parent["payload_sha256"],
            "proposed_operation": self.operation(payload),
        }

    def test_country_version_preserves_full_body_identity_and_parent(self):
        parent = self.operation(self.ready())
        before = copy.deepcopy(parent)
        with tempfile.TemporaryDirectory() as tmp:
            proposal = self.correction(parent, Path(tmp))
            result = final.correct_operations([parent], [proposal])
        self.assertEqual(parent, before)
        self.assertEqual(result[0]["payload"]["item"]["country_codes"], ["AE"])
        self.assertEqual(
            result[0]["payload"]["item"]["draft_request"],
            parent["payload"]["item"]["draft_request"],
        )
        self.assertNotEqual(result[0]["revision_id"], parent["revision_id"])
        self.assertFalse(result[0]["advance_existing_head"])

    def test_country_version_rejects_body_edit_duplicate_or_forged_reference(self):
        parent = self.operation(self.ready())
        with tempfile.TemporaryDirectory() as tmp:
            proposal = self.correction(parent, Path(tmp))
            changed = copy.deepcopy(proposal)
            changed["proposed_operation"]["payload"]["item"]["draft_request"][
                "summary"
            ] = "Changed claim"
            with self.assertRaisesRegex(ValueError, "only_unassigned"):
                final.correct_operations([parent], [changed])
            with self.assertRaisesRegex(ValueError, "unique_existing"):
                final.correct_operations([parent], [proposal, proposal])
            Path(
                proposal["proposed_operation"]["payload"]["item"][
                    "country_source_evidence"
                ]["geography_reference"]["captured_page_asset"]
            ).write_text("tampered", encoding="utf8")
            with self.assertRaisesRegex(ValueError, "literal_original"):
                final.correct_operations([parent], [proposal])

    def test_source_kind_is_bound_to_actual_variant_and_original_raw_hash(self):
        op = self.operation(self.ready())
        sid = op["payload"]["sources"][0]["source_id"]
        proof = {
            sid: {
                "raw_html_sha256": "a" * 64,
                "observed_content_kind": "CATEGORY_LIST_WITH_PARTIAL_EXCERPTS",
            }
        }
        self.assertEqual(
            final.capture_kind_holds(op, proof),
            ["source_kind_or_article_completeness_unresolved"],
        )
        proof[sid]["observed_content_kind"] = final.AUTHORED
        self.assertEqual(final.capture_kind_holds(op, proof), [])
        proof[sid]["raw_html_sha256"] = "b" * 64
        with self.assertRaisesRegex(ValueError, "exact_source_kind"):
            final.capture_kind_holds(op, proof)
        with self.assertRaisesRegex(ValueError, "exact_source_kind"):
            final.capture_kind_holds(op, {})

    def test_rebuilt_batches_exclude_indexes_and_have_no_human_approval(self):
        first = self.operation(self.ready())
        other = self.ready("22222222-2222-4222-8222-222222222222")
        other["sources"][0]["source_id"] = "99999999-9999-4999-8999-999999999999"
        second = self.operation(other)
        ops = [first, second]
        plan = original.seal_plan({}, ops)
        decisions = {
            "format": "RAD_MECHANICAL_RECONCILIATION_V1",
            "policy": "RAD_CONTENT_PRECEDENCE_V4.1",
            "package_sha256": plan["package_sha256"],
            "adapter_sha256": final.file_sha(Path(final.mechanical.__file__)),
            "dispositions": [],
        }
        decisions["decision_package_sha256"] = original.digest(
            original.canonical(decisions)
        )
        captures = {
            first["payload"]["sources"][0]["source_id"]: {
                "raw_html_sha256": "a" * 64,
                "observed_content_kind": final.AUTHORED,
            },
            other["sources"][0]["source_id"]: {
                "raw_html_sha256": "a" * 64,
                "observed_content_kind": "CATEGORY_LIST_WITH_PARTIAL_EXCERPTS",
            },
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            proof = root / "proof.json"
            proof.write_text("{}", encoding="utf8")
            report = final.prepare_batches(
                plan, ops, decisions, captures, proof, root / "batches"
            )
            request = json.loads(
                (
                    root / "batches" / report["batches"][0]["approval_request_file"]
                ).read_text("utf8")
            )
        self.assertEqual((report["eligible_proposals"], report["held"]), (1, 1))
        members = json.loads(request["p_manifest_text"])
        self.assertEqual([m["revision_id"] for m in members], [first["revision_id"]])
        self.assertEqual(
            original.digest(request["p_manifest_text"]), request["p_manifest_sha256"]
        )
        self.assertIsNone(request["p_note"])
        self.assertEqual(
            (report["approved"], report["published"], report["hosted_writes"]),
            (0, 0, 0),
        )


class PublicationHoldSQLTest(unittest.TestCase):
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
            cls.fixture.sql(
                (
                    Path(__file__).resolve().parents[2]
                    / "supabase/migrations/20261103114340_rad_corrected_source_editorial_admission.sql"
                ).read_text("utf8")
            )
        except BaseException:
            cls.fixture.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        cls.fixture.tearDownClass()

    def test_exact_held_revision_denied_and_hold_rows_immutable_and_private(self):
        self.fixture.sql(
            (
                Path(__file__).resolve().parents[2]
                / "supabase/tests/corrected_source_editorial_holds.sql"
            ).read_text("utf8")
        )


if __name__ == "__main__":
    unittest.main()
