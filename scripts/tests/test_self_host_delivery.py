import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts.build_self_host_delivery import assemble


class DeliveryBoundaries(unittest.TestCase):
    def test_refuses_existing_directory_without_touching_it(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output = root / "existing"
            output.mkdir()
            marker = output / "keep"
            marker.write_text("preserve")
            with self.assertRaises(ValueError):
                assemble(root / "repo", root / "upstream", output)
            self.assertEqual(marker.read_text(), "preserve")

    def test_dirty_checkout_cannot_be_mislabeled_as_a_commit(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            output = root / "delivery"
            with patch(
                "scripts.build_self_host_delivery.git", return_value=" M changed"
            ):
                with self.assertRaisesRegex(ValueError, "commit all"):
                    assemble(root / "repo", root / "upstream", output)
            self.assertFalse(output.exists())

    def test_refuses_output_inside_repository(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with self.assertRaises(ValueError):
                assemble(root, root / "upstream", root / "public/delivery")
            self.assertFalse((root / "public").exists())
