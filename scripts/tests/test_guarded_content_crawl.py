import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

from tools.content_completion.guarded_crawl import GuardedCollector


class GuardedCrawlTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.collector = GuardedCollector(Path(directory.name))

    @patch("tools.plan3_content.crawl.Collector.request")
    def test_three_disconnects_stop_future_requests_to_only_that_host(self, request):
        request.side_effect = [OSError("connection closed")] * 3 + [(b"ok", {})]
        for _ in range(3):
            with self.assertRaises(OSError):
                self.collector.request("https://radmohajer.ir/fa")
        with self.assertRaisesRegex(ValueError, "host_circuit_open"):
            self.collector.request("https://radmohajer.ir/fa/other")
        self.assertEqual(request.call_count, 3)
        self.collector.request("https://digivisa.ir/other")
        self.assertEqual(request.call_count, 4)

    @patch("tools.plan3_content.crawl.Collector.request")
    def test_access_denial_stops_immediately(self, request):
        request.side_effect = HTTPError(
            "https://digivisa.ir/a", 403, "Forbidden", {}, None
        )
        with self.assertRaises(HTTPError):
            self.collector.request("https://digivisa.ir/a")
        with self.assertRaisesRegex(ValueError, "host_circuit_open:http_403"):
            self.collector.request("https://digivisa.ir/b")
        self.assertEqual(request.call_count, 1)

    @patch("tools.plan3_content.crawl.Collector.request")
    def test_success_resets_disconnect_count(self, request):
        request.side_effect = [OSError("offline"), (b"ok", {}), OSError("offline")]
        with self.assertRaises(OSError):
            self.collector.request("https://digivisa.ir/a")
        self.collector.request("https://digivisa.ir/a")
        with self.assertRaises(OSError):
            self.collector.request("https://digivisa.ir/a")
        self.assertNotIn("digivisa.ir", self.collector.circuit)


if __name__ == "__main__":
    unittest.main()
