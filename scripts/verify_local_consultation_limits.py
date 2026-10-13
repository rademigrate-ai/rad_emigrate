"""Execute daily and concurrent intake limits using disposable real JWTs."""
import concurrent.futures
import json
from verify_stage2_browser_e2e import LocalSupabaseFixtures, load_local_environment, require
from verify_prepilot_consultation import access_token
from verify_prod_equiv_rpc_acceptance import psql


def main():
    env = load_local_environment()
    require(env['API_URL'] == 'http://127.0.0.1:56321', 'refusing other stacks')
    fixtures = LocalSupabaseFixtures(env)
    result = {}
    try:
        daily, parallel_user = fixtures.create_identity('user'), fixtures.create_identity('user')
        daily_token, concurrent_token = access_token(fixtures, daily), access_token(fixtures, parallel_user)
        psql(f"insert into public.consultation_requests(user_id,topic,message,status,created_at) "
             f"select '{daily.user_id}'::uuid,'Synthetic daily limit','Synthetic engineering limit fixture','submitted', "
             "now()-interval '2 hours' from generate_series(1,10);")
        status, body, _ = fixtures.request('POST', '/rest/v1/rpc/submit_consultation_request', token=daily_token,
                                           payload={'p_topic': 'Daily limit probe', 'p_message': 'Synthetic engineering fixture'})
        require(status == 400 and json.loads(body)['code'] == 'P0001'
                and 'consultation_rate_limited' in body.decode(), 'daily ten-request limit failed')
        def submit(i):
            return fixtures.request('POST', '/rest/v1/rpc/submit_consultation_request', token=concurrent_token,
                                    payload={'p_topic': f'Concurrent fixture {i}', 'p_message': 'Synthetic engineering fixture'})
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            replies = list(pool.map(submit, range(8)))
        accepted = [json.loads(body) for status, body, _ in replies if status == 200]
        denied = [(status, json.loads(body)) for status, body, _ in replies if status != 200]
        require(len(set(accepted)) == 3 and len(denied) == 5, 'concurrent limit overshot or lost requests')
        require(all(status == 400 and body['code'] == 'P0001' for status, body in denied), 'unexpected denial')
        require(psql(f"select count(*) from public.consultation_requests where user_id='{parallel_user.user_id}'") == '3',
                'persisted consultation count mismatch')
        result = {'result': 'PASS', 'daily_seeded_outside_hour': 10, 'daily_eleventh_status': status,
                  'concurrent_calls': 8, 'accepted_unique': 3, 'rate_limited': 5, 'persisted': 3}
    finally:
        fixtures.cleanup()
        result['fixtures_cleaned'] = True
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
