"""Resume discovery from immutable, hash-verified prior caches, never from zero."""

import argparse
import gzip
import hashlib
import json
import shutil
from pathlib import Path

from tools.content_completion.guarded_crawl import GuardedCollector
from tools.content_completion.reconcile import progress
from tools.plan3_content.dataset import read_jsonl


def resume(prior_cache, corpus, output):
    cache = output / "cache"
    cache.mkdir(parents=True, exist_ok=True)
    observations = {
        row["id"]: row
        for row in progress(prior_cache).values()
        if row.get("fetch_status") == "fetched"
    }
    reused = 0
    for path in sorted(prior_cache.glob("*.html.gz")):
        metadata = path.with_name(path.name.removesuffix(".html.gz") + ".json")
        recorded = (
            json.loads(metadata.read_text(encoding="utf-8"))
            if metadata.exists()
            else observations.get(path.name.removesuffix(".html.gz"))
        )
        if recorded is None:
            continue
        raw = gzip.decompress(path.read_bytes())
        if hashlib.sha256(raw).hexdigest() != recorded["raw_sha256"]:
            raise ValueError("historical_cache_hash_mismatch:" + path.name)
        target = cache / path.name
        if not target.exists():
            shutil.copyfile(path, target)
        target_metadata = cache / metadata.name
        if not target_metadata.exists():
            target_metadata.write_text(
                json.dumps(
                    {
                        k: recorded[k]
                        for k in (
                            "status",
                            "final_url",
                            "content_type",
                            "last_modified_header",
                            "etag",
                            "redirects",
                            "retrieved_at",
                            "raw_sha256",
                        )
                        if k in recorded
                    }
                ),
                encoding="utf-8",
            )
        reused += 1
    (output / "resume-receipt.json").write_text(
        json.dumps(
            {"immutable_prior_cache": str(prior_cache), "reused_captures": reused},
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    sources = read_jsonl(corpus / "sources.jsonl.gz")
    collector = GuardedCollector(cache, 2, 10000, retry_failures=True)
    collector.run(None, output / "capture.jsonl.gz", [s["url"] for s in sources])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prior-cache", type=Path, required=True)
    parser.add_argument("--corpus", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    resume(args.prior_cache, args.corpus, args.output)
