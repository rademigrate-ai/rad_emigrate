"""Local acceptance credentials must not use inherited Windows proxy settings."""

import unittest
import urllib.request
from unittest.mock import MagicMock, patch

from scripts import verify_self_host_otp_sessions as otp
from scripts import verify_self_host_password_recovery as recovery
from scripts import verify_self_host_storage_gates as storage


class LocalTransportTests(unittest.TestCase):
    def test_all_acceptance_clients_explicitly_disable_proxies(self):
        for invoke in [
            lambda: storage.call("http://127.0.0.1:58600/test"),
            lambda: recovery.request("http://127.0.0.1:58600/test"),
            lambda: otp.call("http://127.0.0.1:58600/test"),
        ]:
            response = MagicMock()
            response.status = 200
            response.read.return_value = b"{}"
            response.headers = {}
            response.__enter__.return_value = response
            opener = MagicMock()
            opener.open.return_value = response
            with (
                patch("urllib.request.build_opener", return_value=opener) as build,
                patch("urllib.request.urlopen", return_value=response),
            ):
                invoke()
            handlers = build.call_args.args if build.call_args else ()
            self.assertTrue(
                any(
                    isinstance(h, urllib.request.ProxyHandler) and h.proxies == {}
                    for h in handlers
                ),
                "owned loopback transport must explicitly disable proxies",
            )
