"""Two-JWT notification read/update isolation on the disposable 47+5 stack."""
import json
import uuid
from verify_stage2_browser_e2e import LocalSupabaseFixtures, load_local_environment, require
from verify_prepilot_consultation import access_token


def main():
    env = load_local_environment()
    require(env['API_URL'] == 'http://127.0.0.1:56321', 'refusing other stacks')
    fixtures = LocalSupabaseFixtures(env)
    results = {}
    try:
        owner, other = fixtures.create_identity('user'), fixtures.create_identity('user')
        own_token, other_token = access_token(fixtures, owner), access_token(fixtures, other)
        nid = str(uuid.uuid4())
        fixtures.expect_json('POST', '/rest/v1/notifications', payload=[{
            'id': nid, 'user_id': owner.user_id, 'type': 'system',
            'title': 'Synthetic notification acceptance', 'body': 'Non-production engineering fixture',
        }], prefer='return=representation')
        path = f'/rest/v1/notifications?select=id,read_at&id=eq.{nid}'
        require(len(fixtures.expect_json('GET', path, token=own_token)) == 1, 'owner read failed')
        require(fixtures.expect_json('GET', path, token=other_token) == [], 'cross-owner read leaked')
        changed = fixtures.expect_json('PATCH', path, token=other_token,
                                      payload={'read_at': '2026-10-13T00:00:00Z'}, prefer='return=representation')
        require(changed == [], 'cross-owner update changed notification')
        require(fixtures.expect_json('GET', path, token=own_token)[0]['read_at'] is None,
                'cross-owner attempt altered notification')
        changed = fixtures.expect_json('PATCH', path, token=own_token,
                                      payload={'read_at': '2026-10-13T00:00:00Z'}, prefer='return=representation')
        require(len(changed) == 1 and changed[0]['read_at'], 'owner mark-read failed')
        status, _, _ = fixtures.request('POST', '/rest/v1/notifications', token=own_token,
                                        payload={'user_id': other.user_id, 'type': 'system', 'title': 'Denied', 'body': 'Denied'})
        require(status == 403, 'ordinary user created arbitrary notification')
        results = {'result': 'PASS', 'owner_read': True, 'owner_mark_read': True,
                   'cross_owner_rows': 0, 'cross_owner_updates': 0, 'arbitrary_insert_status': status}
    finally:
        fixtures.cleanup()
        results['fixtures_cleaned'] = True
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
