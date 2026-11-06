import unittest

from tools.content_completion.coverage_join_v4 import join_evidence


class CoverageEvidenceBoundaries(unittest.TestCase):
    def fixture(self):
        block = {"type": "paragraph", "text": "Original source passage."}
        source = {
            "source_id": "source",
            "snapshot_id": "snapshot",
            "url": "https://digivisa.ir/article/a",
            "raw_html_sha256": "raw",
            "body_sha256": "body",
            "blocks": [block],
        }
        article = {
            "article_id": "article",
            "locale": "en",
            "content_class": "editorial",
            "source_urls": [source["url"]],
            "segment_ledger": [
                {
                    "source_id": "source",
                    "snapshot_id": "snapshot",
                    "block_index": 0,
                    "represented_block_id": "block",
                    "status": "preserved",
                }
            ],
        }
        db = {
            "article_id": "article",
            "locale": "en",
            "revision_id": "revision",
            "revision_exists": True,
            "rich_sections_match": True,
            "reader_sections_match": True,
            "source_references_valid": True,
            "composition_payload_match": True,
            "placement_matches": True,
        }
        ui = {
            "article_id": "article",
            "locale": "en",
            "revision_id": "revision",
            "route_opened": True,
            "body_render_verified": True,
            "full_api_structure_verified": True,
            "console_errors": [],
            "render_probe": "first_and_final_retained_block",
        }
        return [source], [article], [db], [ui]

    def test_database_row_never_counts_as_rendered_transfer(self):
        sources, articles, db, _ = self.fixture()
        report, _ = join_evidence([], sources, articles, db, [])
        self.assertEqual(report["fully_verified_source_url_transfers"], 0)
        self.assertEqual(report["source_segments_without_render_verification"], 1)
        self.assertEqual(report["status"], "FAIL")

    def test_render_of_an_old_revision_cannot_certify_current_head(self):
        sources, articles, db, ui = self.fixture()
        ui[0]["revision_id"] = "older-revision"
        report, _ = join_evidence([], sources, articles, db, ui)
        self.assertEqual(report["recovered_corpus_status"], "FAIL")

    def test_full_rpc_comparison_is_required_alongside_visible_probe(self):
        sources, articles, db, ui = self.fixture()
        ui[0]["full_api_structure_verified"] = False
        report, _ = join_evidence([], sources, articles, db, ui)
        self.assertEqual(report["fully_verified_source_url_transfers"], 0)

    def test_unresolved_discovery_prevents_global_completion(self):
        sources, articles, db, ui = self.fixture()
        report, lineage = join_evidence(
            [{"disposition": "SOURCE_UNRESOLVED"}], sources, articles, db, ui
        )
        self.assertEqual(report["recovered_corpus_status"], "PASS")
        self.assertEqual(report["status"], "FAIL")
        self.assertEqual(report["unrecoverable_claims"], 0)
        self.assertEqual(len(lineage[0]["original_blocks"][0]["structure_sha256"]), 64)

    def test_empty_inputs_cannot_certify_complete_migration(self):
        report, _ = join_evidence([], [], [], [], [])
        self.assertEqual(report["status"], "FAIL")
        self.assertIn("empty_inventory_sources_or_composition", report["errors"])

    def test_conflicting_receipts_cannot_be_silently_overwritten(self):
        sources, articles, db, ui = self.fixture()
        report, _ = join_evidence(
            [{"disposition": "CONTENT_CAPTURED", "url": sources[0]["url"]}],
            sources,
            articles,
            db + [{**db[0], "revision_exists": False}],
            ui,
        )
        self.assertEqual(report["recovered_corpus_status"], "FAIL")
        self.assertIn("duplicate_database_or_render_receipts", report["errors"])

    def test_local_render_cannot_certify_hosted_staging(self):
        sources, articles, db, ui = self.fixture()
        db[0]["environment"] = "staging:epolbumcfbohtmgvomki"
        ui[0]["environment"] = "local:rad_full_content_v4_20261028"
        report, _ = join_evidence(
            [{"disposition": "CONTENT_CAPTURED", "url": sources[0]["url"]}],
            sources,
            articles,
            db,
            ui,
            "staging:epolbumcfbohtmgvomki",
        )
        self.assertEqual(report["fully_verified_source_url_transfers"], 0)
        self.assertIn("receipt_environment_missing_or_mismatched", report["errors"])

    def test_a_partially_transferred_page_is_not_counted_as_available(self):
        sources, articles, db, ui = self.fixture()
        sources[0]["blocks"].append(
            {"type": "paragraph", "text": "Unmapped unique fact."}
        )
        report, _ = join_evidence(
            [{"disposition": "CONTENT_CAPTURED", "url": sources[0]["url"]}],
            sources,
            articles,
            db,
            ui,
        )
        self.assertEqual(report["fully_verified_source_url_transfers"], 0)
        self.assertEqual(report["source_urls_available_in_other_titles"], 0)


if __name__ == "__main__":
    unittest.main()
