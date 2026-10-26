"""Independent structural fidelity and destination-scope validation."""

import argparse
import hashlib
import json
from pathlib import Path

from tools.plan3_content.dataset import read_jsonl
from tools.plan3_content.parser import digest


def verify(directory):
    manifest = json.loads((directory / "manifest.json").read_text(encoding="utf8"))
    for name, expected in manifest["files"].items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != expected:
            raise ValueError("file_checksum_mismatch:" + name)
    sources = {s["source_id"]: s for s in read_jsonl(directory / "sources.jsonl.gz")}
    articles = read_jsonl(directory / "articles.jsonl.gz")
    identities = set()
    covered = set()
    block_count = 0
    duplicates = 0
    for a in articles:
        identity = (a["article_id"], a["locale"])
        assert identity not in identities, "duplicate_article_locale"
        identities.add(identity)
        assert (
            not a["published"]
            and not a["publication_allowed"]
            and a["reviewer_id"] is None
        )
        actual_domains = {sources[s]["domain"] for s in a["source_ids"]}
        assert actual_domains == set(a["source_publishers"])
        if a["content_class"] == "canonical":
            assert actual_domains <= {"radvisa.com", "digivisa.ir"}
            assert len(a["country_codes"]) == 1 and a["visa_category"]
            assert all(
                sources[s]["taxonomy"]["country_codes"] == a["country_codes"]
                for s in a["source_ids"]
            )
        if "radmohajer.ir" in actual_domains:
            assert (
                actual_domains == {"radmohajer.ir"}
                and a["content_class"] == "editorial"
            )
        representatives = {}
        for section in a["sections"]:
            for b in section["blocks"]:
                assert b["id"] not in representatives
                representatives[b["id"]] = b
                block_count += 1
                original = b["original_structure"]
                assert original["text"] == b["text"]
                for ref in b["provenance"]:
                    s = sources[ref["source_id"]]
                    raw = s["blocks"][ref["block_index"]]
                    assert raw == original, "structure_or_text_changed"
                    assert ref["snapshot_id"] == s["snapshot_id"]
                    assert digest(raw) == ref["structure_sha256"]
                    assert s["body_text"][ref["start"] : ref["end"]] == original["text"]
                    assert digest(original["text"]) == ref["sha256"]
                    covered.add((s["source_id"], ref["block_index"]))
        for removed in a["omissions"]:
            assert removed["reason"] == "exact_structure_and_text_repetition"
            ref = removed["provenance"]
            assert (
                sources[ref["source_id"]]["blocks"][ref["block_index"]]
                == representatives[removed["represented_block_id"]][
                    "original_structure"
                ]
            )
            duplicates += 1
        for row in a["segment_ledger"]:
            target = representatives[row["represented_block_id"]]
            assert any(
                ref["source_id"] == row["source_id"]
                and ref["block_index"] == row["block_index"]
                for ref in target["provenance"]
            )
    expected = set()
    for s in sources.values():
        if s["consolidation_disposition"] == "body_ready_for_unreviewed_composition":
            assert digest(s["body_text"]) == s["body_sha256"]
            assert "\n\n".join(b["text"] for b in s["blocks"]) == s["body_text"]
            expected.update((s["source_id"], i) for i in range(len(s["blocks"])))
    assert covered == expected, "missing_or_extra_source_segments"
    assert not read_jsonl(directory / "unaccounted_segments.jsonl.gz")
    relations = read_jsonl(directory / "relations.jsonl.gz")
    by_id = {a["article_id"]: a for a in articles}
    seen = set()
    for r in relations:
        pair = (r["parent_id"], r["related_id"])
        # A shared article identity can have separate locale proposals, but the
        # stored relation itself must remain unique across those localizations.
        assert pair not in seen, "duplicate_relation_identity"
        seen.add(pair)
        p, c = by_id[pair[0]], by_id[pair[1]]
        assert p["content_class"] == "canonical" and c["content_class"] == "editorial"
        assert set(p["country_codes"]) & set(c["country_codes"])
        assert r["state"] == "proposed" and r["reviewer_id"] is None
    return {
        "status": "PASS",
        "url_dispositions": len(sources),
        "article_locales": len(articles),
        "article_identities": len({a["article_id"] for a in articles}),
        "source_segments_accounted": len(covered),
        "preserved_destination_blocks": block_count,
        "exact_duplicate_representations": duplicates,
        "unaccounted_segments": 0,
        "human_approved_articles": 0,
        "verified_legal_claims": 0,
        "publication_ready": 0,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.directory), ensure_ascii=False))
