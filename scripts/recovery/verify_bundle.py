#!/usr/bin/env python3
"""Verify ciphertext byte hashes; authenticate the manifest separately first."""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


def verify(root):
    root = Path(root).resolve(strict=True)
    value = json.loads((root / "ciphertext-manifest.json").read_text(encoding="utf-8"))
    if value.get("format") != "rad-encrypted-recovery-v1" or not value.get("files"):
        raise ValueError("invalid encrypted bundle manifest")
    seen = set()
    for item in value["files"]:
        name = item["file"]
        if (name in seen or Path(name).name != name or '/' in name or '\\' in name or
                not name.endswith('.age') or not re.fullmatch(r"[0-9a-f]{64}", item["sha256"])):
            raise ValueError("invalid or duplicate encrypted filename/hash")
        path = root / name
        if path.is_symlink() or path.stat().st_size != item["bytes"]:
            raise ValueError("encrypted file size or path mismatch")
        with path.open("rb") as stream:
            actual = hashlib.file_digest(stream, "sha256").hexdigest()
        if actual != item["sha256"]:
            raise ValueError("encrypted file hash mismatch")
        seen.add(name)
    if seen != {x.name for x in root.glob('*.age')} or list(root.glob('*.partial')):
        raise ValueError("unexpected encrypted or incomplete files in bundle")
    return len(seen)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True)
    args = parser.parse_args()
    try:
        count = verify(args.root)
        print(json.dumps({"status": "PASS", "encrypted_files": count}))
        return 0
    except (OSError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
