const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { validate } = require('./validate-trackers.cjs');
const names = ['coelo-flutter-pendencias.md', 'coelo-supabase-pendencias.md', 'coelo-flutter-integrado-supabase-pendencias.md'];
function fixture() {
  const actions = [
    ['auth.login', 'auth', 'mvp'], ['institutions.list', 'institutions', 'mvp'],
    ['shell.load', 'shell', 'flutter-only'], ['account.settings', 'account', 'mvp'],
    ['auth.mfa', 'auth', 'gate-formal-mvp'], ['institutions.export', 'institutions', 'deferred-post-mvp'],
  ].map(([id, family, scope]) => {
    const local = scope === 'flutter-only' || id === 'account.settings';
    return { id, family, scope, screen: id, done: 'Synthetic prior work', fe: 'FE acceptance',
      be: 'BE acceptance', evidence: 'synthetic-evidence.md', frontendStatus: 'pending-verification',
      backendStatus: local ? 'not-applicable' : scope === 'mvp' ? 'pending-verification' : scope,
      integratedStatus: local ? 'flutter-only' : scope === 'mvp' ? 'pending-verification' : scope };
  });
  const header = '---\naction_count: 6\nfamily_count: 4\nactive_mvp_action_count: 3\nactive_e2e_action_count: 2\nclient_only_mvp_action_count: 1\nbackend_applicable_action_count: 4\nformal_mvp_gate_action_count: 1\ndeferred_post_mvp_action_count: 1\nflutter_only_action_count: 1\n---\n';
  const summary = 'Conclusão certificada no inventário: Front-end 0/6, backend 0/4 ações aplicáveis e integração 0/2 ativas (também 0/3 incluindo o gate formal)\n';
  const trackers = ['frontend', 'backend', 'integrated'].map((layer, i) => header + summary + actions.map(a =>
    '| ' + [a.screen, a.id, a.scope, a.done, i === 1 ? a.be : a.fe, ...(i === 2 ? [a.be] : []), a[layer + 'Status'], a.evidence].join(' | ') + ' |'
  ).join('\n'));
  return { data: { actions, counts: { mvp: 3, 'gate-formal-mvp': 1, 'flutter-only': 1, 'deferred-post-mvp': 1 },
    layerCounts: { frontendApplicable: 6, backendApplicable: 4, integratedActiveApplicable: 2, backendNotApplicable: 2, integratedNotApplicable: 2 } }, trackers };
}
function certify(f) {
  const a = f.data.actions.find(a => a.id === 'auth.login');
  const states = ['verified', 'done', 'verified-e2e'];
  ['frontendStatus', 'backendStatus', 'integratedStatus'].forEach((key, i) => { a[key] = states[i]; });
  a.certifications = Object.fromEntries(['frontend', 'backend', 'integrated'].map(layer => [layer, {
    evidence: 'synthetic-evidence.md', revision: 'synthetic-revision',
    environment: 'synthetic-environment', recordedAt: '2026-09-09T12:00:00Z',
  }]));
  f.trackers = f.trackers.map((text, i) => text.split('\n').map(line =>
    line.includes('| auth.login |') ? line.replace('| pending-verification |', `| ${states[i]} |`) : line
  ).join('\n').replace('Front-end 0/6, backend 0/4 ações aplicáveis e integração 0/2 ativas (também 0/3',
    'Front-end 1/6, backend 1/4 ações aplicáveis e integração 1/2 ativas (também 1/3'));
  return f;
}
test('accepts the current reconciled inventory', () => {
  const data = JSON.parse(fs.readFileSync(`${__dirname}/inventario-etapa-2.json`, 'utf8'));
  const trackers = names.map(name => fs.readFileSync(`${__dirname}/${name}`, 'utf8'));
  assert.doesNotThrow(() => validate(data, trackers));
});
test('accepts a different inventory size with reconciled denominators', () => {
  const f = fixture();
  assert.doesNotThrow(() => validate(f.data, f.trackers));
});
test('accepts a documented future E2E promotion instead of freezing zero', () => {
  const f = certify(fixture());
  assert.doesNotThrow(() => validate(f.data, f.trackers));
});
test('rejects promotion without nominal certification', () => {
  const f = certify(fixture());
  delete f.data.actions[0].certifications;
  assert.throws(() => validate(f.data, f.trackers), /certification/i);
});
test('rejects E2E when the same action has no completed backend', () => {
  const f = certify(fixture());
  f.data.actions[0].backendStatus = 'pending-verification';
  assert.throws(() => validate(f.data, f.trackers), /backend/i);
});
test('rejects drift between tracker rows and inventory states', () => {
  const f = fixture();
  f.trackers[0] = f.trackers[0].replace('| pending-verification |', '| verified |');
  assert.throws(() => validate(f.data, f.trackers), /state/i);
});
test('rejects stale scope totals', () => {
  const f = fixture();
  f.data.counts.mvp -= 1;
  assert.throws(() => validate(f.data, f.trackers), /counts/i);
});

test('rejects stale work, next steps and evidence even with matching counts and states', () => {
  for (const [layer, original] of [[0, 'Synthetic prior work'], [0, 'FE acceptance'],
    [1, 'BE acceptance'], [2, 'FE acceptance'], [2, 'BE acceptance'], [2, 'synthetic-evidence.md']]) {
    const f = fixture();
    f.trackers[layer] = f.trackers[layer].replace(original, 'Stale description');
    assert.throws(() => validate(f.data, f.trackers), /Tracker content/);
  }
});
test('rejects duplicate action IDs', () => {
  const f = fixture();
  f.data.actions[1].id = f.data.actions[0].id;
  assert.throws(() => validate(f.data, f.trackers), /duplicate/i);
});
test('rejects a stale headline after an otherwise consistent promotion', () => {
  const f = certify(fixture());
  f.trackers[0] = f.trackers[0].replace('Front-end 1/6', 'Front-end 0/6');
  assert.throws(() => validate(f.data, f.trackers), /summary/i);
});
test('keeps backend completion independent of frontend', () => {
  const f = certify(fixture());
  f.data.actions[0].frontendStatus = 'pending-verification';
  f.data.actions[0].integratedStatus = 'pending-verification';
  f.trackers = f.trackers.map((text, i) => text.replace(i === 0 ? '| verified |' : i === 2 ? '| verified-e2e |' : 'UNCHANGED', '| pending-verification |')
    .replace('Front-end 1/6', 'Front-end 0/6').replace('integração 1/2', 'integração 0/2').replace('também 1/3', 'também 0/3'));
  assert.doesNotThrow(() => validate(f.data, f.trackers));
});
