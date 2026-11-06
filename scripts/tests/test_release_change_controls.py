"""Prevent a merge/config-only change from silently releasing the application."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ReleaseChangeControls(unittest.TestCase):
    def test_render_requires_manual_deployment(self):
        source = (ROOT / "render.yaml").read_text("utf8")
        self.assertRegex(source, r"(?m)^    autoDeployTrigger: off$")
        self.assertNotRegex(source, r"(?m)^\s+autoDeploy:\s+true\s*$")

    def test_both_ci_events_cover_release_configuration(self):
        source = (ROOT / ".github/workflows/ci.yml").read_text("utf8")
        for event in ("pull_request", "push"):
            block = re.search(
                rf"(?ms)^  {event}:\n(.*?)(?=^  [a-z_]+:|^\S|\Z)", source
            )
            self.assertIsNotNone(block, event)
            for path in ("deploy/**", "render.yaml"):
                self.assertIn("      - '" + path + "'", block[1], event)

    def test_ci_cannot_use_production_secrets_or_deploy(self):
        for path in (ROOT / ".github/workflows").glob("*.y*ml"):
            source = path.read_text("utf8")
            self.assertNotIn("pull_request_target:", source, path.name)
            self.assertNotRegex(source, r"\$\{\{\s*secrets\.", path.name)
            self.assertNotRegex(source, r"(?m)^\s*id-token:\s*write", path.name)
            self.assertNotRegex(source, r"(?m)^\s*environment:", path.name)
            self.assertNotRegex(
                source, r"(?i)supabase\s+(?:db\s+push|functions\s+deploy)", path.name
            )


if __name__ == "__main__":
    unittest.main()
