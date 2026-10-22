#!/usr/bin/env python3
"""Regression test suite for fail-closed staging preflight."""
import tempfile
import unittest
from pathlib import Path

from scripts.staging_preflight import (
    FORWARD_MIGRATIONS,
    PRODUCTION_PROJECT,
    StagingPreflightError,
    validate_preflight,
)


def valid_config() -> dict:
    return {
        "APP_ENV": "staging",
        "RAD_DEPLOYMENT_KIND": "staging",
        "RAD_STAGING_PROJECT_REF": "stgproject1234567890",
        "RAD_STAGING_DB_URL": "postgresql://postgres:pass@db.stgproject1234567890.supabase.co:5432/postgres?sslmode=require",
        "RAD_STAGING_SITE_URL": "https://staging.rademigrate.invalid",
        "RAD_STAGING_BACKUP_RECORD": "snapshot_pre_stage8_20261022",
        "RAD_OWNER_STAGING_APPROVAL": "approval_owner_signed_20261022",
    }


class TestStagingPreflight(unittest.TestCase):
    def test_valid_staging_config_passes(self):
        result = validate_preflight(valid_config(), verify_git=False)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["mode"], "DRY_RUN_READ_ONLY")
        self.assertEqual(result["staging_project"], "stgproject1234567890")
        self.assertFalse(result["production_mutations"])

    def test_rejects_missing_project_id(self):
        cfg = valid_config()
        cfg["RAD_STAGING_PROJECT_REF"] = ""
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "missing_project_id")

    def test_rejects_production_project_id(self):
        cfg = valid_config()
        cfg["RAD_STAGING_PROJECT_REF"] = PRODUCTION_PROJECT
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "production_project_forbidden")

    def test_rejects_invalid_project_format(self):
        cfg = valid_config()
        cfg["RAD_STAGING_PROJECT_REF"] = "too-short"
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "invalid_project_format")

    def test_rejects_missing_backup_proof(self):
        cfg = valid_config()
        cfg["RAD_STAGING_BACKUP_RECORD"] = ""
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "missing_backup_proof")

    def test_rejects_missing_owner_approval(self):
        cfg = valid_config()
        cfg["RAD_OWNER_STAGING_APPROVAL"] = ""
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "missing_owner_approval")

    def test_rejects_unresolved_migration_conflicts(self):
        cfg = valid_config()
        cfg["UNRESOLVED_MIGRATION_CONFLICTS"] = "true"
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "unresolved_migration_conflicts")

    def test_rejects_migration_checksum_mismatch(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmppath = Path(tmpdir)
            # Create dummy migration files with corrupted hashes
            for fn, _ in FORWARD_MIGRATIONS:
                (tmppath / fn).write_text("-- corrupted\n", encoding="utf-8")
            with self.assertRaises(StagingPreflightError) as ctx:
                validate_preflight(valid_config(), verify_git=False, migration_dir=tmppath)
            self.assertTrue(str(ctx.exception).startswith("migration_checksum_mismatch_"))

    def test_rejects_non_staging_app_env(self):
        cfg = valid_config()
        cfg["APP_ENV"] = "production"
        with self.assertRaises(StagingPreflightError) as ctx:
            validate_preflight(cfg, verify_git=False)
        self.assertEqual(str(ctx.exception), "staging_environment_required")


if __name__ == "__main__":
    unittest.main()
