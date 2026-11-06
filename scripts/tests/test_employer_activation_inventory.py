"""Inventory classification is evidence, never an activation authorization."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.employer_activation_inventory import PROJECT, compare


class EmployerInventoryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        (self.repo / "lib").mkdir()
        (self.repo / "supabase/migrations").mkdir(parents=True)
        (self.repo / "lib/client.dart").write_text("client.rpc('save_review');", "utf8")
        self.function = dict(
            schema="public",
            name="save_review",
            identity="p_request jsonb",
            arguments="p_request jsonb",
            result="jsonb",
            owner="postgres",
            security_definer=True,
            definition_sha256="a" * 64,
        )

    def inventory(self, installed=None, functions=None):
        with patch(
            "scripts.employer_activation_inventory.subprocess.check_output",
            side_effect=["b" * 40, ""],
        ):
            return compare(
                self.repo,
                {"project": PROJECT, "functions": installed or []},
                {
                    "project": "LOCAL_SYNTHETIC",
                    "functions": functions or [self.function],
                },
            )

    def test_exact_signature_and_definition_classification(self):
        self.assertEqual(self.inventory()["counts"]["MISSING"], 1)
        self.assertEqual(
            self.inventory([self.function])["counts"]["INSTALLED_SAME_DEFINITION"], 1
        )
        changed = {**self.function, "definition_sha256": "c" * 64}
        self.assertEqual(
            self.inventory([changed])["counts"]["INSTALLED_DIFFERENT_DEFINITION"], 1
        )
        overload = {**self.function, "identity": "p_id uuid"}
        self.assertEqual(self.inventory([overload])["counts"]["MISSING"], 1)

    def test_uncompiled_literal_is_not_silently_discarded(self):
        (self.repo / "lib/client.dart").write_text("client.rpc('not_defined');", "utf8")
        result = self.inventory()
        self.assertEqual(
            result["unresolved_client_literals"], {"not_defined": ["lib/client.dart"]}
        )
        self.assertFalse(result["execution_allowed"])

    def test_selector_reference_and_latest_definition_are_retained(self):
        (self.repo / "lib/client.dart").write_text(
            "const choice = 'save_review'; client.rpc(choice);", "utf8"
        )
        for version in ("20261104000001", "20261104000002"):
            (self.repo / f"supabase/migrations/{version}_candidate.sql").write_text(
                "CREATE OR REPLACE FUNCTION public.save_review(p_request jsonb)", "utf8"
            )
        result = self.inventory()
        self.assertTrue(
            result["rpc_inventory"][0]["last_definition_migration"].endswith(
                "20261104000002_candidate.sql"
            )
        )
        self.assertFalse(any(m["version_recorded"] for m in result["migration_files"]))
        self.assertFalse(result["execution_allowed"])

    def test_catalog_environment_labels_are_required(self):
        with self.assertRaisesRegex(ValueError, "explicit_production_and_isolated"):
            compare(self.repo, {"project": "other"}, {"project": "LOCAL_SYNTHETIC"})


if __name__ == "__main__":
    unittest.main()
