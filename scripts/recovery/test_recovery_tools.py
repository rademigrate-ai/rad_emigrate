import argparse
import contextlib
import copy
import hashlib
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import encrypted_backup
import snapshot
import storage_manifest
import verify_bundle


class RecoveryToolsTest(unittest.TestCase):
    def test_storage_byte_change_missing_extra_and_empty_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            objects = root / "objects"
            objects.mkdir()
            (objects / "empty").write_bytes(b"")
            (objects / "binary").write_bytes(b"\x00\xff")
            original = storage_manifest.manifest(objects)
            self.assertEqual((original["count"], original["total_bytes"]), (2, 2))
            a, b = root / "a.json", root / "b.json"
            storage_manifest.write_json(original, a)
            storage_manifest.write_json(original, b)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(storage_manifest.compare(a, b), 0)
            changed = copy.deepcopy(original)
            changed["objects"][0]["sha256"] = "0" * 64
            b.write_text(json.dumps(changed), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(storage_manifest.compare(a, b), 1)
            changed["objects"].pop()
            changed["objects"].append({"key": "extra", "bytes": 0, "sha256": "0" * 64})
            b.write_text(json.dumps(changed), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(storage_manifest.compare(a, b), 1)
            with self.assertRaises(FileExistsError):
                storage_manifest.write_json(original, a)

    def test_invalid_storage_manifest_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / "invalid.json"
            file.write_text('{}', encoding="utf-8")
            with self.assertRaises(ValueError):
                storage_manifest.compare(file, file)

    def test_ciphertext_hash_and_partial_detection(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cipher = root / "fixture.age"
            cipher.write_bytes(b"synthetic ciphertext only")
            value = {"format": "rad-encrypted-recovery-v1", "files": [{"file": cipher.name,
                "bytes": cipher.stat().st_size, "sha256": hashlib.sha256(cipher.read_bytes()).hexdigest()}]}
            (root / "ciphertext-manifest.json").write_text(json.dumps(value), encoding="utf-8")
            self.assertEqual(verify_bundle.verify(root), 1)
            (root / "incomplete.partial").write_bytes(b"partial")
            with self.assertRaises(ValueError):
                verify_bundle.verify(root)
            (root / "incomplete.partial").unlink()
            cipher.write_bytes(b"tampered ciphertext only!")
            with self.assertRaises(ValueError):
                verify_bundle.verify(root)

    def test_duplicate_storage_keys_are_rejected(self):
        value = {"format": "rad-storage-byte-manifest-v1", "objects": [
            {"key": "fixture", "bytes": 0, "sha256": "0" * 64}] * 2,
            "count": 2, "total_bytes": 0}
        with tempfile.TemporaryDirectory() as temp:
            file = Path(temp) / "duplicate.json"
            file.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(ValueError):
                storage_manifest.compare(file, file)

    def test_effective_overgrant_and_data_mismatch_fail(self):
        source = {key: [] for key in snapshot.REQUIRED_SECTIONS}
        source.update({"format": "rad-postgres-recovery-snapshot-v1", "postgres": "17.11",
                  "effective_tables": [{"key": "public.fixture", "role": "anon", "select": False}],
                  "data_hashes": {"public.fixture": {"rows": 1, "sha256_of_row_sha256s": "a"}}})
        with tempfile.TemporaryDirectory() as temp:
            a, b = Path(temp) / "a.json", Path(temp) / "b.json"
            a.write_text(json.dumps(source), encoding="utf-8")
            b.write_text(json.dumps(source), encoding="utf-8")
            args = argparse.Namespace(source=a, target=b)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(snapshot.compare(args), 0)
            changed = copy.deepcopy(source)
            changed["effective_tables"][0]["select"] = True
            b.write_text(json.dumps(changed), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(snapshot.compare(args), 1)
            changed = copy.deepcopy(source)
            changed["data_hashes"]["public.fixture"]["sha256_of_row_sha256s"] = "b"
            b.write_text(json.dumps(changed), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(snapshot.compare(args), 1)

    def test_storage_inventory_missing_and_size_mismatch_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "objects").mkdir()
            (root / "objects" / "fixture").write_bytes(b"abc")
            metadata, objects = root / "db.json", root / "objects.json"
            value = {"format": "rad-postgres-recovery-snapshot-v1",
                     "storage_inventory": [{"key": "fixture", "bytes": 3}]}
            metadata.write_text(json.dumps(value), encoding="utf-8")
            storage_manifest.write_json(storage_manifest.manifest(root / "objects"), objects)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(storage_manifest.reconcile(metadata, objects), 0)
            value["storage_inventory"][0]["bytes"] = 2
            metadata.write_text(json.dumps(value), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(storage_manifest.reconcile(metadata, objects), 1)
            value["storage_inventory"][0]["key"] = "missing"
            metadata.write_text(json.dumps(value), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(storage_manifest.reconcile(metadata, objects), 1)
    def test_service_without_approval_never_starts_psql(self):
        args = argparse.Namespace(docker_container=None, service="rad_prod_backup", project_ref=None,
                                  approval_file=None, data_hashes=False, writes_frozen=False)
        with mock.patch.object(snapshot, "run_psql") as run:
            with self.assertRaises(ValueError):
                snapshot.capture(args)
            run.assert_not_called()

    def test_incomplete_database_snapshot_cannot_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "incomplete.json"
            path.write_text(json.dumps({"format": "rad-postgres-recovery-snapshot-v1",
                                        "postgres": "17.11"}), encoding="utf-8")
            with self.assertRaises(ValueError):
                snapshot.compare(argparse.Namespace(source=path, target=path))

    def test_data_hashes_require_frozen_writes(self):
        args = argparse.Namespace(docker_container="rad-synthetic", service=None, data_hashes=True,
                                  writes_frozen=False)
        with mock.patch.object(snapshot, "run_psql") as run:
            with self.assertRaises(ValueError):
                snapshot.capture(args)
            run.assert_not_called()

    def test_local_capture_forces_read_only_and_utc(self):
        args = argparse.Namespace(docker_container="rad-synthetic", database="fixture")
        command = snapshot.psql_command(args, "SELECT 1")
        self.assertIn("PGOPTIONS=-c default_transaction_read_only=on", command)
        self.assertIn("PGTZ=UTC", command)
        self.assertNotIn("shell", command)

    def test_approval_scope_and_tls_are_enforced(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            approval = root / "approval.json"
            approval.write_text(json.dumps({"project_ref": "synthetic-ref",
                "authorized_operations": ["database_backup"], "owner_approval_reference": "synthetic",
                "dba_approval_reference": "synthetic"}), encoding="utf-8")
            args = argparse.Namespace(approval_file=approval, project_ref="synthetic-ref",
                                      writes_frozen=True, service="rad_backup")
            encrypted_backup.approval(args, "database_backup")
            with self.assertRaises(ValueError):
                encrypted_backup.approval(args, "storage_backup")
            service = root / "pg_service.conf"
            service.write_text('[rad_backup]\nhost=db.synthetic-ref.supabase.co\nport=5432\n'
                               'sslmode=disable\nuser=backup\n', encoding="utf-8")
            with mock.patch.dict(os.environ, {"PGSERVICEFILE": str(service)}):
                with self.assertRaises(ValueError):
                    encrypted_backup.validate_service(args)
                service.write_text(service.read_text().replace('disable', 'verify-full'), encoding="utf-8")
                encrypted_backup.validate_service(args)


if __name__ == "__main__":
    unittest.main()
