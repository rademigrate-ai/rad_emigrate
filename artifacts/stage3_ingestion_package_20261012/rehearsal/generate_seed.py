#!/usr/bin/env python3
"""Generate 02_seed_production.sql from LIVE_STATE_SNAPSHOT.json.

The rehearsal starts from production's EXACT current state (5 documents,
5 snapshots, 6 content sources) so ON CONFLICT behavior is tested against the
real pre-existing rows, not an empty database.
"""
import json
import pathlib
import sys


def q(s):
    if s is None:
        return "null"
    return "'" + str(s).replace("'", "''") + "'"


def main():
    pkg = pathlib.Path(__file__).resolve().parent.parent
    live = json.loads((pkg / "LIVE_STATE_SNAPSHOT.json").read_text(encoding="utf-8"))
    lines = ["-- Seed: exact captured production state (pre-ingest baseline)\nbegin;"]
    for s in live["content_sources"]:
        lines.append(
            "insert into public.content_sources (id, publisher, source_type, title, url, language_code, is_active)"
            " values (%s, %s, %s, %s, %s, 'fa', %s) on conflict (id) do nothing;"
            % (q(s["id"]), q(s["publisher"]), q(s["source_type"]),
               q(s.get("title") or s["publisher"]), q(s["url"]),
               "true" if s.get("is_active", True) else "false"))
    for d in live["source_documents"]:
        lines.append(
            "insert into public.source_documents (id, canonical_url, source_id, source_authority, title, language_code, jurisdiction, last_content_hash)"
            " values (%s, %s, %s, %s, %s, %s, %s, %s) on conflict (id) do nothing;"
            % (q(d["id"]), q(d["canonical_url"]), q(d.get("source_id")),
               q(d["source_authority"]), q(d["title"]), q(d["language_code"]),
               q(d.get("jurisdiction")), q(d.get("last_content_hash"))))
    for s in live["source_snapshots"]:
        lines.append(
            "insert into public.source_snapshots (id, document_id, content_hash, normalized_text, http_status)"
            " values (%s, %s, %s, 'seed baseline text', %s) on conflict (id) do nothing;"
            % (q(s["id"]), q(s["document_id"]), q(s["content_hash"]),
               q(s.get("http_status"))))
    lines.append("commit;")
    (pkg / "rehearsal" / "02_seed_production.sql").write_text(
        "\n".join(lines) + "\n", encoding="utf-8")
    print("seed lines:", len(lines) - 3)
    return 0


if __name__ == "__main__":
    sys.exit(main())
