const fs = require('node:fs');
const assert = require('node:assert/strict');
const cp = require('node:child_process');
const root='docs/reviews/';
const data=JSON.parse(fs.readFileSync(root+'inventario-etapa-2.json','utf8'));
const ids=data.actions.map(a=>a.id);
assert.equal(ids.length,219);
assert.equal(new Set(ids).size,219);
assert.equal(new Set(data.actions.map(a=>a.family)).size,38);
assert.deepEqual(data.counts,{mvp:189,'gate-formal-mvp':3,'flutter-only':5,'deferred-post-mvp':22});
assert.deepEqual(data.layerCounts,{
  frontendApplicable:219,
  backendApplicable:212,
  integratedActiveApplicable:187,
  backendNotApplicable:7,
  integratedNotApplicable:7
});
const backendNotApplicable=data.actions.filter(a=>a.backendStatus==='not-applicable').map(a=>a.id);
assert.deepEqual(backendNotApplicable,[
  'shell.load','shell.navigate','shell.switch-context','shell.unauthorized','shell.reload',
  'account.settings','account.theme'
]);
const integratedNotApplicable=data.actions.filter(a=>a.integratedStatus==='flutter-only').map(a=>a.id);
assert.deepEqual(integratedNotApplicable,backendNotApplicable);
for(const n of ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md']) {
  const s=fs.readFileSync(root+n,'utf8');
  const rows=s.split('\n').filter(l=>l.startsWith('| ')&&ids.includes(l.split('|')[2]?.trim()));
  assert.equal(rows.length,219,n);
  assert.deepEqual(rows.map(l=>l.split('|')[2].trim()),ids,n);
  assert(!/R2 está fora do MVP|exportação individual de cada|0\/37|105\/207|0\/202/.test(s),n);
  assert.match(s,/backend_applicable_action_count: 212/,n);
  assert.match(s,/active_e2e_action_count: 187/,n);
  assert.match(s,/client_only_mvp_action_count: 2/,n);
  assert.match(s,/Conclusão certificada no inventário: Front-end 0\/219, backend 0\/212 ações aplicáveis e integração 0\/187 ativas/,n);
  for(const row of rows){const c=row.split('|').map(x=>x.trim());assert.equal(c[3],data.actions.find(a=>a.id===c[2]).scope);}
}
for(const a of data.actions) {
  assert(a.done&&a.fe&&a.be&&a.evidence,a.id);
  assert(!['verified','done','verified-e2e'].includes(a.integratedStatus));
}
const backendTracker=fs.readFileSync(root+'coelo-supabase-pendencias.md','utf8');
const integratedTracker=fs.readFileSync(root+'coelo-flutter-integrado-supabase-pendencias.md','utf8');
for(const id of ['account.settings','account.theme']) {
  assert.match(backendTracker,new RegExp(`\\| ${id.replace('.','\\.')} \\| mvp \\|[^\\n]+\\| not-applicable \\|`),id);
  assert.match(integratedTracker,new RegExp(`\\| ${id.replace('.','\\.')} \\| mvp \\|[^\\n]+\\| flutter-only \\|`),id);
}
for(const n of ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md']) {
  const archived=fs.readFileSync(root+'archive/2026-09-08/'+n,'utf8');
  const original=cp.execFileSync('git',['show',`${data.sourceCommit}:${root}${n}`],{encoding:'utf8',maxBuffer:8e6});
  assert.equal(archived,original,'Archive must preserve original: '+n);
}
console.log('PASS: 219 IDs × 3 matrizes; FE 219 aplicáveis; BE 212 aplicáveis/7 N/A; E2E 187 ativos aplicáveis/7 N/A; escopos 189+3+22+5; históricos preservados. Não substitui auditoria semântica/runtime.');
