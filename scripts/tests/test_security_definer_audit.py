"""Unit tests auditing all SECURITY DEFINER functions in Supabase migrations."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / "supabase" / "migrations"


class SecurityDefinerAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.functions = []
        sp_regex = re.compile(r"set\s+search_path\s*(?:=|\bto\b)", re.IGNORECASE)

        for file_path in sorted(MIGRATIONS.glob("*.sql")):
            content = file_path.read_text(encoding="utf-8")
            parts = re.split(r"(?i)create\s+(?:or\s+replace\s+)?function\s+", content)
            for part in parts[1:]:
                if re.search(r"(?i)\bsecurity\s+definer\b", part):
                    fn_name = part.split("(")[0].strip()
                    # Check before body opening ($$ or $function$ or $tag$)
                    body_match = re.search(r"\$[a-zA-Z0-9_]*\$", part)
                    header = part[: body_match.start()] if body_match else part[:500]
                    has_sp = bool(sp_regex.search(header))
                    cls.functions.append({
                        "file": file_path.name,
                        "name": fn_name,
                        "has_search_path": has_sp,
                    })

    def test_security_definer_functions_detected(self):
        self.assertGreaterEqual(
            len(self.functions),
            50,
            "Expected at least 50 SECURITY DEFINER functions across migrations",
        )

    def test_all_security_definer_functions_have_search_path_pinned(self):
        missing = [fn for fn in self.functions if not fn["has_search_path"]]
        self.assertEqual(
            missing,
            [],
            f"Found SECURITY DEFINER functions missing pinned search_path: {missing}",
        )

    def test_audit_report_document_exists(self):
        report = ROOT / "docs" / "SECURITY_DEFINER_PRIVILEGE_AUDIT_20261018.md"
        self.assertTrue(report.is_file(), "Audit document must exist")
        content = report.read_text(encoding="utf-8")
        self.assertIn("SECURITY DEFINER Privilege Audit", content)
        self.assertIn("search_path", content)


if __name__ == "__main__":
    unittest.main()

