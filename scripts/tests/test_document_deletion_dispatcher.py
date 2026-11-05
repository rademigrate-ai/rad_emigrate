"""Dispatcher never confuses an accepted request with completed destruction."""

import unittest

from scripts.document_deletion_dispatcher import dispatch


def health(exhausted=0):
    return {
        "pending": 1,
        "exhausted": exhausted,
        "leased": 0,
        "oldest_pending_seconds": 2,
    }


class DispatcherTests(unittest.TestCase):
    def test_report_only_is_the_default(self):
        calls = []

        def call(path):
            calls.append(path)
            return 200, health()

        result = dispatch(call)
        self.assertEqual(result["mode"], "REPORT_ONLY")
        self.assertEqual(calls, ["/rest/v1/rpc/document_deletion_queue_health"])

    def test_worker_execution_is_bounded_and_stops_at_empty_queue(self):
        responses = iter(
            [
                (200, health()),
                (200, {"processed": 1, "state": "finalized"}),
                (200, {"processed": 0, "reason": "queue_empty"}),
                (200, health()),
            ]
        )
        waits = []
        result = dispatch(
            lambda _: next(responses), execute=True, max_jobs=3, sleep=waits.append
        )
        self.assertEqual(result["finalized"], 1)
        self.assertEqual(result["worker_calls"], 2)
        self.assertEqual(len(waits), 1)

    def test_server_errors_and_malformed_successes_never_count_as_finalized(self):
        for response in [
            (502, {"error": "secret private path"}),
            (200, {"processed": 1, "state": "pending_storage"}),
        ]:
            responses = iter([(200, health()), response, (200, health())])
            result = dispatch(
                lambda _, responses=responses: next(responses), execute=True, max_jobs=1
            )
            self.assertEqual(result["finalized"], 0)
            self.assertFalse(result["healthy"])
            self.assertNotIn("secret", str(result))

    def test_exhausted_retries_emit_an_alert(self):
        result = dispatch(lambda _: (200, health(exhausted=1)))
        self.assertFalse(result["healthy"])
        self.assertIn("retries_exhausted", result["alerts"])

    def test_network_failure_is_observable_without_exception_details(self):
        def call(_):
            raise OSError("sensitive-url?token=secret")

        result = dispatch(call, execute=True)
        self.assertFalse(result["healthy"])
        self.assertEqual(result["worker_calls"], 0)
        self.assertNotIn("secret", str(result))

    def test_bounds_are_validated_before_network_or_sleep(self):
        for values in [{"max_jobs": 0}, {"max_jobs": 101}, {"interval": 0}]:
            with self.assertRaises(ValueError):
                dispatch(lambda _: self.fail("network invoked"), **values)
