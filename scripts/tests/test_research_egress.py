"""No-network security tests for the protected research transport."""

import unittest
from unittest.mock import patch

from scripts.research_egress import (
    EgressError,
    PinnedHTTPSConnection,
    ProtectedFetcher,
    public_addresses,
)


class ProtectedEgressTests(unittest.TestCase):
    def test_connection_pins_socket_and_checks_original_tls_hostname(self):
        with (
            patch("scripts.research_egress.socket.socket") as socket_type,
            patch("scripts.research_egress.ssl.create_default_context") as context,
        ):
            connection = PinnedHTTPSConnection("example.org", "8.8.8.8")
            connection.connect()
            socket_type.return_value.connect.assert_called_once_with(("8.8.8.8", 443))
            context.return_value.wrap_socket.assert_called_once_with(
                socket_type.return_value,
                server_hostname="example.org",
                do_handshake_on_connect=False,
            )
            context.return_value.wrap_socket.return_value.do_handshake.assert_called_once()

    def test_expiration_during_tls_closes_socket_and_cannot_complete_late(self):
        with (
            patch("scripts.research_egress.socket.socket"),
            patch("scripts.research_egress.ssl.create_default_context") as context,
        ):
            connection = PinnedHTTPSConnection("example.org", "8.8.8.8")
            wrapped = context.return_value.wrap_socket.return_value
            wrapped.do_handshake.side_effect = connection.abort
            with self.assertRaises(EgressError):
                connection.connect()
            wrapped.close.assert_called()

    def test_rejects_every_nonpublic_dns_answer_including_mixed_answers(self):
        for address in [
            "127.0.0.1",
            "10.0.0.1",
            "169.254.169.254",
            "100.64.0.1",
            "192.0.2.1",
            "::1",
            "fc00::1",
            "::ffff:127.0.0.1",
        ]:
            with self.subTest(address=address):
                with patch(
                    "scripts.research_egress.socket.getaddrinfo",
                    return_value=[
                        (2, 1, 6, "", ("8.8.8.8", 443)),
                        (2, 1, 6, "", (address, 443)),
                    ],
                ):
                    with self.assertRaises(EgressError):
                        public_addresses("example.org")

    def test_exact_https_allowlist_before_dns_or_network(self):
        fetcher = ProtectedFetcher({"example.org"})
        for url in [
            "http://example.org/a",
            "https://example.org.evil/a",
            "https://u:p@example.org/a",
            "https://example.org:8443/a",
            "https://127.0.0.1/a",
            "https://example.org./a",
        ]:
            with (
                self.subTest(url=url),
                patch("scripts.research_egress.public_addresses") as resolve,
            ):
                with self.assertRaises(EgressError):
                    fetcher.fetch(url)
                resolve.assert_not_called()

    def test_robots_denial_does_not_fetch_source(self):
        calls = []

        def request(url, **_):
            calls.append(url)
            return (
                200,
                {"content-type": "text/plain"},
                b"User-agent: *\nDisallow: /private\n",
            )

        fetcher = ProtectedFetcher({"example.org"}, request=request, minimum_interval=0)
        with self.assertRaisesRegex(EgressError, "robots_disallowed"):
            fetcher.fetch("https://example.org/private/article")
        self.assertEqual(calls, ["https://example.org/robots.txt"])

    def test_unknown_robots_fail_closed_and_404_allows(self):
        for status in [401, 403, 429, 500, 302]:
            fetcher = ProtectedFetcher(
                {"example.org"},
                request=lambda *a, status=status, **k: (status, {}, b""),
                minimum_interval=0,
            )
            with self.subTest(status=status), self.assertRaises(EgressError):
                fetcher.fetch("https://example.org/article")
        calls = []

        def request(url, **_):
            calls.append(url)
            return (
                (404, {}, b"")
                if url.endswith("robots.txt")
                else (200, {"content-type": "text/html"}, b"complete article")
            )

        fetcher = ProtectedFetcher({"example.org"}, request=request, minimum_interval=0)
        self.assertEqual(
            fetcher.fetch("https://example.org/article")[2], b"complete article"
        )
        self.assertEqual(len(calls), 2)

    def test_complete_bytes_preserved_and_oversized_body_rejected(self):
        body = ("متن کامل" * 100).encode()

        def request(url, **_):
            return (
                (404, {}, b"")
                if url.endswith("robots.txt")
                else (200, {"content-type": "text/html"}, body)
            )

        fetcher = ProtectedFetcher({"example.org"}, request=request, minimum_interval=0)
        self.assertEqual(fetcher.fetch("https://example.org/article")[2], body)
        fetcher = ProtectedFetcher(
            {"example.org"}, request=request, max_bytes=20, minimum_interval=0
        )
        with self.assertRaisesRegex(EgressError, "source_too_large"):
            fetcher.fetch("https://example.org/article")

    def test_redirect_is_returned_for_caller_revalidation_never_followed(self):
        calls = []

        def request(url, **_):
            calls.append(url)
            return (
                (404, {}, b"")
                if url.endswith("robots.txt")
                else (302, {"location": "https://10.0.0.1/private"}, b"")
            )

        fetcher = ProtectedFetcher({"example.org"}, request=request, minimum_interval=0)
        self.assertEqual(fetcher.fetch("https://example.org/article")[0], 302)
        self.assertEqual(len(calls), 2)

    def test_pdf_and_unknown_binary_require_separate_reviewed_extractor(self):
        def request(url, **_):
            return (
                (404, {}, b"")
                if url.endswith("robots.txt")
                else (200, {"content-type": "application/pdf"}, b"%PDF")
            )

        with self.assertRaisesRegex(EgressError, "unsupported_source_type"):
            ProtectedFetcher(
                {"example.org"}, request=request, minimum_interval=0
            ).fetch("https://example.org/file")


if __name__ == "__main__":
    unittest.main()
