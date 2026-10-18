#!/usr/bin/env python3
"""Fail-closed staging configuration checks; no network or deployment actions.

JWT decoding here checks accidental role/project configuration only. It does not
verify JWT signatures or assert that an opaque publishable key belongs to a
project. Real staging authentication remains an owner-run verification step.
"""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import sys
from urllib.parse import parse_qs, unquote, urlsplit

PRODUCTION_PROJECT = 'inshddthftkhcdosoqcn'
PRODUCTION_WEB_HOSTS = {'rad-emigrate.onrender.com'}
PRIVATE_BUILD_VARIABLES = (
    'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_SECRET_KEY', 'SUPABASE_ACCESS_TOKEN',
    'OPENAI_API_KEY', 'ANTHROPIC_API_KEY', 'GEMINI_API_KEY', 'OCR_API_KEY',
    'RAD_PAYMENT_SANDBOX_SECRET', 'RAD_RESEARCH_INVOCATION_TOKEN',
    'DATABASE_URL', 'SUPABASE_DB_PASSWORD', 'PGPASSWORD', 'PAYMENT_API_KEY',
    'STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET', 'RESEND_API_KEY',
    'SENDGRID_API_KEY', 'TWILIO_AUTH_TOKEN',
    'RAD_NOTIFICATION_WORKER_TOKEN',
)


class StagingConfigError(ValueError):
    """Contains only a fixed code, never user-supplied values or credentials."""


def read_environment_file(path: Path) -> dict[str, str]:
    values = {}
    for raw in path.read_text(encoding='utf-8-sig').splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if '=' not in line:
            raise StagingConfigError('invalid_environment_file')
        name, value = line.split('=', 1)
        if not re.fullmatch(r'[A-Z][A-Z0-9_]*', name) or name in values:
            raise StagingConfigError('invalid_or_duplicate_environment_name')
        value = value.strip()
        if value.startswith(('"', "'")):
            if len(value) < 2 or value[-1] != value[0]:
                raise StagingConfigError('invalid_environment_quoting')
            value = value[1:-1]
        # Parse data only. Shell substitution and dotenv expansion are not run.
        if any(char in value for char in ('\x00', '\r', '\n')):
            raise StagingConfigError('invalid_environment_value')
        values[name] = value
    return values


def legacy_public_claims(key: str) -> dict:
    try:
        segments = key.split('.')
        if len(segments) != 3 or len(key) > 8192:
            raise ValueError()
        payload = segments[1]
        data = json.loads(base64.urlsafe_b64decode(payload+'='*((-len(payload)) % 4)))
        if not isinstance(data, dict):
            raise ValueError()
        return data
    except (ValueError, UnicodeError, TypeError):
        raise StagingConfigError('invalid_public_key') from None


def validate_database_target(value: str, project: str) -> None:
    try:
        parsed=urlsplit(value)
        user=unquote(parsed.username or '')
        direct=parsed.hostname == 'db.'+project+'.supabase.co' and user == 'postgres'
        pooled=bool(parsed.hostname and parsed.hostname.endswith('.pooler.supabase.com')) and user == 'postgres.'+project
        query=parse_qs(parsed.query,keep_blank_values=True)
        if (parsed.scheme not in ('postgres','postgresql') or not (direct or pooled)
                or parsed.port != 5432 or not parsed.password or parsed.path != '/postgres'
                or parsed.fragment or query.get('sslmode') not in (['require'],['verify-full'])
                or any(key not in ('sslmode','sslrootcert') for key in query)):
            raise StagingConfigError('staging_database_target_mismatch')
    except ValueError as error:
        if isinstance(error,StagingConfigError): raise
        raise StagingConfigError('invalid_staging_database_url') from None


