import unittest

from scripts.self_host_stack import gateway_log_privacy, storage_response_privacy


class StorageGatewayPrivacy(unittest.TestCase):
    def test_access_log_keeps_status_without_private_request_fields(self):
        original = '                        inline_string: "%DOWNSTREAM_REMOTE_ADDRESS_WITHOUT_PORT% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %REQ(REFERER)%\\n"\n'
        result = gateway_log_privacy(original)
        self.assertNotIn("PATH", result)
        self.assertNotIn("REFERER", result)
        self.assertIn("%RESPONSE_CODE%", result)
        self.assertIn("%DURATION%", result)
        self.assertEqual(gateway_log_privacy(result), result)
        # The official template also contains a non-log inline secret matcher.
        with_auth = (
            result + "                      inline_string: '${DASHBOARD_BASIC_AUTH}'\n"
        )
        self.assertEqual(gateway_log_privacy(with_auth), with_auth)
        for unknown in ("unexpected format", original + original):
            with self.assertRaises(ValueError):
                gateway_log_privacy(unknown)

    def setUp(self):
        self.route = (
            "                      - match:\n"
            "                          prefix: /storage/v1/\n"
            "                        route:\n"
            "                          cluster: storage\n"
            "                          prefix_rewrite: /\n"
            "                        typed_per_filter_config: AUTH_UNCHANGED\n"
        )

    def test_no_store_preserves_routing_and_authorization_and_is_idempotent(self):
        result = storage_response_privacy(self.route)
        self.assertIn("value: private, no-store, max-age=0", result)
        self.assertIn("append_action: OVERWRITE_IF_EXISTS_OR_ADD", result)
        self.assertIn("cluster: storage\n", result)
        self.assertIn("prefix_rewrite: /\n", result)
        self.assertIn("typed_per_filter_config: AUTH_UNCHANGED\n", result)
        self.assertEqual(storage_response_privacy(result), result)

    def test_unknown_or_ambiguous_upstream_route_fails_closed(self):
        for source in ("no storage route", self.route + self.route):
            with self.subTest(source=source), self.assertRaises(ValueError):
                storage_response_privacy(source)
