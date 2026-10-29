import unittest

from tools.content_completion.compare_staging import quote


class StagingComparisonTests(unittest.TestCase):
    def test_quote_keeps_embedded_source_apostrophe_inside_sql_literal(self):
        self.assertEqual(quote("a'b"), "'a''b'")


if __name__ == "__main__":
    unittest.main()
