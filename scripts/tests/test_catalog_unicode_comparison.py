"""Catalog comparison must preserve Unicode without excusing actual SQL changes."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]


class CatalogUnicodeComparison(unittest.TestCase):
    def compare(self, mutate=False):
        expected=json.loads((ROOT/'supabase/reconciliation/production_catalog.json').read_text(encoding='utf-8'))
        target=next(row for row in expected['functions'] if row['proname']=='redact_safe_metadata')
        self.assertIn('\u2026',target['definition'])
        if mutate:
            target['definition']=target['definition'].replace('\u2026','...')
        with tempfile.TemporaryDirectory(prefix='rad-catalog-unicode-') as temp:
            actual=Path(temp)/'catalog.json'
            # Escaped and literal UTF-8 JSON must describe the same SQL text.
            actual.write_text(json.dumps(expected,ensure_ascii=True),encoding='utf-8')
            result=subprocess.run([sys.executable,str(ROOT/'scripts/compare_reconciliation_catalog.py'),str(actual)],
                                  cwd=temp,capture_output=True,text=True,encoding='utf-8')
            report=json.loads((Path(temp)/'reconciliation-report.json').read_text(encoding='utf-8'))
            return result.returncode,report

    def test_escaped_and_literal_unicode_catalogs_are_equivalent(self):
        code,report=self.compare()
        self.assertEqual(code,0)
        self.assertEqual(report['functions']['status'],'MATCH')

    def test_real_unicode_sql_change_remains_security_relevant_drift(self):
        code,report=self.compare(True)
        self.assertEqual(code,1)
        self.assertEqual(report['functions']['status'],'SECURITY-RELEVANT DRIFT')


if __name__=='__main__':unittest.main()
