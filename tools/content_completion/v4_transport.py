"""Hash-bound compressed transport for reviewed public-content SQL operations.

OpenPGP compression reduces repetitive full article/provenance payloads. The
fixed public transport passphrase is not a secret and provides no confidentiality.
Plain, reviewable SQL, its hashes and the complete operation list remain the
authority; the server verifies the decompressed hash before executing anything.
This tool creates files only, never connects to hosted databases.
"""

import argparse
import base64
import gzip
import hashlib
import json
import subprocess
from pathlib import Path

from tools.content_completion.phase_bundle import save_json

PUBLIC_PASSPHRASE = "RAD-V4-PUBLIC-CONTENT-TRANSPORT-NOT-A-SECRET"


def build(directory, gpg, batch_size=5):
    if not 1 <= batch_size <= 20:
        raise ValueError("invalid_batch_size")
    plan = json.loads((directory / "import-plan.json").read_text("utf-8"))
    if plan["project"] != "epolbumcfbohtmgvomki" or plan["publication_allowed"]:
        raise ValueError("staging_drafts_only")
    target = directory / "transport"
    target.mkdir(exist_ok=True)
    gpg_home = target / ".gnupg"
    gpg_home.mkdir(exist_ok=True)
    batches = []
    for start in range(0, len(plan["operations"]), batch_size):
        operations = plan["operations"][start : start + batch_size]
        texts = []
        for operation in operations:
            raw = gzip.decompress((directory / operation["file"]).read_bytes())
            if hashlib.sha256(raw).hexdigest() != operation["sha256"]:
                raise ValueError("reviewed_operation_hash_changed")
            content = raw.decode("utf-8")
            if "begin;\n" not in content or not content.endswith("commit;\n"):
                raise ValueError("unexpected_transaction_shape")
            texts.append(content.split("begin;\n", 1)[1].removesuffix("commit;\n"))
        sql = "\n".join(texts)
        checksum = hashlib.sha256(sql.encode("utf-8")).hexdigest()
        encrypted = subprocess.run(
            [
                str(gpg),
                "--no-options",
                "--homedir",
                str(gpg_home.resolve()),
                "--batch",
                "--yes",
                "--pinentry-mode",
                "loopback",
                "--passphrase",
                PUBLIC_PASSPHRASE,
                "--symmetric",
                "--cipher-algo",
                "AES256",
                "--compress-algo",
                "ZIP",
                "--compress-level",
                "9",
                "--s2k-count",
                "1024",
                "--output",
                "-",
            ],
            input=sql.encode("utf-8"),
            capture_output=True,
            check=True,
        ).stdout
        encoded = base64.b64encode(encrypted).decode("ascii")
        query = f"""-- Reviewed V4 Staging draft content operations; all original SQL hashes in import-plan.json.
-- OpenPGP is used only for compression of complete public article payloads.
begin;
set local statement_timeout='120s';
do $transport$ declare content text;begin
content:=convert_from(extensions.pgp_sym_decrypt_bytea(decode('{encoded}','base64'),'{PUBLIC_PASSPHRASE}'),'UTF8');
if encode(extensions.digest(content,'sha256'),'hex')<>'{checksum}' then raise exception 'v4_transport_hash_mismatch';end if;
execute content;
end $transport$;
commit;
select jsonb_build_object('v4_manifest','{plan["manifest_sha256"]}','transport_batch',{len(batches)},'operations',{len(operations)},'publication_allowed',false,'import_gate_enabled',(select enabled from private.rad_editorial_import_target where project_ref='epolbumcfbohtmgvomki')) receipt;
"""
        filename = f"batch-{len(batches):04d}.json"
        save_json(
            target / filename,
            {"query": query, "operations": operations, "decompressed_sha256": checksum},
        )
        batches.append(
            {
                "file": filename,
                "operations": len(operations),
                "query_bytes": len(query),
                "sha256": hashlib.sha256((target / filename).read_bytes()).hexdigest(),
            }
        )
    manifest = {
        "project": plan["project"],
        "manifest_sha256": plan["manifest_sha256"],
        "batch_id": plan["batch_id"],
        "batches": batches,
        "operation_count": len(plan["operations"]),
        "publication_allowed": False,
    }
    save_json(target / "manifest.json", manifest)
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument(
        "--gpg", type=Path, default=Path(r"C:\Program Files\GnuPG\bin\gpg.exe")
    )
    parser.add_argument("--batch-size", type=int, default=5)
    args = parser.parse_args()
    result = build(args.directory, args.gpg, args.batch_size)
    print(json.dumps({k: v for k, v in result.items() if k != "batches"}))
