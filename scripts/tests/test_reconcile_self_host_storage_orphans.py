"""Guardrails for the deliberately non-automatic Storage orphan reconciler."""

import unittest

from scripts.reconcile_self_host_storage_orphans import approved_orphans


class OrphanApprovalTests(unittest.TestCase):
    def test_explicit_approved_path_is_required(self):
        with self.assertRaisesRegex(ValueError, "approved-object"):
            approved_orphans(["user/orphan.pdf"], [])

    def test_unverified_object_is_not_permitted(self):
        with self.assertRaisesRegex(ValueError, "age-verified"):
            approved_orphans(["user/verified.pdf"], ["user/unverified.pdf"])

    def test_duplicate_approval_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate"):
            approved_orphans(["a.pdf"], ["a.pdf", "a.pdf"])

    def test_allows_only_explicit_verified_subset(self):
        self.assertEqual(
            approved_orphans(["b.pdf", "a.pdf", "c.pdf"], ["b.pdf", "a.pdf"]),
            ["a.pdf", "b.pdf"],
        )


if __name__ == "__main__":
    unittest.main()
