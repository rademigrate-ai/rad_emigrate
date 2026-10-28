"""Linear source/canonical/draft graph checks, independent of manifest counts."""

from .dataset import digest, uid


def verify_graph(sources, canonical, drafts, identities):
    by_source = {s["source_id"]: s for s in sources}
    by_draft = {a["canonical_id"]: a for a in drafts}
    if len(by_source) != len(sources) or len(by_draft) != len(drafts):
        raise ValueError("duplicate_graph_identity")
    ids = [c["canonical_id"] for c in canonical]
    if len(set(ids)) != len(ids) or set(ids) != set(by_draft):
        raise ValueError("canonical_draft_identity_graph")
    for s in sources:
        body = s["body_text"]
        if body and (
            digest(body) != s["body_sha256"]
            or body != "\n\n".join(b["text"] for b in s["blocks"])
            or s["snapshot_id"]
            != uid("snapshot:" + s["source_id"] + ":" + s["body_sha256"])
        ):
            raise ValueError("source_body_graph")
    assigned = set()
    for c in canonical:
        members = c["source_ids"]
        if len(set(members)) != len(members) or assigned.intersection(members):
            raise ValueError("source_assigned_more_than_once")
        assigned.update(members)
        s = by_source[c["primary_source_id"]]
        expected_manifests = [
            {
                k: by_source[i][k]
                for k in (
                    "source_id",
                    "url",
                    "snapshot_id",
                    "body_sha256",
                    "retrieved_at",
                )
            }
            for i in members
        ]
        if (
            s["source_id"] not in members
            or c["source_manifests"] != expected_manifests
            or c["source_urls"] != sorted(by_source[i]["url"] for i in members)
            or c["body_text"] != s["body_text"]
            or c["structured_blocks"] != s["blocks"]
            or c["body_sha256"] != s["body_sha256"]
            or c["content_version_hash"]
            != by_draft[c["canonical_id"]]["payload_sha256"]
            or c["change_diff_inputs"]["block_hashes"]
            != [digest(b) for b in s["blocks"]]
            or any(
                identities.get(i) != c["canonical_id"]
                or by_source[i]["canonical_group"] != c["canonical_id"]
                for i in members
            )
        ):
            raise ValueError("canonical_provenance_graph")
    if assigned != {s["source_id"] for s in sources if s["complete_article_body"]}:
        raise ValueError("complete_body_partition_graph")
    return {
        "source_records": len(sources),
        "complete_bodies_traced": len(assigned),
        "canonical_drafts_traced": len(canonical),
    }
