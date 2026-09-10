// Aplica deltas de estado no inventário e regenera, a partir dele, a matriz por
// ação e os campos de cabeçalho dos três rastreadores.
//
// O inventário é a fonte; os rastreadores são projeções. Manter as três matrizes
// à mão significa 690 linhas idênticas para não divergir. `validate-trackers.cjs`
// continua sendo o juiz: este script só escreve o que aquele valida.
//
// Uso:
//   node docs/reviews/apply-tracker-delta.cjs <deltas.json>   aplica e regenera
//   node docs/reviews/apply-tracker-delta.cjs --sync          só regenera
//
// Formato de <deltas.json>: array de
//   {action_id, camada: frontend|backend|integrated, estado_proposto,
//    delta?, evidencia?, certificacao?: {evidence, revision, environment, recordedAt}}

const fs = require('node:fs');
const path = require('node:path');

const directory = __dirname;
const names = ['coelo-flutter-pendencias.md', 'coelo-supabase-pendencias.md', 'coelo-flutter-integrado-supabase-pendencias.md'];
const layers = ['frontend', 'backend', 'integrated'];
const terminals = ['verified', 'done', 'verified-e2e'];
const inventoryPath = path.join(directory, 'inventario-etapa-2.json');

const normalize = value => String(value).replace(/\|/g, '/').replace(/\r?\n/g, ' ').trim();

function applyDeltas(data, deltas) {
  const byId = new Map(data.actions.map(action => [action.id, action]));
  const applied = [];
  for (const entry of deltas) {
    const action = byId.get(entry.action_id);
    if (!action) throw new Error('action_id desconhecido: ' + entry.action_id);
    const index = layers.indexOf(entry.camada);
    if (index < 0) throw new Error('camada invalida em ' + entry.action_id + ': ' + entry.camada);
    const field = entry.camada + 'Status';
    const before = action[field];
    if (entry.estado_proposto) action[field] = entry.estado_proposto;
    if (entry.delta) {
      if (entry.camada === 'frontend') action.fe = entry.delta;
      else if (entry.camada === 'backend') action.be = entry.delta;
      else action.done = entry.delta;
    }
    if (entry.evidencia && !action.evidence.includes(entry.evidencia)) {
      action.evidence = action.evidence + '; ' + entry.evidencia;
    }
    if (action[field] === terminals[index]) {
      if (!entry.certificacao) throw new Error('estado terminal exige certificacao: ' + entry.action_id);
      action.certifications = action.certifications || {};
      action.certifications[entry.camada] = entry.certificacao;
    }
    applied.push(entry.action_id + ' ' + entry.camada + ': ' + before + ' -> ' + action[field]);
  }
  return applied;
}

function headerFields(data) {
  const actions = data.actions;
  const be = actions.filter(a => a.backendStatus !== 'not-applicable');
  const integrated = actions.filter(a => a.integratedStatus !== 'flutter-only');
  const active = integrated.filter(a => a.scope === 'mvp');
  const formal = integrated.filter(a => a.scope === 'gate-formal-mvp');
  const counts = { mvp: 0, 'gate-formal-mvp': 0, 'flutter-only': 0, 'deferred-post-mvp': 0 };
  for (const a of actions) counts[a.scope]++;
  data.counts = counts;
  data.layerCounts = {
    frontendApplicable: actions.length,
    backendApplicable: be.length,
    integratedActiveApplicable: active.length,
    backendNotApplicable: actions.length - be.length,
    integratedNotApplicable: actions.length - integrated.length,
  };
  const completed = actions.filter(a => a.frontendStatus === 'verified').length;
  const beCompleted = be.filter(a => a.backendStatus === 'done').length;
  const e2eCompleted = active.filter(a => a.integratedStatus === 'verified-e2e').length;
  return {
    fields: {
      action_count: actions.length,
      family_count: new Set(actions.map(a => a.family)).size,
      active_mvp_action_count: counts.mvp,
      active_e2e_action_count: active.length,
      client_only_mvp_action_count: actions.filter(a => a.scope === 'mvp' && a.backendStatus === 'not-applicable').length,
      backend_applicable_action_count: be.length,
      formal_mvp_gate_action_count: counts['gate-formal-mvp'],
      deferred_post_mvp_action_count: counts['deferred-post-mvp'],
      flutter_only_action_count: counts['flutter-only'],
    },
    summary: 'Conclusão certificada no inventário: Front-end ' + completed + '/' + actions.length +
      ', backend ' + beCompleted + '/' + be.length + ' ações aplicáveis e integração ' +
      e2eCompleted + '/' + active.length + ' ativas (também ' + e2eCompleted + '/' +
      (active.length + formal.length) + ' incluindo o gate formal)',
  };
}

function rewriteTracker(text, data, index, header) {
  const marker = '## Matriz vigente por ação';
  const start = text.indexOf(marker);
  if (start < 0) throw new Error('marcador da matriz ausente');
  const lines = text.slice(start).split('\n');
  const first = lines.findIndex(line => line.startsWith('| '));
  let last = first;
  while (last + 1 < lines.length && lines[last + 1].startsWith('| ')) last++;
  const rebuilt = data.actions.map(a => {
    const cells = index === 2
      ? [a.screen, '`' + a.id + '`', a.scope, a.done, a.fe, a.be, a.integratedStatus, a.evidence]
      : [a.screen, '`' + a.id + '`', a.scope, a.done, index === 0 ? a.fe : a.be, a[layers[index] + 'Status'], a.evidence];
    return '| ' + cells.map(normalize).join(' | ') + ' |';
  });
  const kept = lines.slice(first, first + 2);
  lines.splice(first, last - first + 1, ...kept, ...rebuilt);
  let output = text.slice(0, start) + lines.join('\n');
  for (const [key, value] of Object.entries(header.fields)) {
    output = output.replace(new RegExp('^' + key + ': .*$', 'm'), key + ': ' + value);
  }
  output = output.replace(/Conclusão certificada no inventário: [^.]*\)/, header.summary);
  return output;
}

const argument = process.argv[2];
if (!argument) {
  console.error('uso: node apply-tracker-delta.cjs <deltas.json> | --sync');
  process.exit(2);
}

const data = JSON.parse(fs.readFileSync(inventoryPath, 'utf8'));
if (argument !== '--sync') {
  const deltas = JSON.parse(fs.readFileSync(argument, 'utf8'));
  for (const line of applyDeltas(data, deltas)) console.log('delta: ' + line);
  data.updatedAt = new Date().toISOString();
}
const header = headerFields(data);
fs.writeFileSync(inventoryPath, JSON.stringify(data, null, 2) + '\n');
names.forEach((name, index) => {
  const file = path.join(directory, name);
  fs.writeFileSync(file, rewriteTracker(fs.readFileSync(file, 'utf8'), data, index, header));
});
console.log('inventario e tres rastreadores regenerados; rode validate-trackers.cjs');
