#!/usr/bin/env python3
"""Synthetic signup, mailbox recovery/OTP and expiry against an owned local stack.

Never follows a verification redirect or connects to an external mailbox. Tokens,
passwords, message bodies and addresses are kept in memory and never reported.
The expiry probe changes only its synthetic user's local recovery timestamp.
"""
import argparse
from datetime import datetime, timezone
import html
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--supabase', required=True, type=Path)
    parser.add_argument('--psql', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    args = parser.parse_args()
    project = os.environ.get('RAD_LOCAL47_PROJECT', 'rad_codex_local47')
    port = int(os.environ.get('RAD_LOCAL47_PORT', '55322'))
    runtime = Path(os.environ.get('TEMP', '/tmp')) / project
    marker = json.loads((runtime / 'RAD_DISPOSABLE_LOCAL_ONLY.json').read_text(encoding='utf-8'))
    assert marker == {'project': project, 'source': str(ROOT), 'port': port}, 'wrong local runtime owner'
    result = subprocess.run([str(args.supabase.resolve()), '--workdir', str(runtime), 'status', '--output', 'env'],
                            capture_output=True, text=True, encoding='utf-8', check=True)
    values = {}
    for line in result.stdout.splitlines():
        parts = shlex.split(line, comments=True)
        if parts and '=' in parts[0]:
            key, value = parts[0].split('=', 1)
            values[key] = value
    api = values['API_URL'].rstrip('/')
    assert api == f'http://127.0.0.1:{port-1}', 'refusing non-owned API'
    mailbox = f'http://127.0.0.1:{port+2}'
    anon, service = values['ANON_KEY'], values['SERVICE_ROLE_KEY']
    opener = urllib.request.build_opener(NoRedirect())
    owned_users, owned_messages = [], set()
    env = os.environ.copy()
    env['PGPASSWORD'] = 'postgres'
    psql = [str(args.psql.resolve()), '-XqAt', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1', '-p', str(port), '-U', 'postgres', '-d', 'postgres']

    def request(base, path, method='GET', payload=None, token=None, elevated=False):
        assert base in (api, mailbox), 'external HTTP target prohibited'
        headers = {'Content-Type': 'application/json'}
        if base == api:
            headers.update(apikey=service if elevated else anon, Authorization='Bearer ' + (token or (service if elevated else anon)))
        raw = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(base + path, data=raw, headers=headers, method=method)
        try:
            response = opener.open(req, timeout=15)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            body = response.read(2_000_001)
            assert len(body) <= 2_000_000, 'unexpectedly large local response'
            try:
                data = json.loads(body) if body else {}
            except (ValueError, UnicodeError):
                data = {}
            return response.status, data, response.headers

    def require_status(result, expected, label):
        assert result[0] in expected, label + ': unexpected HTTP status ' + str(result[0])
        return result[1]

    def create_user():
        email = 'rad-local47-' + uuid.uuid4().hex + '@example.invalid'
        password = secrets.token_urlsafe(32)
        user = require_status(request(api, '/auth/v1/admin/users', 'POST',
            {'email': email, 'password': password, 'email_confirm': True}, elevated=True), [200, 201], 'create synthetic user')
        owned_users.append(user['id'])
        return user['id'], email, password

    def message_link(email, expected_type):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            found = require_status(request(mailbox, '/api/v1/search?' + urllib.parse.urlencode({'query': 'to:' + email})), [200], 'mailbox search')
            for item in found.get('messages', []):
                # Search results are additionally bound to the exact synthetic recipient.
                if not any(recipient.get('Address', '').lower() == email for recipient in item.get('To', [])):
                    continue
                owned_messages.add(item['ID'])
                message = require_status(request(mailbox, '/api/v1/message/' + urllib.parse.quote(item['ID'], safe='')), [200], 'mailbox read')
                content = html.unescape(str(message.get('HTML', '')) + '\n' + str(message.get('Text', '')))
                for link in re.findall(r'https?://[^\s<>"\']+', content):
                    parsed = urllib.parse.urlsplit(link)
                    query = urllib.parse.parse_qs(parsed.query)
                    if parsed.path == '/auth/v1/verify' and query.get('type') == [expected_type]:
                        assert parsed.scheme == 'http' and parsed.netloc == f'127.0.0.1:{port-1}', 'non-local verification URL'
                        assert len(query.get('token', [''])[0]) >= 20, 'missing verification token'
                        return parsed.path + '?' + parsed.query, query
            time.sleep(.2)
        raise AssertionError('synthetic email did not arrive in owned local mailbox')

    def verify_denied(token_hash, label):
        response = request(api, '/auth/v1/verify', 'POST', {'token_hash': token_hash, 'type': 'recovery'})
        require_status(response, [400, 401, 403, 422], label)
        assert not response[1].get('access_token'), label + ': session unexpectedly issued'

    report = {'scope': 'owned_local_Auth_Mailpit', 'production_mutations': False, 'external_email_delivery': False,
              'frontend_browser_flow_tested': False, 'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'source_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip()),
              'captured_at': datetime.now(timezone.utc).isoformat(), 'checks': []}

    def passed(label):
        report['checks'].append(label)
        print('PASS ' + label, flush=True)

    try:
        # Default local CLI config has email confirmations disabled; do not claim a signup-confirmation test.
        email = 'rad-local47-' + uuid.uuid4().hex + '@example.invalid'
        password = secrets.token_urlsafe(32)
        signup = require_status(request(api, '/auth/v1/signup', 'POST',
            {'email': email, 'password': password, 'data': {'role': 'super_admin'}}), [200], 'synthetic signup')
        user_id = signup['user']['id']
        owned_users.append(user_id)
        assert signup.get('access_token'), 'this probe expects default local autoconfirm configuration'
        profile = require_status(request(api, '/rest/v1/profiles?select=role&id=eq.' + user_id,
            token=signup['access_token']), [200], 'new profile')
        assert profile == [{'role': 'user'}], 'untrusted signup metadata escalated profile role'
        passed('signup_profile_trigger_ignores_untrusted_role')

        redirect = api + '/reset-password'
        require_status(request(api, '/auth/v1/recover?' + urllib.parse.urlencode({'redirect_to': redirect}),
            'POST', {'email': email}), [200], 'request recovery')
        link, query = message_link(email, 'recovery')
        assert query.get('redirect_to') == [redirect], 'allowed recovery redirect not preserved'
        verify_denied('0' * 64, 'forged recovery token')
        require_status(request(api, '/auth/v1/user', 'PUT', {'password': secrets.token_urlsafe(32)}), [400, 401, 403], 'unauthenticated password change')
        status, _, headers = request(api, link)
        assert status in (302, 303), 'recovery verification did not redirect'
        location = urllib.parse.urlsplit(headers.get('Location', ''))
        assert urllib.parse.urlunsplit((location.scheme, location.netloc, location.path, location.query, '')) == redirect, 'recovery target changed'
        fragment = urllib.parse.parse_qs(location.fragment)
        access, refresh = fragment['access_token'][0], fragment['refresh_token'][0]
        assert fragment.get('type') == ['recovery'], 'recovery session type missing'
        identity = require_status(request(api, '/auth/v1/user', token=access), [200], 'recovered identity')
        assert identity['id'] == user_id, 'recovery changed account identity'
        verify_denied(query['token'][0], 'recovery replay')
        passed('mailbox_recovery_redirect_identity_forgery_and_replay')

        new_password = secrets.token_urlsafe(32)
        require_status(request(api, '/auth/v1/user', 'PUT', {'password': new_password}, token=access), [200], 'recovery password change')
        require_status(request(api, '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': password}), [400, 401, 422], 'old password rejected')
        login = require_status(request(api, '/auth/v1/token?grant_type=password', 'POST', {'email': email, 'password': new_password}), [200], 'new password accepted')
        renewed = require_status(request(api, '/auth/v1/token?grant_type=refresh_token', 'POST', {'refresh_token': login['refresh_token']}), [200], 'session refresh')
        assert renewed['user']['id'] == user_id, 'refresh changed identity'
        require_status(request(api, '/auth/v1/logout?scope=global', 'POST', token=renewed['access_token']), [204], 'global logout')
        require_status(request(api, '/auth/v1/token?grant_type=refresh_token', 'POST', {'refresh_token': renewed['refresh_token']}), [400, 401, 422], 'refresh after logout')
        passed('password_replacement_session_refresh_and_logout_revocation')

        expired_id, expired_email, _ = create_user()
        require_status(request(api, '/auth/v1/recover?' + urllib.parse.urlencode({'redirect_to': 'https://outside.example.invalid/steal'}),
            'POST', {'email': expired_email}), [200], 'request synthetic expiry recovery')
        expired_link, expired_query = message_link(expired_email, 'recovery')
        # Direct fixture ageing avoids waiting an hour and does not alter Auth config or clocks.
        aged = subprocess.run(psql, input="update auth.users set recovery_sent_at=now()-interval '2 hours' where id='" + expired_id + "'::uuid;",
            env=env, capture_output=True, text=True, encoding='utf-8', check=True)
        verify_denied(expired_query['token'][0], 'expired recovery')
        status, _, headers = request(api, expired_link)
        location = urllib.parse.urlsplit(headers.get('Location', ''))
        assert status in (302, 303) and location.netloc == f'127.0.0.1:{port-1}', 'unapproved redirect escaped local site'
        assert 'access_token' not in urllib.parse.parse_qs(location.fragment), 'expired link issued session'
        passed('fixture_aged_recovery_denied_and_unapproved_redirect_contained')

        otp_id, otp_email, _ = create_user()
        require_status(request(api, '/auth/v1/otp', 'POST', {'email': otp_email, 'create_user': False}), [200], 'request passwordless email')
        _, otp_query = message_link(otp_email, 'magiclink')
        require_status(request(api, '/auth/v1/verify', 'POST', {'email': otp_email, 'token': '00000000', 'type': 'email'}), [400, 401, 403, 422], 'forged email OTP')
        otp = require_status(request(api, '/auth/v1/verify', 'POST', {'token_hash': otp_query['token'][0], 'type': 'email'}), [200], 'email token verification')
        assert otp['user']['id'] == otp_id and otp.get('access_token'), 'email token changed account identity'
        require_status(request(api, '/auth/v1/verify', 'POST', {'token_hash': otp_query['token'][0], 'type': 'email'}), [400, 401, 403, 422], 'email token replay')
        passed('passwordless_mailbox_token_identity_forgery_and_replay')
    finally:
        # Delete only IDs allocated by this invocation, not another test's users/messages.
        for owned in owned_users:
            require_status(request(api, '/auth/v1/admin/users/' + owned, 'DELETE', elevated=True), [200, 204], 'cleanup synthetic user')
        if owned_messages:
            require_status(request(mailbox, '/api/v1/messages', 'DELETE', {'IDs': sorted(owned_messages)}), [200, 204], 'cleanup owned messages')
    report.update(status='PASS', synthetic_users_removed=len(owned_users), owned_messages_removed=len(owned_messages),
                  signup_email_confirmation_tested=False, expiry_method='synthetic_user_recovery_sent_at_aged_two_hours')
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
