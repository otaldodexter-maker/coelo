import test from 'node:test';
import assert from 'node:assert/strict';
import { qualifyLocalConfig, qualifyPublicSettings, qualificationSql, target } from './r02-d01-auth-proof.mjs';

test('local config requires exact production redirect within auth section', () => {
  assert.equal(qualifyLocalConfig(`[auth]\nadditional_redirect_urls = ["${target.redirect}"]\n[other]`).productionConfigVerified, false);
  assert.throws(() => qualifyLocalConfig(`[auth]\n[other]\nadditional_redirect_urls = ["${target.redirect}"]`), /LOCAL_REDIRECT_MISSING/);
});

test('mismatched project and origins never issue a request', async () => {
  for (const override of [{projectRef: 'another'}, {apiOrigin: `${target.apiOrigin}.example.com`}, {appOrigin: 'http://localhost:3000'}]) {
    await assert.rejects(qualifyPublicSettings({...override, fetcher: () => assert.fail('network')}), /NOMINAL_TARGET_MISMATCH/);
  }
});

test('secret and absent API keys are rejected before network', async () => {
  for (const publishableKey of [undefined, 'sb_secret_synthetic', 'synthetic-jwt']) {
    await assert.rejects(qualifyPublicSettings({publishableKey, fetcher: () => assert.fail('network')}), /PUBLISHABLE_KEY_REQUIRED/);
  }
});

test('public settings uses one GET, blocks redirects, and emits only allowlisted booleans', async () => {
  let calls = 0;
  const result = await qualifyPublicSettings({publishableKey: 'sb_publishable_synthetic', fetcher: async (url, options) => {
    calls++;
    assert.equal(url, `${target.apiOrigin}/auth/v1/settings`);
    assert.equal(options.method, 'GET');
    assert.equal(options.redirect, 'error');
    assert.equal(options.credentials, 'omit');
    assert.deepEqual(Object.keys(options.headers), ['apikey']);
    return {status: 200, json: async () => ({external: {email: true}, disable_signup: true, secret: 'never-output', email: 'never-output'})};
  }});
  assert.equal(calls, 1);
  assert.equal(result.emailProviderEnabled, true);
  assert.equal(result.session, 'not-exercised');
  assert.ok(!JSON.stringify(result).includes('never-output'));
});

test('network and malformed provider errors are sanitized', async () => {
  for (const fetcher of [async () => {throw new Error('synthetic-private-token');}, async () => ({status: 200, json: async () => ({})}), async () => ({status: 401})]) {
    await assert.rejects(qualifyPublicSettings({publishableKey: 'sb_publishable_synthetic', fetcher}), /^Error: SETTINGS_UNCONFIRMED$/);
  }
});

test('nominal qualification SQL only reads aggregate/schema data and never calls bootstrap', () => {
  assert.ok(qualificationSql.startsWith('begin read only;'));
  assert.ok(qualificationSql.endsWith('commit;'));
  assert.ok(!/\b(insert|update|delete|alter|drop|create)\b/i.test(qualificationSql));
  assert.ok(!/select\s+public\.superadmin_auth_bootstrap_context/i.test(qualificationSql));
  assert.ok(qualificationSql.includes(target.projectRef));
  for (const id of [target.authUserId, target.identityId, target.authLinkId, target.membershipId]) assert.ok(qualificationSql.includes(id));
});
