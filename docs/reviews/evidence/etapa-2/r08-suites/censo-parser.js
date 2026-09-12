#!/usr/bin/env node
const fs = require('fs');
const args = Object.fromEntries(process.argv.slice(2).reduce((a, v, i, xs) => { if (v.startsWith('--')) a.push([v.slice(2), xs[i + 1]]); return a; }, []));
if (!args.input || !args.output || args.base == null || args['exit-code'] == null) { console.error('usage: node censo-parser.js --input FILE --output FILE --base SHA --exit-code N'); process.exit(2); }
const repoMarker = '/apps/superadmin/';
const pathRel = (v) => { const p = String(v || '').replace(/^file:\/\//, '').replace(/\\/g, '/'); const i = p.indexOf(repoMarker); return i >= 0 ? p.slice(i + 1) : p; };
const suites = new Map(), starts = new Map(), cases = [], orphanDone = [], unknown = [], counts = { passed: 0, failed: 0, skipped: 0, hidden: 0, loading: 0, errors: 0 };
for (const line of fs.readFileSync(args.input, 'utf8').split(/\r?\n/)) {
  if (!line.trim() || line.startsWith('nativeExitCode=')) continue;
  let x; try { x = JSON.parse(line); } catch { unknown.push({ raw: line }); continue; }
  if (x.type === 'suite' && x.suite?.id != null) suites.set(x.suite.id, { id: x.suite.id, path: pathRel(x.suite.path) });
  if (x.type === 'testStart' && x.test?.id != null) {
    const suite = suites.get(x.test.suiteID); const name = x.test.name || ''; const loading = suite && name === `loading ${x.test.url || suite.path}`;
    starts.set(x.test.id, { testID: x.test.id, suiteID: x.test.suiteID, path: pathRel(x.test.root_url || x.test.url || suite?.path), name, metadata: x.test.metadata || {}, loading });
  }
  if (x.type === 'error') { counts.errors++; unknown.push({ type: 'error', error: x.error || x }); }
  if (!['start','suite','allSuites','group','print','testStart','testDone','error'].includes(x.type)) unknown.push({ type: x.type, raw: x });
  if (x.type === 'testDone') {
    const start = starts.get(x.testID); if (!start) { orphanDone.push({ testID: x.testID, result: x.result }); continue; }
    const row = { testID: start.testID, suiteID: start.suiteID, path: start.path, name: start.name, result: x.result, skipped: Boolean(x.skipped), hidden: Boolean(x.hidden), loading: Boolean(start.loading), metadata: start.metadata };
    if (row.loading) counts.loading++; else if (row.hidden) counts.hidden++; else if (row.skipped || row.metadata.skip) counts.skipped++; else if (row.result === 'success') counts.passed++; else counts.failed++;
    cases.push(row);
  }
}
const report = { schemaVersion: 1, generatedAt: new Date().toISOString(), base: args.base, nativeExitCode: Number(args['exit-code']), input: args.input, counts, cases, orphanDone, unknown };fs.writeFileSync(args.output, JSON.stringify(report, null, 2) + '\n');console.log(JSON.stringify({ base: report.base, nativeExitCode: report.nativeExitCode, counts: report.counts, cases: report.cases.length, orphanDone: report.orphanDone.length, unknown: report.unknown.length }));