def validate_staging(values: dict[str, str], *, public_build: bool = True) -> dict:
    if values.get('APP_ENV') != 'staging':
        raise StagingConfigError('staging_environment_required')
    if values.get('RAD_DEPLOYMENT_KIND', 'staging') != 'staging':
        raise StagingConfigError('staging_intent_mismatch')
    project = values.get('RAD_STAGING_PROJECT_REF', '')
    if not re.fullmatch(r'[a-z]{20}', project):
        raise StagingConfigError('explicit_staging_project_required')
    if project == PRODUCTION_PROJECT:
        raise StagingConfigError('production_project_forbidden')
    try:
        if any(re.search(r'\s|[\x00-\x1f\x7f]', values.get(name, '')) for name in ('SUPABASE_URL', 'RAD_STAGING_SITE_URL')):
            raise StagingConfigError('invalid_staging_url')
        parsed = urlsplit(values.get('SUPABASE_URL', ''))
        if (parsed.scheme != 'https' or parsed.hostname != project+'.supabase.co'
                or parsed.username is not None or parsed.password is not None
                or parsed.port is not None or parsed.path not in ('', '/')
                or parsed.query or parsed.fragment):
            raise StagingConfigError('staging_api_target_mismatch')
        site = urlsplit(values.get('RAD_STAGING_SITE_URL', ''))
        if (site.scheme != 'https' or not site.hostname or site.username is not None
                or site.password is not None or site.port is not None
                or site.hostname.rstrip('.') in PRODUCTION_WEB_HOSTS
                or site.hostname == PRODUCTION_PROJECT+'.supabase.co'
                or site.path not in ('', '/') or site.query or site.fragment
                or site.hostname.rstrip('.') == 'localhost'
                or ':' in site.hostname or re.fullmatch(r'[0-9.]+', site.hostname)
                or site.hostname.endswith('.')
                or site.hostname.endswith(('.localhost', '.local', '.internal', '.invalid', '.test'))):
            raise StagingConfigError('explicit_staging_site_required')
    except ValueError as error:
        if isinstance(error, StagingConfigError):
            raise
        raise StagingConfigError('invalid_staging_url') from None
    if public_build:
        if any(values.get(name, '').strip() for name in PRIVATE_BUILD_VARIABLES):
            raise StagingConfigError('private_credentials_in_public_build_environment')
        publishable = values.get('SUPABASE_PUBLISHABLE_KEY', '').strip()
        legacy = values.get('SUPABASE_ANON_KEY', '').strip()
        if publishable and legacy:
            raise StagingConfigError('ambiguous_public_key_aliases')
        key = publishable or legacy
        if key.startswith('sb_publishable_'):
            if not re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]{20,200}', key):
                raise StagingConfigError('invalid_public_key')
            binding = 'opaque_publishable_key_owner_verification_required'
        else:
            claims = legacy_public_claims(key)
            if claims.get('role') != 'anon':
                raise StagingConfigError('privileged_or_invalid_browser_key')
            if claims.get('ref') != project:
                raise StagingConfigError('browser_key_project_mismatch')
            binding = 'legacy_claims_checked_signature_not_verified'
    else:
        if values.get('DATABASE_URL') or values.get('SUPABASE_DB_URL'):
            raise StagingConfigError('generic_database_url_forbidden_for_staging')
        if values.get('RAD_STAGING_DB_URL'):
            validate_database_target(values['RAD_STAGING_DB_URL'],project)
        service=values.get('SUPABASE_SERVICE_ROLE_KEY','').strip()
        if service:
            if service.startswith('sb_secret_'):
                if not re.fullmatch(r'sb_secret_[A-Za-z0-9_-]{20,200}',service):
                    raise StagingConfigError('invalid_backend_key')
            else:
                claims=legacy_public_claims(service)
                if claims.get('role') != 'service_role' or claims.get('ref') != project:
                    raise StagingConfigError('backend_key_project_mismatch')
        binding = 'backend_claims_if_present_checked_opaque_key_binding_requires_owner_verification'
    return {'status': 'PASS', 'scope': 'configuration_only_no_network_or_deployment',
            'project_ref': project, 'api_host': parsed.hostname, 'site_host': site.hostname,
            'public_key_binding': binding, 'production_target': False,
            'database_connection_configured':bool(values.get('RAD_STAGING_DB_URL')) if not public_build else False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path)
    parser.add_argument('--scope', choices=('public-build', 'backend-plan'), default='public-build')
    args = parser.parse_args()
    try:
        values = read_environment_file(args.env_file) if args.env_file else dict(os.environ)
        result = validate_staging(values, public_build=args.scope == 'public-build')
    except (StagingConfigError, OSError) as error:
        code = str(error) if isinstance(error, StagingConfigError) else 'environment_file_unavailable'
        print(json.dumps({'status': 'FAIL', 'error': code}), file=sys.stderr)
        return 2
    print(json.dumps(result))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
