import hashlib
import json
import unittest
from pathlib import Path

from tools.editorial_reference_capture import extract_references, safe_url
from tools.plan3_content.dataset import read_jsonl


class OriginalReferenceTests(unittest.TestCase):
    def test_preserves_original_fragment_and_rejects_unsafe_schemes(self):
        self.assertEqual(
            safe_url("/law#exception", "https://example.org"),
            "https://example.org/law#exception",
        )
        for value in [
            "javascript:alert(1)",
            "file:///private",
            "https://user:pass@example.org/",
            "https://example.org:1234/",
        ]:
            with self.assertRaises(ValueError):
                safe_url(value, "https://example.org")

    def test_h1_owned_region_excludes_sidebar_and_retains_original_href(self):
        raw = b'<div class="Box"><h1>Title</h1><div class="BoxCenter"><p>Text <a href="/law#exception">Law</a></p></div></div><div class="Box"><div class="BoxCenter"><a href="/sidebar">Sidebar</a></div></div>'
        source = dict(
            parser_selector=".BoxSizeAsli .Box > .BoxCenter",
            url="https://example.org/article",
            source_id="source",
            snapshot_id="snapshot",
            body_sha256="a" * 64,
            raw_html_sha256="b" * 64,
            body_links=[dict(url="https://example.org/law", label="Law")],
            blocks=[dict(text="Text Law")],
        )
        result = extract_references(raw, source)
        self.assertEqual(len(result["links"]), 1)
        self.assertEqual(result["links"][0]["original_href"], "/law#exception")
        self.assertEqual(result["links"][0]["url"], "https://example.org/law#exception")
        self.assertIsNone(result["links"][0]["target_block_id"])
        self.assertEqual(result["links"][0]["verification_state"], "unverified")

    def test_sealed_maps_cover_every_locale_and_only_actual_source_snapshots(self):
        root = Path("artifacts/RAD_CONTENT_REFERENCE_CAPTURE_20261026")
        manifest = json.loads((root / "manifest.json").read_text(encoding="utf8"))
        for name, digest in manifest["files"].items():
            self.assertEqual(
                hashlib.sha256((root / name).read_bytes()).hexdigest(), digest
            )
        sources = {
            r["snapshot_id"]: r for r in read_jsonl(root / "source_references.jsonl.gz")
        }
        maps = read_jsonl(root / "article_reference_maps.jsonl.gz")
        self.assertEqual(len(sources), 1061)
        self.assertEqual(len(maps), 743)
        self.assertEqual(len({(r["article_id"], r["locale"]) for r in maps}), 743)
        links = []
        for row in maps:
            capture = row["map"]
            snapshots = {r["snapshot_id"] for r in capture["sources"]}
            for source in capture["sources"]:
                self.assertEqual(
                    source["body_sha256"], sources[source["snapshot_id"]]["body_sha256"]
                )
                self.assertEqual(
                    source["raw_html_sha256"],
                    sources[source["snapshot_id"]]["raw_html_sha256"],
                )
            for link in capture["links"]:
                self.assertIn(link["source_snapshot_id"], snapshots)
                self.assertEqual(link["verification_state"], "unverified")
                links.append(link)
        # One original link can contribute to more than one destination locale.
        self.assertEqual(
            sum(len(s["links"]) for s in sources.values()), manifest["original_links"]
        )
        self.assertEqual(len(links), 2449)
        for link in links:
            self.assertIn(link, sources[link["source_snapshot_id"]]["links"])


if __name__ == "__main__":
    unittest.main()
