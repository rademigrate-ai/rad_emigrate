"""Exercise actual GPG -> pgcrypto transport on the marked local V4 fixture."""

import gzip
import hashlib
import json
from pathlib import Path

from tools.content_completion.v4_database_evidence import jsonb_text
from tools.content_completion.v4_local_import import ROOT, connection
from tools.content_completion.v4_transport import build


def run():
    output = ROOT / "_scratch/v4-transport-roundtrip"
    output.mkdir(parents=True, exist_ok=True)
    value = {"long": [True, None, "متن فارسی با نیم‌فاصله"], "é": 2, "b": 1, "aa": 3}
    encoded = json.dumps(value, ensure_ascii=False).replace("'", "''")
    expected = jsonb_text(value).replace("'", "''")
    operations = []
    for index in range(2):
        raw = f"begin;\ndo $probe$begin if '{encoded}'::jsonb::text<>'{expected}' then raise exception 'independent_jsonb_hash_serialization_mismatch';end if;end $probe$;\ncommit;\n".encode()
        file = f"operation-{index:04d}.sql.gz"
        (output / file).write_bytes(gzip.compress(raw))
        operations.append({"file": file, "sha256": hashlib.sha256(raw).hexdigest()})
    plan = {
        "project": "epolbumcfbohtmgvomki",
        "publication_allowed": False,
        "manifest_sha256": "a" * 64,
        "batch_id": "local-public-transport-probe",
        "operations": operations,
    }
    (output / "import-plan.json").write_text(json.dumps(plan), encoding="utf-8")
    manifest = build(output, Path(r"C:\Program Files\GnuPG\bin\gpg.exe"))
    batch = json.loads((output / "transport/batch-0000.json").read_text("utf-8"))
    sql = connection(ROOT / "_scratch/v4-runtime")
    result = sql(batch["query"])
    if '"operations": 2' not in result:
        raise ValueError("actual_transport_receipt_missing")
    rejected = False
    try:
        sql(batch["query"].replace(batch["decompressed_sha256"], "0" * 64))
    except RuntimeError as error:
        if "v4_transport_hash_mismatch" not in str(error):
            raise
        rejected = True
    if not rejected:
        raise ValueError("tampered_transport_accepted")
    receipt = {
        "status": "PASS",
        "actual_gpg_pgcrypto_unicode_roundtrip": True,
        "actual_multistatement_execution": True,
        "independent_postgres_jsonb_serialization": True,
        "tampered_decompressed_hash_rejected": True,
        "hosted_operations": 0,
        "persistent_database_mutations": 0,
        "manifest": manifest,
    }
    (
        ROOT / "artifacts/RAD_FULL_CONTENT_V4_20261028/local-transport-roundtrip.json"
    ).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps({key: value for key, value in receipt.items() if key != "manifest"})
    )


if __name__ == "__main__":
    run()
