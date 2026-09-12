const fs = require('fs');

function readJsonl(file) {
  const suites = new Map();
  const cases = new Set();
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    if (!line.trim()) continue;
    let item;
    try { item = JSON.parse(line); } catch { continue; }
    if (item.type === 'suite' && item.suite?.id != null) {
      suites.set(item.suite.id, item.suite.path);
    }
    if (item.type === 'testStart' && item.test?.url && item.test.name) {
      const path = item.test.url.replace(/^file:\/\//, '').replace(/\\/g, '/');
      cases.add(`${path} :: ${item.test.name}`);
    }
    if (item.type === 'testStart' && item.test?.suiteID != null && item.test.name && !item.test.name.startsWith('loading ')) {
      const path = suites.get(item.test.suiteID);
      if (path) cases.add(`${path.replace(/\\/g, '/')} :: ${item.test.name}`);
    }
  }
  return { cases, events: cases.size, duplicateOccurrences: 0, unknownLines: [] };
}

function readAnonymous(file) {
  const cases = new Set();
  const unknown = [];
  let events = 0;
  const re = /^\d\d:\d\d \+\d+: (.*?): (.+)$/;
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const match = line.match(re);
    if (!match) continue;
    const path = match[1].replace(/\\/g, '/');
    const name = match[2];
    if (path.includes('/test/')) {
      events++;
      cases.add(`${path} :: ${name}`);
    }
    else unknown.push(line);
  }
  return { cases, events, duplicateOccurrences: events - cases.size, unknownLines: unknown };
}

const inputs = {
  ciclo30: 'docs/reviews/evidence/etapa-2/r08-coordenacao/flutter-integrado-ciclo30.jsonl',
  ciclo60: 'docs/reviews/evidence/etapa-2/r08-coordenacao/flutter-integrado-ciclo60.jsonl',
  ciclo90: 'docs/reviews/evidence/etapa-2/r08-coordenacao/flutter-integrado-ciclo90.jsonl',
  anonimo293: 'docs/reviews/evidence/etapa-2/r08-formularios-cuidado-rotina/07-anonymous-tests-final.log',
};
const sets = {};
for (const [name, file] of Object.entries(inputs)) {
  sets[name] = name === 'anonimo293' ? readAnonymous(file) : (() => {
    const parsed = readJsonl(file);
    return { cases: parsed.cases, events: parsed.events, duplicateOccurrences: parsed.duplicateOccurrences, unknownLines: parsed.unknownLines };
  })();
}
const names = Object.keys(sets);
const intersection = (a, b) => [...a].filter((value) => b.has(value)).sort();
const result = {
  generatedAt: new Date().toISOString(),
  key: 'normalized test path + full test name',
  counts: Object.fromEntries(names.map((name) => [name, {
    observedEvents: sets[name].events,
    uniqueKeys: sets[name].cases.size,
    duplicateOccurrences: sets[name].duplicateOccurrences,
  }])),
  intersections: {},
  unknownLines: Object.fromEntries(names.map((name) => [name, sets[name].unknownLines.length])),
};
for (let i = 0; i < names.length; i++) {
  for (let j = i + 1; j < names.length; j++) {
    const key = `${names[i]}∩${names[j]}`;
    result.intersections[key] = intersection(sets[names[i]].cases, sets[names[j]].cases);
  }
}
process.stdout.write(JSON.stringify(result, null, 2));
