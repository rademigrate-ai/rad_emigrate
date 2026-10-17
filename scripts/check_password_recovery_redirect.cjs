// Standalone regression tests: node scripts/check_password_recovery_redirect.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const root = path.resolve(__dirname, '..');
const script = fs.readFileSync(path.join(root, 'web', 'rad_recovery_redirect.js'), 'utf8');
const index = fs.readFileSync(path.join(root, 'web', 'index.html'), 'utf8');
assert(index.indexOf('src="rad_recovery_redirect.js"') > 0);
assert(index.indexOf('src="rad_recovery_redirect.js"') < index.indexOf('src="flutter_bootstrap.js"'));

function normalize(href) {
  const input = new URL(href);
  let result = input.pathname + input.search + input.hash;
  let calls = 0;
  const history = {
    state: { source: 'test' },
    replaceState(state, _unused, next) {
      assert.equal(state, history.state);
      result = next;
      calls += 1;
    },
  };
  vm.runInNewContext(script, {
    window: {
      location: { hash: input.hash, search: input.search, origin: input.origin },
      history,
    },
    URL,
    URLSearchParams,
  });
  return { result, calls };
}

const origin = 'https://rad-emigrate.onrender.com';
const cases = [
  [origin + '/#/reset-password', '/reset-password', 1],
  [origin + '/#/reset-password?code=PKCE_TEST', '/reset-password?code=PKCE_TEST', 1],
  [origin + '/?code=PKCE_TEST#/reset-password', '/reset-password?code=PKCE_TEST', 1],
  [origin + '/#/reset-password#access_token=TEST', '/reset-password#access_token=TEST', 1],
  [origin + '/?x=1#/reset-password?code=TEST', '/reset-password?code=TEST&x=1', 1],
  [origin + '/reset-password', '/reset-password', 0],
  [origin + '/#/login', '/#/login', 0],
  [origin + '/#/reset-password-evil?code=TEST', '/#/reset-password-evil?code=TEST', 0],
];
for (const [url, expected, calls] of cases) {
  const got = normalize(url);
  assert.deepEqual(got, { result: expected, calls }, url);
}
console.log('PASS: ' + cases.length + ' recovery URL normalization scenarios');
