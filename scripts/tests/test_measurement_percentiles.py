import unittest

from scripts.measure_self_host_acceptance import percentile95


class MeasurementPercentiles(unittest.TestCase):
    def test_small_samples_use_the_nearest_rank_definition(self):
        self.assertEqual(percentile95([7]), 7)
        self.assertEqual(percentile95([100, 1, 2, 3, 4]), 100)
        self.assertEqual(percentile95(list(range(1, 21))), 19)
        with self.assertRaises(ValueError):
            percentile95([])
