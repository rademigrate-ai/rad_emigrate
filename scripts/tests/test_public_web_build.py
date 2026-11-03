import base64
import json
import tempfile
import unittest
from pathlib import Path

from scripts.public_web_build import PRODUCTION, validate_environment, verify_artifact

SYNTHETIC_BACKEND_KEY = "sb_secret_" + "SYNTHETIC_BACKEND_VALUE_12345"


def token(role="anon", project=PRODUCTION):
    payload = (
        base64.urlsafe_b64encode(json.dumps({"role": role, "ref": project}).encode())
        .decode()
        .rstrip("=")
    )
    return "eyJhbGciOiJIUzI1NiJ9." + payload + ".TEST_SIGNATURE_VALUE"


class PublicWebBuildTest(unittest.TestCase):
    def values(self):
        return {
            "APP_ENV": "production",
            "SUPABASE_URL": f"https://{PRODUCTION}.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_SYNTHETIC_PUBLIC_VALUE_12345",
        }

    def test_reject_privileged_or_wrong_project_configuration(self):
        for key in [
            SYNTHETIC_BACKEND_KEY,
            token("service_role"),
            token("authenticated"),
            token(project="s" * 20),
        ]:
            with (
                self.subTest(key_kind=key.split("_")[0]),
                self.assertRaises(ValueError),
            ):
                validate_environment(self.values() | {"SUPABASE_PUBLISHABLE_KEY": key})
        with self.assertRaises(ValueError):
            validate_environment(
                self.values() | {"SUPABASE_URL": "https://" + "s" * 20 + ".supabase.co"}
            )
        with self.assertRaises(ValueError):
            validate_environment(
                self.values() | {"SUPABASE_SERVICE_ROLE_KEY": "test-only-secret"}
            )

    def test_accept_legacy_anon_and_reject_url_credentials_or_fragments(self):
        self.assertEqual(
            validate_environment(self.values() | {"SUPABASE_PUBLISHABLE_KEY": token()})[
                "public_key_kind"
            ],
            "legacy_anon",
        )
        for url in [
            f"https://user@{PRODUCTION}.supabase.co",
            f"https://{PRODUCTION}.supabase.co/#other",
            f"http://{PRODUCTION}.supabase.co",
        ]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_environment(self.values() | {"SUPABASE_URL": url})

    def fixture(self, root):
        (root / "version.json").write_text(
            json.dumps({"git_sha": "a" * 40, "flutter": "3.47.6"}), encoding="utf8"
        )
        (root / "index.html").write_text("SPA", encoding="utf8")
        (root / "404.html").write_text("SPA", encoding="utf8")
        settings = self.values()
        (root / "main.dart.js").write_text(
            settings["SUPABASE_URL"] + " " + settings["SUPABASE_PUBLISHABLE_KEY"],
            encoding="utf8",
        )

    def test_artifact_requires_exact_commit_fallback_and_public_target(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            result = verify_artifact(root, self.values(), "a" * 40)
            self.assertEqual(result["privileged_key_scan"], "PASS")
            with self.assertRaisesRegex(ValueError, "version_commit"):
                verify_artifact(root, self.values(), "b" * 40)
            (root / "404.html").write_text("Wrong", encoding="utf8")
            with self.assertRaisesRegex(ValueError, "spa_fallback"):
                verify_artifact(root, self.values(), "a" * 40)

    def test_artifact_rejects_credential_in_another_asset_and_user_jwt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self.fixture(root)
            asset = root / "extra.json"
            asset.write_text(SYNTHETIC_BACKEND_KEY, encoding="utf8")
            with self.assertRaisesRegex(ValueError, "credential_pattern"):
                verify_artifact(root, self.values(), "a" * 40)
            asset.write_text(token("authenticated"), encoding="utf8")
            with self.assertRaisesRegex(ValueError, "nonpublic_or_wrong_project_jwt"):
                verify_artifact(root, self.values(), "a" * 40)


if __name__ == "__main__":
    unittest.main()
