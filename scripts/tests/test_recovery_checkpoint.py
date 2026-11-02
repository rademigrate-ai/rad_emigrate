"""Recovery-plan guards and failure-safe encrypted artifact handling."""

import copy
import hashlib
import sys
import tempfile
import threading
import unittest
from pathlib import Path

from scripts import recovery_checkpoint as recovery
from scripts import recovery_local_rehearsal as rehearsal


def profile():
    return {
        "source_project": recovery.PROJECT,
        "source_service": "rad_prod_readonly",
        "destination_project": "abcdefghijklmnopqrst",
        "destination_service": "rad_isolated_restore",
        "source_identity_sha256": "a" * 64,
        "destination_identity_sha256": "b" * 64,
        "owner_authorization_sha256": "c" * 64,
        "pg_service_file_ref": "file:private/pg_service.conf",
        "pg_pass_file_ref": "file:private/pgpass.conf",
        "recipient_fingerprint": "A" * 40,
        "key_custodian_ref": "vault:recovery/custodian",
        "encrypted_destination_ref": "vault:recovery/checkpoint",
        "retention_days": 30,
        "maximum_loss_seconds": 0,
        "maximum_restore_seconds": 7200,
        "source_writes_quiesced": True,
        "destination_empty": True,
        "outbound_blocked_before_restore": True,
        "cron_disabled_before_restore": True,
        "managed_restore_toc_review_sha256": "d" * 64,
    }


class RecoveryCheckpointTest(unittest.TestCase):
    def test_stalled_snapshot_stream_has_a_deadline(self):
        released = threading.Event()

        class StalledStream:
            def readline(self):
                released.wait()
                return ""

        try:
            with self.assertRaisesRegex(RuntimeError, "snapshot_export_timeout"):
                rehearsal.bounded_snapshot_line(StalledStream(), 0.01)
        finally:
            released.set()

    def test_failed_owned_cluster_shutdown_cannot_return_passing_receipt(self):
        receipt = {"status": "PASS_SYNTHETIC_ONLY"}
        with self.assertRaisesRegex(RuntimeError, "owned_cluster_shutdown_failed"):
            rehearsal.finalize_shutdown(receipt, 1)
        self.assertEqual(receipt["status"], "FAILED_OWNED_CLUSTER_SHUTDOWN")
        self.assertFalse(receipt["owned_cluster_stopped"])

    def test_rejects_swapped_shared_or_unapproved_destinations(self):
        for key, value in [
            ("destination_project", recovery.PROJECT),
            ("destination_project", recovery.STAGING),
            ("destination_project", recovery.SECURITY),
            ("destination_service", "rad_prod_readonly"),
            ("owner_authorization_sha256", None),
            ("outbound_blocked_before_restore", False),
            ("source_writes_quiesced", False),
        ]:
            candidate = copy.deepcopy(profile())
            candidate[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                recovery.build_plan(candidate, "00000003-0000001B-1")

    def test_plan_has_one_snapshot_and_separate_secret_references(self):
        plan = recovery.build_plan(profile(), "00000003-0000001B-1")
        self.assertEqual(plan["status"], "OPERATOR_PLAN_ONLY_NOT_RECOVERY_PROOF")
        self.assertEqual(plan["hosted_operations_executed"], 0)
        self.assertIn("--snapshot=00000003-0000001B-1", plan["database_producer"])
        self.assertIn("--format=custom", plan["database_producer"])
        self.assertEqual(plan["database_producer"][-1], "service=rad_prod_readonly")
        self.assertNotIn("password=", " ".join(plan["database_producer"]))
        self.assertNotIn("--clean", plan["restore_consumer"])
        self.assertIn("--exit-on-error", plan["restore_consumer"])

    def test_plaintext_credentials_and_snapshot_injection_are_rejected(self):
        bad = profile() | {"source_password": "must-not-be-logged"}
        with self.assertRaises(ValueError):
            recovery.build_plan(bad, "00000003-0000001B-1")
        with self.assertRaises(ValueError):
            recovery.build_plan(profile(), "1; drop database postgres")

    def test_failed_export_or_encrypt_never_promotes_partial_ciphertext(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "checkpoint.dump.gpg"
            producer = [
                sys.executable,
                "-c",
                "import sys;sys.stdout.buffer.write(b'partial');sys.exit(2)",
            ]
            consumer = [
                sys.executable,
                "-c",
                "import sys;sys.stdout.buffer.write(sys.stdin.buffer.read())",
            ]
            with self.assertRaisesRegex(RuntimeError, "producer_failed"):
                recovery.checked_export(producer, consumer, target)
            self.assertFalse(target.exists())
            self.assertFalse(target.with_suffix(".gpg.partial").exists())
            good = [sys.executable, "-c", "print('synthetic')"]
            broken = [
                sys.executable,
                "-c",
                "import sys;sys.stdin.buffer.read();sys.exit(3)",
            ]
            with self.assertRaisesRegex(RuntimeError, "encryptor_failed"):
                recovery.checked_export(good, broken, target)
            self.assertFalse(target.exists())

    def test_seal_detects_changed_or_missing_ciphertext(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "checkpoint.dump.gpg"
            target.write_bytes(b"synthetic ciphertext")
            manifest = {
                "checkpoint.dump.gpg": hashlib.sha256(target.read_bytes()).hexdigest()
            }
            recovery.verify_files(root, manifest)
            target.write_bytes(b"corrupted")
            with self.assertRaisesRegex(ValueError, "artifact_mismatch"):
                recovery.verify_files(root, manifest)
            with self.assertRaises(ValueError):
                recovery.verify_files(root, {"../outside.gpg": "a" * 64})


if __name__ == "__main__":
    unittest.main()
