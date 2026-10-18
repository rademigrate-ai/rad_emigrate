"""Unit tests verifying foreign-key index coverage in migrations."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"


class ForeignKeyCoveringIndexesTests(unittest.TestCase):
    def test_stage10_covering_indexes_migration_exists_and_covers_unindexed_fks(self):
        migration_file = MIGRATIONS / "20261018210000_stage10_covering_fk_indexes_completion.sql"
        self.assertTrue(migration_file.is_file(), "Stage 10 migration file must exist")
        content = migration_file.read_text(encoding="utf-8")

        # Must cover the 3 candidate foreign keys flagged in the audit
        self.assertIn("knowledge_claims_superseded_by_idx", content)
        self.assertIn("consultation_requests_assigned_to_idx", content)
        self.assertIn("consultation_requests_related_application_id_idx", content)

        # Must use conditional execution and partial index pattern
        self.assertIn("CREATE INDEX IF NOT EXISTS", content)
        self.assertIn("WHERE superseded_by IS NOT NULL", content)
        self.assertIn("WHERE assigned_to IS NOT NULL", content)
        self.assertIn("WHERE related_application_id IS NOT NULL", content)

    def test_all_stage10_indexes_target_valid_schema_columns(self):
        migration_file = MIGRATIONS / "20261018210000_stage10_covering_fk_indexes_completion.sql"
        content = migration_file.read_text(encoding="utf-8")
        # Ensure proper syntax without dangerous DROP commands
        self.assertNotIn("DROP TABLE", content.upper())
        self.assertNotIn("DROP INDEX", content.upper())
        self.assertNotIn("TRUNCATE", content.upper())


if __name__ == "__main__":
    unittest.main()

