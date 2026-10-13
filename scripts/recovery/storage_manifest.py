#!/usr/bin/env python3
"""Hash staged Supabase Storage bytes and compare source/restore manifests.

Operate only on an owner-approved, encrypted or tmpfs staging directory. This
tool does not connect to Supabase, list private objects, or upload anything.
"""

import argparse
import hashlib
import json
import os
import re
import sys
from pathlib import Path


def manifest(root):
    if Path(root).is_symlink():
        raise ValueError("Storage root must not be a symlink")
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError("Storage root must be a directory")
    objects = []
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            if (Path(base) / name).is_symlink():
                raise ValueError("symlink in Storage staging tree")
        for name in files:
            path = Path(base) / name
            before = path.stat()
            digest = hashlib.sha256()
            with path.open("rb") as stream:
                while block := stream.read(1024 * 1024):
                    digest.update(block)
            after = path.stat()
            if (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
                raise ValueError("Storage file changed during hashing; freeze writes and repeat")
            objects.append({"key": path.relative_to(root).as_posix(),
                            "bytes": path.stat().st_size, "sha256": digest.hexdigest()})
    objects.sort(key=lambda x: x["key"])
    return {"format": "rad-storage-byte-manifest-v1", "objects": objects,
            "count": len(objects), "total_bytes": sum(o["bytes"] for o in objects)}


def write_json(value, output):
    result = json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"
    if output:
        with Path(output).open("x", encoding="utf-8") as stream:
            stream.write(result)
    else:
        print(result, end="")


def load_manifest(path):
    value = json.loads(Path(path).read_text(encoding="utf-8"))
    if value.get("format") != "rad-storage-byte-manifest-v1":
        raise ValueError("unexpected Storage manifest format")
    keys = []
    for item in value["objects"]:
        key = item["key"]
        if (not isinstance(key, str) or not key or key.startswith('/') or '\\' in key or
                any(part in ('.', '..', '') for part in key.split('/')) or
                not re.fullmatch(r"[0-9a-f]{64}", item["sha256"]) or
                type(item["bytes"]) is not int or item["bytes"] < 0):
            raise ValueError("invalid Storage object manifest entry")
        keys.append(key)
    if len(set(keys)) != len(keys) or value["count"] != len(keys) or value["total_bytes"] != sum(x["bytes"] for x in value["objects"]):
        raise ValueError("duplicate keys or inconsistent Storage totals")
    return value


def compare(source, target):
    left, right = load_manifest(source), load_manifest(target)
    a = {x["key"]: x for x in left["objects"]}
    b = {x["key"]: x for x in right["objects"]}
    missing = sorted(a.keys() - b.keys())
    extra = sorted(b.keys() - a.keys())
    changed = sorted(k for k in a.keys() & b.keys() if a[k] != b[k])
    status = "PASS" if not (missing or extra or changed) else "FAIL"
    print(json.dumps({"status": status, "source_count": len(a), "target_count": len(b),
                      "missing": missing, "extra": extra, "changed": changed}, indent=2))
    return 0 if status == "PASS" else 1


def reconcile(database_snapshot, storage_manifest):
    database = json.loads(Path(database_snapshot).read_text(encoding="utf-8"))
    if database.get("format") != "rad-postgres-recovery-snapshot-v1" or "storage_inventory" not in database:
        raise ValueError("source database Storage inventory is required")
    inventory = database["storage_inventory"]
    source = {}
    for item in inventory:
        if item["key"] in source or type(item["bytes"]) is not int or item["bytes"] < 0:
            raise ValueError("duplicate source keys or missing source byte size")
        source[item["key"]] = item["bytes"]
    bytes_manifest = load_manifest(storage_manifest)
    target = {x["key"]: x["bytes"] for x in bytes_manifest["objects"]}
    missing = sorted(source.keys() - target.keys())
    extra = sorted(target.keys() - source.keys())
    mismatched = sorted(k for k in source.keys() & target.keys() if source[k] != target[k])
    status = "PASS" if not (missing or extra or mismatched) else "FAIL"
    print(json.dumps({"status": status, "source_object_count": len(source),
                      "backed_up_object_count": len(target), "missing": missing,
                      "extra": extra, "size_mismatch": mismatched}, indent=2))
    return 0 if status == "PASS" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    cap = sub.add_parser("capture")
    cap.add_argument("--root", required=True)
    cap.add_argument("--output")
    cmp = sub.add_parser("compare")
    cmp.add_argument("--source", required=True)
    cmp.add_argument("--target", required=True)
    rec = sub.add_parser("reconcile")
    rec.add_argument("--database-snapshot", required=True)
    rec.add_argument("--storage-manifest", required=True)
    args = parser.parse_args()
    try:
        if args.command == "capture":
            write_json(manifest(args.root), args.output)
            return 0
        if args.command == "reconcile":
            return reconcile(args.database_snapshot, args.storage_manifest)
        return compare(args.source, args.target)
    except (OSError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
