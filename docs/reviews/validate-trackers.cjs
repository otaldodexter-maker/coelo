const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const names = ['coelo-flutter-pendencias.md', 'coelo-supabase-pendencias.md', 'coelo-flutter-integrado-supabase-pendencias.md'];
const layers = ['frontend', 'backend', 'integrated'];
const terminals = ['verified', 'done', 'verified-e2e'];
const common = ['pending-verification', 'audited', 'fail-closed', 'blocked-decision', 'blocked-environment', 'local-green', 'regressed'];
const states = [
  new Set([...common, 'verified']),
  new Set([...common, 'remote-green', 'done', 'not-applicable', 'deferred-post-mvp', 'gate-formal-mvp']),
  new Set([...common, 'blocked-flutter', 'blocked-supabase', 'blocked-backend', 'ready-for-e2e', 'verified-e2e', 'flutter-only', 'deferred-post-mvp', 'gate-formal-mvp']),
];

function validate(data, trackers) {
  const actions = data.actions;
  assert(actions.length > 0, 'Empty inventory');
  const ids = actions.map(a => a.id);
  assert.equal(new Set(ids).size, ids.length, 'Duplicate action IDs');
  assert.equal(trackers.length, 3, 'Three trackers required');
  const counts = { mvp: 0, 'gate-formal-mvp': 0, 'flutter-only': 0, 'deferred-post-mvp': 0 };
  for (const a of actions) {
    assert(Object.hasOwn(counts, a.scope), 'Unknown scope: ' + a.id);
    counts[a.scope]++;
    assert(a.id && a.family && a.screen && a.done && a.fe && a.be && a.evidence, 'Missing fields: ' + a.id);
    const clientOnly = a.scope === 'flutter-only' || ['account.settings', 'account.theme'].includes(a.id);
    assert.equal(a.backendStatus === 'not-applicable', clientOnly, 'Backend applicability: ' + a.id);
    assert.equal(a.integratedStatus === 'flutter-only', clientOnly, 'E2E applicability: ' + a.id);
    if (['gate-formal-mvp', 'deferred-post-mvp'].includes(a.scope)) {
      assert.equal(a.backendStatus, a.scope, 'Backend scope state: ' + a.id);
      assert.equal(a.integratedStatus, a.scope, 'E2E scope state: ' + a.id);
    }
    if (['ready-for-e2e', 'verified-e2e'].includes(a.integratedStatus)) {
      assert.equal(a.frontendStatus, 'verified', 'E2E requires completed frontend: ' + a.id);
      assert.equal(a.backendStatus, 'done', 'E2E requires completed backend: ' + a.id);
    }
    layers.forEach((layer, i) => {
      assert(states[i].has(a[layer + 'Status']), 'Unknown ' + layer + ' state: ' + a.id);
      if (a[layer + 'Status'] !== terminals[i]) return;
      const certificate = a.certifications?.[layer];
      for (const key of ['evidence', 'revision', 'environment', 'recordedAt']) {
        assert(typeof certificate?.[key] === 'string' && certificate[key].trim(), 'Missing certification ' + layer + '.' + key + ': ' + a.id);
      }
      assert(Number.isFinite(Date.parse(certificate.recordedAt)), 'Invalid certification date: ' + a.id);
    });
  }
  assert.deepEqual(data.counts, counts, 'Scope counts');
  const be = actions.filter(a => a.backendStatus !== 'not-applicable');
  const integrated = actions.filter(a => a.integratedStatus !== 'flutter-only');
  const active = integrated.filter(a => a.scope === 'mvp');
  const formal = integrated.filter(a => a.scope === 'gate-formal-mvp');
  assert.deepEqual(data.layerCounts, {
    frontendApplicable: ids.length, backendApplicable: be.length,
    integratedActiveApplicable: active.length, backendNotApplicable: ids.length - be.length,
    integratedNotApplicable: ids.length - integrated.length,
  }, 'Layer counts');
  const completed = actions.filter(a => a.frontendStatus === 'verified').length;
  const beCompleted = be.filter(a => a.backendStatus === 'done').length;
  const e2eCompleted = active.filter(a => a.integratedStatus === 'verified-e2e').length;
  const summary = 'Conclusão certificada no inventário: Front-end ' + completed + '/' + ids.length +
    ', backend ' + beCompleted + '/' + be.length + ' ações aplicáveis e integração ' +
    e2eCompleted + '/' + active.length + ' ativas (também ' + e2eCompleted + '/' +
    (active.length + formal.length) + ' incluindo o gate formal)';
  const fields = {
    action_count: ids.length, family_count: new Set(actions.map(a => a.family)).size,
    active_mvp_action_count: counts.mvp, active_e2e_action_count: active.length,
    client_only_mvp_action_count: actions.filter(a => a.scope === 'mvp' && a.backendStatus === 'not-applicable').length,
    backend_applicable_action_count: be.length, formal_mvp_gate_action_count: counts['gate-formal-mvp'],
    deferred_post_mvp_action_count: counts['deferred-post-mvp'], flutter_only_action_count: counts['flutter-only'],
  };
  trackers.forEach((text, i) => {
    const marker = '## Matriz vigente por ação';
    const matrix = text.includes(marker) ? text.split(marker)[1].split(/\r?\n## /)[0] : text;
    const rows = matrix.split('\n').filter(line => line.startsWith('| '))
      .map(line => line.split('|').slice(1, -1).map(cell => cell.trim().replace(/^`|`$/g, '')))
      .filter(row => row[1] !== 'action_id' && !/^:?-+:?$/.test(row[1] || ''));
    assert.deepEqual(rows.map(row => row[1]), ids, 'Tracker IDs: ' + names[i]);
    rows.forEach((row, j) => {
      assert.equal(row[2], actions[j].scope, 'Tracker scope: ' + ids[j]);
      assert.equal(row[i === 2 ? 6 : 5], actions[j][layers[i] + 'Status'], 'Tracker state: ' + names[i] + ' ' + ids[j]);
    });
    for (const [key, value] of Object.entries(fields)) {
      assert.match(text, new RegExp('^' + key + ': ' + value + '\\r?$', 'm'), 'Header ' + key + ': ' + names[i]);
    }
    assert(text.includes(summary), 'Stale certified summary: ' + names[i]);
    assert(!/R2 está fora do MVP|exportação individual de cada/.test(text), 'Superseded media rule: ' + names[i]);
  });
  return { actions: ids.length, families: fields.family_count, frontendCompleted: completed, backendCompleted: beCompleted, e2eCompleted, activeE2E: active.length };
}

if (require.main === module) {
  const directory = __dirname;
  const repo = path.resolve(directory, '../..');
  const data = JSON.parse(fs.readFileSync(path.join(directory, 'inventario-etapa-2.json'), 'utf8'));
  const result = validate(data, names.map(name => fs.readFileSync(path.join(directory, name), 'utf8')));
  for (const a of data.actions) {
    for (const [i, layer] of layers.entries()) {
      if (a[layer + 'Status'] !== terminals[i]) continue;
      const reference = a.certifications[layer].evidence;
      assert(!path.isAbsolute(reference), 'Certification must be repository relative: ' + a.id);
      const resolved = fs.realpathSync(path.resolve(repo, reference));
      const relative = path.relative(fs.realpathSync(repo), resolved);
      assert(relative && !relative.startsWith('..') && !path.isAbsolute(relative), 'Certification outside repository: ' + a.id);
      assert(fs.statSync(resolved).isFile(), 'Certification must be a file: ' + a.id);
    }
  }
  for (const name of names) {
    const archived = fs.readFileSync(path.join(directory, 'archive/2026-09-08', name), 'utf8');
    const original = cp.execFileSync('git', ['show', data.sourceCommit + ':docs/reviews/' + name], { cwd: repo, encoding: 'utf8', maxBuffer: 8e6 });
    assert.equal(archived, original, 'Archive must preserve original: ' + name);
  }
  console.log('PASS: ' + JSON.stringify(result) + '; three trackers consistent; archives preserved. Structural validation, not runtime certification.');
}
module.exports = { validate };
