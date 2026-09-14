// Mechanical projection of the owner table into the two delivery records.
// Never changes inventory certificates: apply-tracker-delta.cjs owns those.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../../..');
const catalog = fs.readFileSync(path.join(__dirname, 'R14-pendencias.md'), 'utf8');
const rows = catalog.split(/\r?\n/).filter(line => /^\| owner\.r12-\d+ \|/.test(line));
if (rows.length !== 53) throw new Error(`Expected 53 owner rows, found ${rows.length}`);
const ownerPath = path.join(__dirname, 'R12-owner-items.json');
const deliveryPath = path.join(root, 'docs/reviews/entrega-atual.json');
const owners = JSON.parse(fs.readFileSync(ownerPath, 'utf8'));
const delivery = JSON.parse(fs.readFileSync(deliveryPath, 'utf8'));
for (const row of rows) {
  const [id, actions, state, evidence, nextGate] = row.split('|').slice(1, -1).map(x => x.trim());
  const [status, fe, be, ...e2e] = state.split(' / ');
  if (!['open', 'partial', 'done', 'deferred'].includes(status) || !fe || !be || !e2e.length) {
    throw new Error(`Invalid row ${id}`);
  }
  const owner = owners.find(item => item.id === id);
  const item = delivery.ownerItems.find(item => item.id === id);
  if (!owner || !item) throw new Error(`Missing record ${id}`);
  const patch = {
    actionIds: actions.includes('gate/') ? [] : actions.split(', '),
    fe, be, e2e: e2e.join(' / '), evidence: evidence.split(';')[0].trim(), nextGate,
  };
  Object.assign(owner, patch, {status});
  // Delivery schema intentionally keeps partially implemented requests open.
  Object.assign(item, patch, {status: status === 'partial' ? 'open' : status});
  for (const source of evidence.split(';').map(value => value.trim()).filter(Boolean)) {
    if (!delivery.evidenceFiles.includes(source)) delivery.evidenceFiles.push(source);
  }
}
delivery.evidenceFiles = [...new Set(delivery.evidenceFiles.flatMap(value =>
  value.split(';').map(source => source.trim()).filter(Boolean)))];
fs.writeFileSync(ownerPath, JSON.stringify(owners, null, 2) + '\n');
fs.writeFileSync(deliveryPath, JSON.stringify(delivery, null, 2) + '\n');
console.log('53 owner rows projected; partial delivery commitments remain open.');
