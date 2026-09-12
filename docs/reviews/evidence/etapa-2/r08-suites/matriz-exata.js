const fs = require('fs');
const norm = (v) => String(v || '').replace(/^file:\/\//, '').replace(/\\/g, '/');
function jsonl(file) {
  const suites = new Map(), starts = new Map(), cases = new Set();
  let startCount=0, doneCount=0, executed=0, filtered=0;
  for (const line of fs.readFileSync(file,'utf8').split(/\r?\n/)) {
    if (!line.trim()) continue; let x; try { x=JSON.parse(line); } catch { continue; }
    if (x.type==='suite' && x.suite?.id != null) suites.set(x.suite.id,norm(x.suite.path));
    if (x.type==='testStart' && x.test?.id != null) { startCount++; const name=x.test.name||''; starts.set(x.test.id,{path:norm(x.test.root_url||x.test.url||suites.get(x.test.suiteID)),name,loading:name.startsWith('loading ')}); }
    if (x.type==='testDone' && x.testID != null) { doneCount++; const s=starts.get(x.testID); if(!s||s.loading||x.hidden||x.skipped||!s.path||!s.name){filtered++;continue;} executed++; cases.add(`${s.path} :: ${s.name}`); }
  }
  return {cases,events:executed,duplicateOccurrences:executed-cases.size,unknownLines:[],diagnostics:{testStartEvents:startCount,testDoneEvents:doneCount,executedTestDoneEvents:executed,hiddenOrLoadingDoneEvents:filtered}};
}
function anon(file) {
  const cases=new Set(), unknown=[]; let events=0; const re=/^\d\d:\d\d \+\d+: (.*?\/test\/.*?\.dart): (.+)$/;
  for(const line of fs.readFileSync(file,'utf8').split(/\r?\n/)){const m=line.match(re);if(!m)continue;const p=norm(m[1]),n=m[2];if(n === '' || /^loading [A-Za-z]:\\//.test(n)) continue;events++;cases.add(`${p} :: ${n}`);}
  return {cases,events,duplicateOccurrences:events-cases.size,unknownLines:[],diagnostics:{}};
}
const files={ciclo30:'docs/reviews/evidence/etapa-2/r08-coordenacao/flutter-integrado-ciclo30.jsonl',ciclo60:'docs/reviews/evidence/etapa-2/r08-coordenacao/flutter-integrado-ciclo60.jsonl',ciclo90:'docs/reviews/evidence/etapa-2/r08-coordenacao/flutter-integrado-ciclo90.jsonl',anonimo293:'docs/reviews/evidence/etapa-2/r08-formularios-cuidado-rotina/07-anonymous-tests-final.log'};
const s=Object.fromEntries(Object.entries(files).map(([k,v])=>[k,k==='anonimo293'?anon(v):jsonl(v)])); const names=Object.keys(s); const inter=(a,b)=>[...a].filter(x=>b.has(x)).sort();
const out={generatedAt:new Date().toISOString(),key:'normalized executed test path + full test name, linked by testStart.test.id to testDone.testID',counts:Object.fromEntries(names.map(k=>[k,{observedEvents:s[k].events,uniqueKeys:s[k].cases.size,duplicateOccurrences:s[k].duplicateOccurrences}])),diagnostics:Object.fromEntries(names.map(k=>[k,s[k].diagnostics])),intersections:{},unknownLines:Object.fromEntries(names.map(k=>[k,s[k].unknownLines.length]))};
for(let i=0;i<names.length;i++)for(let j=i+1;j<names.length;j++)out.intersections[`${names[i]}∩${names[j]}`]=inter(s[names[i]].cases,s[names[j]].cases);process.stdout.write(JSON.stringify(out,null,2));

