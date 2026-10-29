"""Real GoTrue/PostgREST fixtures in the separately marked local QA stack.

Keys and generated local-only passwords are never returned in logs or Git.
No hosted URL, arbitrary port, existing contributor stack or unmarked runtime
can be selected by this helper.
"""

import argparse
import json
import secrets
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = 'rad_codex_final_20261028'
PORT = 65322


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class LocalBackend:
    def __init__(self, runtime, cli):
        self.runtime = runtime.resolve()
        marker = json.loads((self.runtime / 'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8'))
        if marker != {'project': PROJECT, 'source': str(ROOT), 'port': PORT}:
            raise ValueError('owned_local_runtime_marker_required')
        result = subprocess.run([str(cli), '--workdir', str(runtime), 'status', '--output', 'json'], capture_output=True, text=True, encoding='utf-8', check=True)
        status = json.loads(result.stdout)
        self.url = status.get('API_URL') or status.get('api_url')
        parsed = urllib.parse.urlsplit(self.url or '')
        if parsed.hostname != '127.0.0.1' or parsed.port != PORT - 1:
            raise ValueError('exact_loopback_QA_target_required')
        self.anon = status.get('ANON_KEY') or status.get('anon_key')
        self.service = status.get('SERVICE_ROLE_KEY') or status.get('service_role_key')
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        if not self.anon or not self.service:
            raise ValueError('local_status_keys_unavailable')

    def request(self, method, path, payload=None, token=None, service=False):
        if not path.startswith('/') or '://' in path:
            raise ValueError('local_relative_API_path_required')
        key = self.service if service else self.anon
        headers = {'apikey': key, 'Authorization': 'Bearer ' + (token or key), 'Content-Type': 'application/json'}
        request = urllib.request.Request(self.url + path, data=json.dumps(payload).encode() if payload is not None else None, headers=headers, method=method)
        try:
            with self.opener.open(request, timeout=30) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            # Body may contain fixture credentials or identifiers. Callers get
            # only a bounded safe status and code, never the raw request.
            body = json.loads(error.read() or b'{}')
            return error.code, {'code': body.get('code') or body.get('error_code')}

    def initialize(self):
        accounts = self.runtime / 'qa-accounts.private.json'
        if accounts.exists():
            data = json.loads(accounts.read_text(encoding='utf-8'))
            if data['project'] != PROJECT or data['api_url'] != self.url:
                raise ValueError('fixture_account_target_changed')
        else:
            rows = []
            for role in ('user_a', 'user_b', 'admin', 'super_admin'):
                password = secrets.token_urlsafe(32)
                email = f'qa-{role}-{uuid.uuid4().hex}@example.invalid'
                status, user = self.request('POST', '/auth/v1/admin/users', {'email': email, 'password': password, 'email_confirm': True, 'user_metadata': {'full_name': 'SYNTHETIC QA ' + role, 'qa_fixture': True}}, service=True)
                if status not in (200, 201) or not user.get('id'):
                    raise RuntimeError('local_fixture_creation_failed:' + str(status))
                granted = 'user' if role.startswith('user_') else role
                status, _ = self.request('PATCH', '/rest/v1/profiles?id=eq.' + user['id'], {'role': granted, 'full_name': 'SYNTHETIC QA ' + role}, service=True)
                if status not in (200, 204):
                    raise RuntimeError('local_fixture_profile_failed:' + str(status))
                rows.append({'role': role, 'id': user['id'], 'email': email, 'password': password})
            data = {'project': PROJECT, 'api_url': self.url, 'accounts': rows, 'scope': 'generated local-only synthetic GoTrue identities, never hosted'}
            accounts.write_text(json.dumps(data), encoding='utf-8')
        sid = subprocess.check_output(['whoami', '/user', '/fo', 'csv', '/nh'], text=True).strip().split(',')[-1].strip('"')
        subprocess.run(['icacls', str(accounts), '/inheritance:r', '/grant:r', '*' + sid + ':(F)'], check=True, capture_output=True)
        # Frontend receives only the public local anon key. Service key stays
        # in this process and is not persisted in the frontend configuration.
        (self.runtime / 'flutter-public.json').write_text(json.dumps({'SUPABASE_URL': self.url, 'SUPABASE_ANON_KEY': self.anon, 'APP_ENV': 'development'}), encoding='utf-8')
        return {'project': PROJECT, 'api_url': self.url, 'roles': [r['role'] for r in data['accounts']], 'real_GoTrue_accounts': len(data['accounts']), 'hosted_writes': 0, 'credential_values_logged': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--cli', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(LocalBackend(args.runtime, args.cli).initialize()))
