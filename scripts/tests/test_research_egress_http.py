"""Raw loopback HTTP authentication tests; source DNS/network is forbidden."""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import time
import unittest
from pathlib import Path

TOKEN = "synthetic-local-http-token-0000000000000000"


class ResearchEgressHttpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            cls.port = reservation.getsockname()[1]
        environment = dict(
            os.environ,
            RAD_RESEARCH_EGRESS_TOKEN=TOKEN,
            RAD_RESEARCH_EGRESS_HOSTS="approved.example.invalid",
            RAD_RESEARCH_EGRESS_PORT=str(cls.port),
        )
        launcher = """import sys
from scripts import research_egress as gateway
def forbid_source_network(*args, **kwargs):
    print('UNEXPECTED_SOURCE_NETWORK', file=sys.stderr, flush=True)
    raise AssertionError('source network forbidden')
gateway.public_addresses = forbid_source_network
gateway.serve()
"""
        cls.process = subprocess.Popen(
            [sys.executable, "-c", launcher],
            cwd=Path(__file__).resolve().parents[2],
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        for _ in range(100):
            if cls.process.poll() is not None:
                raise AssertionError("Loopback gateway failed to start")
            try:
                with socket.create_connection(("127.0.0.1", cls.port), timeout=0.2):
                    return
            except OSError:
                time.sleep(0.05)
        cls.process.terminate()
        cls.process.wait(timeout=5)
        raise AssertionError("Loopback gateway startup timed out")

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        _, errors = cls.process.communicate(timeout=5)
        if errors:
            raise AssertionError(
                "Gateway emitted an exception or attempted source network: "
                + errors.decode("utf-8", "replace")
            )

    def request(self, authorization: bytes | None):
        body = b'{"url":"https://127.0.0.1/private"}'
        header = (
            b""
            if authorization is None
            else b"Authorization: " + authorization + b"\r\n"
        )
        wire = (
            b"POST /fetch HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n"
            + header
            + b"Content-Length: "
            + str(len(body)).encode("ascii")
            + b"\r\n\r\n"
            + body
        )
        with socket.create_connection(
            ("127.0.0.1", self.port), timeout=2
        ) as connection:
            connection.sendall(wire)
            chunks = []
            while True:
                part = connection.recv(65536)
                if not part:
                    break
                chunks.append(part)
        response = b"".join(chunks)
        self.assertTrue(
            response, "Gateway must reject malformed credentials with an HTTP response"
        )
        self.assertNotIn(TOKEN.encode("ascii"), response)
        return response.split(b"\r\n", 1)[0]

    def test_missing_and_wrong_credentials_are_forbidden(self):
        self.assertEqual(self.request(None), b"HTTP/1.0 403 Forbidden")
        self.assertEqual(
            self.request(b"Bearer wrong-synthetic-token"), b"HTTP/1.0 403 Forbidden"
        )

    def test_nonascii_and_oversized_credentials_are_forbidden(self):
        self.assertEqual(self.request(b"Bearer \xff"), b"HTTP/1.0 403 Forbidden")
        self.assertEqual(
            self.request(b"Bearer " + b"x" * 6000), b"HTTP/1.0 403 Forbidden"
        )

    def test_valid_token_still_requires_safe_allowlisted_source(self):
        self.assertEqual(
            self.request(b"Bearer " + TOKEN.encode("ascii")),
            b"HTTP/1.0 422 Unprocessable Entity",
        )


if __name__ == "__main__":
    unittest.main()
