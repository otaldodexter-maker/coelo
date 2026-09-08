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
for(const n of ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md']) {
  const s=fs.readFileSync(root+n,'utf8');
  const rows=s.split('\n').filter(l=>l.startsWith('| ')&&ids.includes(l.split('|')[2]?.trim()));
  assert.equal(rows.length,219,n);
  assert.deepEqual(rows.map(l=>l.split('|')[2].trim()),ids,n);
  assert(!/R2 está fora do MVP|exportação individual de cada|0\/37|105\/207|0\/202/.test(s),n);
  for(const row of rows){const c=row.split('|').map(x=>x.trim());assert.equal(c[3],data.actions.find(a=>a.id===c[2]).scope);}
}
for(const a of data.actions) {
  assert(a.done&&a.fe&&a.be&&a.evidence,a.id);
  assert(!['verified','done','verified-e2e'].includes(a.integratedStatus));
}
for(const n of ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md']) {
  const archived=fs.readFileSync(root+'archive/2026-09-08/'+n,'utf8');
  const original=cp.execFileSync('git',['show',`${data.sourceCommit}:${root}${n}`],{encoding:'utf8',maxBuffer:8e6});
  assert.equal(archived,original,'Archive must preserve original: '+n);
}
console.log('PASS: consistência estrutural de 219 IDs × 3 matrizes; 38 famílias; escopos 189+3+22+5; arquivos históricos idênticos à base. Não substitui auditoria semântica/runtime.');
