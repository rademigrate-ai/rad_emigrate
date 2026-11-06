"""Native rehearsal and evidence collection retain the exact local marker guard."""

import tempfile
import unittest
from pathlib import Path

from tools.content_completion.v4_corpus_rehearsal import run
from tools.content_completion.v4_database_evidence import collect_local


class NativeRehearsalGuardTests(unittest.TestCase):
    def test_rehearsal_refuses_unowned_runtime_before_reading_corpus(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, "owned_v4_runtime_path_required"):
                run(Path("absent-corpus"), Path(temporary), runtime=Path("wrong"))

    def test_receipt_collection_refuses_unowned_runtime_before_reading_queries(self):
        with self.assertRaisesRegex(ValueError, "owned_v4_runtime_path_required"):
            collect_local(Path("absent-evidence"), runtime=Path("wrong"))
