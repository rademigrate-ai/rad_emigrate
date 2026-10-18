"""Review-plan target binding and non-disclosure; no cloud commands or credentials."""
import importlib.util
import json
from pathlib import Path
import sys
import unittest

SCRIPTS=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(SCRIPTS))
spec=importlib.util.spec_from_file_location('prepare_staging',SCRIPTS/'prepare_staging.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PrepareStagingTests(unittest.TestCase):
    def values(self):
        return {'APP_ENV':'staging','RAD_STAGING_PROJECT_REF':'s'*20,
            'SUPABASE_URL':'https://'+'s'*20+'.supabase.co','RAD_STAGING_SITE_URL':'https://staging.example.com',
            'RAD_STAGING_DB_URL':'postgresql://postgres:TEST_ONLY_PASSWORD@db.'+'s'*20+'.supabase.co:5432/postgres?sslmode=require'}

    def test_plan_binds_commands_and_omits_private_values(self):
        plan=module.prepare_plan(self.values(),'a'*40,[{'path':'synthetic.sql','sha256':'b'*64}],['payment-sandbox','document-intelligence'])
        encoded=json.dumps(plan)
        self.assertNotIn('TEST_ONLY_PASSWORD',encoded)
        self.assertNotIn('postgresql://',encoded)
        self.assertFalse(plan['external_commands_executed'])
        self.assertEqual(plan['excluded_local_only_functions'],['payment-sandbox'])
        deploy=plan['commands_for_owner_review'][-1]['argv']
        self.assertEqual(deploy[-2:],['--project-ref','s'*20])
        self.assertIn('explicit_staging_deployment_authorization',plan['blocked_by_owner'])

    def test_owner_dependencies_are_honest_and_revision_is_required(self):
        values=self.values()
        values.pop('RAD_STAGING_DB_URL')
        plan=module.prepare_plan(values,'a'*40,[],[])
        self.assertIn('staging_database_connection',plan['blocked_by_owner'])
        self.assertIn('verified_staging_backup_and_restore_record',plan['blocked_by_owner'])
        with self.assertRaises(module.StagingConfigError): module.prepare_plan(values,'main',[],[])

    def test_production_plan_cannot_be_generated(self):
        values=self.values()
        values['RAD_STAGING_PROJECT_REF']='inshddthftkhcdosoqcn'
        with self.assertRaises(module.StagingConfigError): module.prepare_plan(values,'a'*40,[],[])


if __name__=='__main__': unittest.main()
