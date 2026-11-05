import unittest

from scripts.document_retention_report import candidate_query, validate_policy


class RetentionPolicyTests(unittest.TestCase):
    def test_default_policy_has_no_invented_duration_or_clock(self):
        policy = {
            "automatic_purge_enabled": False,
            "retention_days": None,
            "clock_anchor": None,
            "terminal_application_statuses": [],
            "policy_approval_reference": None,
        }
        self.assertFalse(validate_policy(policy))
        self.assertIsNone(candidate_query(policy))

    def test_destructive_switch_missing_approval_or_unknown_clock_fail_closed(self):
        policy = {
            "automatic_purge_enabled": False,
            "retention_days": 30,
            "clock_anchor": "document_created_at",
            "terminal_application_statuses": ["closed"],
            "policy_approval_reference": "synthetic-test-only",
        }
        for change in [
            {"automatic_purge_enabled": True},
            {"policy_approval_reference": None},
            {"clock_anchor": "invented_closed_at"},
            {"retention_days": True},
            {"terminal_application_statuses": ["closed');delete from documents;--"]},
        ]:
            with self.assertRaises(ValueError):
                validate_policy(policy | change)

    def test_report_excludes_holds_and_pending_requests_and_has_no_mutations(self):
        query = candidate_query(
            {
                "automatic_purge_enabled": False,
                "retention_days": 30,
                "clock_anchor": "document_created_at",
                "terminal_application_statuses": ["closed"],
                "policy_approval_reference": "synthetic-test-only",
            }
        )
        self.assertIn("rad_document_preservation_holds", query)
        self.assertIn("rad_document_deletions", query)
        self.assertTrue(query.lstrip().lower().startswith("select"))
        self.assertNotIn("request_document_deletion", query)
