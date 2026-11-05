import unittest

from scripts.self_host_stack import storage_response_privacy


class StorageGatewayPrivacy(unittest.TestCase):
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
