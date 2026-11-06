"""Image aliases and host architecture must not override the reviewed lock."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from scripts.self_host_stack import pin


class LockedImagePinning(unittest.TestCase):
    def test_pins_the_reviewed_reference_even_when_inspect_lists_an_alias_first(self):
        approved, result, saved = self.exercise(
            architecture="amd64", image_id="sha256:" + "b" * 64
        )
        self.assertEqual(saved["services"]["db"]["image"], approved)
        self.assertEqual(result["vendor/postgres:test"]["digest"], approved)

    def test_refuses_actual_architecture_mismatch(self):
        with self.assertRaisesRegex(ValueError, "architecture"):
            self.exercise(architecture="arm64", image_id="sha256:" + "b" * 64)

    def test_refuses_actual_image_identity_mismatch(self):
        with self.assertRaisesRegex(ValueError, "identity"):
            self.exercise(architecture="amd64", image_id="sha256:" + "c" * 64)

    def exercise(self, *, architecture, image_id):
        approved = "vendor/postgres@sha256:" + "a" * 64
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            model = {"services": {"db": {"image": "vendor/postgres:test"}}}
            (root / "compose.rad.json").write_text(json.dumps(model))
            lock = root / "images.lock.json"
            lock.write_text(json.dumps({"vendor/postgres:test": {
                "digest": approved,
                "architecture": "amd64",
                "image_id": "sha256:" + "b" * 64,
            }}))
            inspected = [{
                "Id": image_id,
                "Architecture": architecture,
                "RepoDigests": ["unreviewed/alias@sha256:" + "d" * 64, approved],
            }]
            with patch("scripts.self_host_stack.run", return_value=
                       subprocess.CompletedProcess([], 0, stdout=json.dumps(inspected).encode())):
                result = pin(root, lock)
            saved = json.loads((root / "compose.rad.json").read_text())
            return approved, result, saved


if __name__ == "__main__":
    unittest.main()
