"""Staging-target/credential boundary tests with synthetic configuration only."""
import base64
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1]/'staging_environment.py'
spec = importlib.util.spec_from_file_location('staging_environment', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def token(role='anon', project='s'*20):
    payload = base64.urlsafe_b64encode(json.dumps({'role':role,'ref':project}).encode()).decode().rstrip('=')
    return 'TEST_HEADER.'+payload+'.TEST_SIGNATURE'


def settings():
    # Synthetic names only; no request is made to either hostname.
    return {'APP_ENV':'staging','RAD_DEPLOYMENT_KIND':'staging','RAD_STAGING_PROJECT_REF':'s'*20,
        'SUPABASE_URL':'https://'+'s'*20+'.supabase.co',
        'RAD_STAGING_SITE_URL':'https://staging.example.com',
        'SUPABASE_PUBLISHABLE_KEY':'sb_publishable_'+'TESTONLY_PUBLIC_VALUE'}


class StagingEnvironmentTests(unittest.TestCase):
    def rejected(self, values, code=None):
        with self.assertRaises(module.StagingConfigError) as caught:
            module.validate_staging(values)
        if code:
            self.assertEqual(str(caught.exception), code)
        self.assertNotIn('TESTONLY_PUBLIC_VALUE', str(caught.exception))

    def test_explicit_public_settings_pass_with_owner_binding_limit(self):
        result = module.validate_staging(settings())
        self.assertEqual(result['status'],'PASS')
        self.assertIn('owner_verification_required',result['public_key_binding'])
        self.assertEqual(result['scope'],'configuration_only_no_network_or_deployment')

    def test_staging_label_cannot_select_production(self):
        values=settings()
        values.update(RAD_STAGING_PROJECT_REF=module.PRODUCTION_PROJECT,
            SUPABASE_URL='https://'+module.PRODUCTION_PROJECT+'.supabase.co')
        self.rejected(values,'production_project_forbidden')

    def test_production_url_cannot_hide_behind_staging_ref(self):
        self.rejected({**settings(),'SUPABASE_URL':'https://'+module.PRODUCTION_PROJECT+'.supabase.co'},'staging_api_target_mismatch')

    def test_intent_missing_malformed_or_production_fails(self):
        for change in [{'APP_ENV':''},{'APP_ENV':'production'},{'RAD_DEPLOYMENT_KIND':'production'},
                {'RAD_STAGING_PROJECT_REF':''},{'RAD_STAGING_PROJECT_REF':'your-project-ref'},
                {'RAD_STAGING_PROJECT_REF':'S'*20}]:
            with self.subTest(change=change): self.rejected({**settings(),**change})

    def test_api_canonical_origin_only(self):
        host='s'*20+'.supabase.co'
        for value in ['http://'+host,'https://other.supabase.co','https://'+host+':443',
                'https://'+host+':bad','https://user@'+host,'https://'+host+'/rest/v1',
                'https://'+host+'?target=prod','https://'+host+'#prod','https://'+host+'.',
                ' https://'+host,'https://'+host+'\n']:
            with self.subTest(value=value): self.rejected({**settings(),'SUPABASE_URL':value})

    def test_staging_site_is_separate_canonical_https_origin(self):
        for value in ['', 'https://rad-emigrate.onrender.com','https://rad-emigrate.onrender.com.',
                'http://staging.example.com','https://localhost','https://127.1','https://[::1]',
                'https://something.localhost','https://staging.example.invalid',
                'https://user@staging.example.com','https://staging.example.com/path',
                'https://staging.example.com?x=y','https://staging.example.com#hash']:
            with self.subTest(value=value): self.rejected({**settings(),'RAD_STAGING_SITE_URL':value})

    def test_legacy_claims_must_be_anon_for_same_project(self):
        values={**settings(),'SUPABASE_PUBLISHABLE_KEY':'','SUPABASE_ANON_KEY':token()}
        result=module.validate_staging(values)
        self.assertIn('signature_not_verified',result['public_key_binding'])
        for key in [token('service_role'),token('authenticated'),token(project=module.PRODUCTION_PROJECT),
                token(project='t'*20),'sb_secret_TEST_PRIVATE_CANARY','not-a-key','x.!@#.x']:
            with self.subTest(key_kind=key.split('.')[0]): self.rejected({**values,'SUPABASE_ANON_KEY':key})

    def test_dual_aliases_missing_and_malformed_keys_fail(self):
        for change in [{'SUPABASE_ANON_KEY':token()},{'SUPABASE_PUBLISHABLE_KEY':''},
                {'SUPABASE_PUBLISHABLE_KEY':'sb_publishable_short'},
                {'SUPABASE_PUBLISHABLE_KEY':'sb_secret_TEST_PRIVATE_CANARY'}]:
            with self.subTest(name=next(iter(change))): self.rejected({**settings(),**change})

    def test_private_credentials_cannot_be_in_public_build(self):
        for name in module.PRIVATE_BUILD_VARIABLES:
            with self.subTest(name=name):
                self.rejected({**settings(),name:'TEST_PRIVATE_CANARY'},'private_credentials_in_public_build_environment')

    def test_backend_plan_does_not_require_public_key_or_fabricate_connection(self):
        values=settings()
        values.pop('SUPABASE_PUBLISHABLE_KEY')
        result=module.validate_staging(values,public_build=False)
        self.assertIn('requires_owner_verification',result['public_key_binding'])
        self.assertFalse(result['database_connection_configured'])

    def test_backend_database_and_service_claims_bind_same_staging_project(self):
        values={**settings(),'RAD_STAGING_DB_URL':'postgresql://postgres:TEST_ONLY@db.'+'s'*20+'.supabase.co:5432/postgres?sslmode=require',
            'SUPABASE_SERVICE_ROLE_KEY':token('service_role')}
        self.assertTrue(module.validate_staging(values,public_build=False)['database_connection_configured'])
        bad=[{'RAD_STAGING_DB_URL':'postgresql://postgres:TEST_ONLY@db.'+module.PRODUCTION_PROJECT+'.supabase.co:5432/postgres?sslmode=require'},
            {'RAD_STAGING_DB_URL':'postgresql://postgres:TEST_ONLY@db.'+'s'*20+'.supabase.co:5432/postgres'},
            {'RAD_STAGING_DB_URL':'postgresql://postgres.'+module.PRODUCTION_PROJECT+':TEST_ONLY@region.pooler.supabase.com:5432/postgres?sslmode=require'},
            {'SUPABASE_SERVICE_ROLE_KEY':token('service_role',module.PRODUCTION_PROJECT)},
            {'SUPABASE_SERVICE_ROLE_KEY':token('anon')},{'DATABASE_URL':'TEST_ONLY'},
            {'RAD_STAGING_DB_URL':'postgresql://postgres:TEST_ONLY@db.'+'s'*20+'.supabase.co:5432/postgres?sslmode=require&host=production'}]
        for change in bad:
            with self.subTest(names=list(change)):
                with self.assertRaises(module.StagingConfigError): module.validate_staging({**values,**change},public_build=False)

    def test_environment_file_is_data_and_duplicate_names_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'environment'
            path.write_text('# comment\nAPP_ENV=staging\nTEST_VALUE="$(do_not_execute)"\n',encoding='utf-8')
            self.assertEqual(module.read_environment_file(path)['TEST_VALUE'],'$(do_not_execute)')
            path.write_text('APP_ENV=staging\nAPP_ENV=production\n',encoding='utf-8')
            with self.assertRaises(module.StagingConfigError): module.read_environment_file(path)

    def test_cli_failure_never_echoes_private_values(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'environment'
            values={**settings(),'SUPABASE_SERVICE_ROLE_KEY':'TEST_PRIVATE_CANARY'}
            path.write_text('\n'.join(key+'='+value for key,value in values.items()),encoding='utf-8')
            result=subprocess.run([sys.executable,str(SCRIPT),'--env-file',str(path)],capture_output=True,text=True)
            self.assertEqual(result.returncode,2)
            self.assertNotIn('TEST_PRIVATE_CANARY',result.stdout+result.stderr)


if __name__=='__main__': unittest.main()
