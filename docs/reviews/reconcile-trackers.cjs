// One-time mechanical migration from 19b8f574. Do not replay after manual tracker
// updates: it intentionally reconstructs this audit, not future operational state.
const fs = require('node:fs');
const cp = require('node:child_process');
const base = '19b8f574';
const dir = 'docs/reviews';
const names = ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md'];
const original = names.map(n => cp.execFileSync('git',['show',`${base}:${dir}/${n}`],{encoding:'utf8',maxBuffer:8e6}));
const cells = line => line.split('|').slice(1,-1).map(s=>s.trim());
const unquote = s => s.replaceAll('`','');
const front = original[0].split('\n').filter(l=>/^\| \d+\.\d+ \|/.test(l)).map(cells);
const back = original[1].split('\n').filter(l=>/^\| \d+ \| `[^`]+` \| `[^`]+` \|/.test(l)).map(cells).filter(c=>c.length===12);
const combined = original[2].split('\n').filter(l=>/^\| \d+ \| `[^`]+` \| `[^`]+` \|/.test(l)).map(cells).filter(c=>c.length===16);
if(front.length!==219||back.length!==219||combined.length!==219) throw Error(`Unexpected rows ${front.length}/${back.length}/${combined.length}`);
const index = rows => new Map(rows.map(c=>[unquote(c[2]),c]));
const bm=index(back), im=index(combined);
const deferred = new Set(['institutions.import','institutions.export','units.import','units.export','units.people-export','groups.import','groups.export','attendance.export','audit.export',...['list','create','upload','preview','confirm','status','download'].map(x=>'imports.'+x),...['import','preview','confirm','status','export','download'].map(x=>'profile-files.'+x)]);
const mfa = new Set(['auth.mfa','account.mfa','internal-users.mfa']);
const clientOnly = new Set(['account.settings','account.theme']);
const overrides = JSON.parse(fs.readFileSync(`${dir}/tracker-corrections-2026-09-08.json`,'utf8'));
function clean(s) {
  return s.replace(/R2 está fora do MVP\.?/gi,'R2 privado é o master do MVP (ADR 0032).')
    .replace(/Supabase Storage|\bStorage\b/g,'R2 privado')
    .replace(/OQ-003\/OQ-040/g,'decisões clínicas específicas')
    .replace(/com MFA\/capability/g,'com capability e AAL conforme ADR 0019')
    .replace(/MFA\/capability/g,'AAL vigente/capability')
    .replace(/exigir.*MFA/gi,'respeitar AAL vigente')
    .replace(/\|/g,'/').replace(/\r/g,'');
}
const actions=front.map(f=>{
  const id=unquote(f[2]), b=bm.get(id), i=im.get(id);
  if(!b||!i) throw Error('Missing crosswalk '+id);
  const family=unquote(i[1]);
  const o={...(overrides.families[family]||{}),...(overrides.actions[id]||{})};
  const scope=id.startsWith('shell.')?'flutter-only':deferred.has(id)?'deferred-post-mvp':mfa.has(id)?'gate-formal-mvp':'mvp';
  let fe=o.fe||`Revalidar o aceite específico desta ação: ${clean(f[11])}`;
  if(family==='principal_profile') fe='Concluir aceites das rotas existentes no Superadmin. Não criar apps/principal. Circulares não possui IDs próprios neste inventário: cruzar subtelas com principal_profile e fontes aprovadas antes de declarar cobertura integral.';
  let be=o.be||`Conferir a implementação e fechar o aceite backend desta ação: ${clean(b[11])}`;
  let done=o.done||'Aceite integral não certificado. Consultar evidência anterior antes de implementar ou repetir testes.';
  if(scope==='deferred-post-mvp') {done=o.done||'Operação real adiada por decisão do Owner (ADR 0032).';fe='Conferir botão visível e mensagem de indisponibilidade; nenhuma chamada de arquivo/job. Não implementar a operação real nesta rodada.';be='Operação real fora do MVP. Preservar legado sem executar, remover ou habilitar jobs.';}
  if(scope==='gate-formal-mvp') {done='MFA interno adiado pela ADR 0019, aditivo de 01/09; AAL1 é aceito no MVP, inclusive Owner.';fe='Preservar UX honesta e sessão AAL1. No encerramento formal do MVP, retomar a reativação nominal de MFA.';be='Preservar política AAL1 vigente. Reativação de MFA é gate formal, não bloqueio técnico das telas atuais.';}
  if(scope==='flutter-only') be='Sem endpoint ou tabela próprios exigidos; depende transversalmente da sessão/contexto.';
  if(clientOnly.has(id)) be='Preferência local do cliente; nenhuma tabela, RPC ou persistência remota pertence a esta ação.';
  return {id,family,screen:f[1],scope,done,fe,be,evidence:o.evidence||`archive/2026-09-08/${names[0]} (buscar ${id}); archive/2026-09-08/${names[1]} (buscar ${id})`,historicalFrontend:unquote(f[4]),historicalBackend:unquote(b[4]),frontendStatus:'pending-verification',backendStatus:scope==='flutter-only'||clientOnly.has(id)?'not-applicable':scope==='deferred-post-mvp'?scope:scope==='gate-formal-mvp'?scope:'pending-verification',integratedStatus:clientOnly.has(id)?'flutter-only':scope==='mvp'?'pending-verification':scope};
});
if(new Set(actions.map(a=>a.id)).size!==219) throw Error('Duplicate action');
const counts={}; for(const a of actions) counts[a.scope]=(counts[a.scope]||0)+1;
if(counts.mvp!==189||counts['deferred-post-mvp']!==22||counts['gate-formal-mvp']!==3||counts['flutter-only']!==5) throw Error(JSON.stringify(counts));
const layerCounts={frontendApplicable:219,backendApplicable:212,integratedActiveApplicable:187,backendNotApplicable:7,integratedNotApplicable:7};
const archive=`${dir}/archive/2026-09-08`;
fs.mkdirSync(archive,{recursive:true});
names.forEach((n,k)=>{const p=`${archive}/${n}`;if(fs.existsSync(p)&&fs.readFileSync(p,'utf8')!==original[k]) throw Error('Archive changed');fs.writeFileSync(p,original[k]);});
const common=`Base auditada: dev ${base}, com correções documentais por código e evidências registradas até 08/09. Somente apps/superadmin e dependências da Etapa 2.\n\nEste é o estado operacional atual. O histórico integral anterior está em [arquivo de 08/09](archive/2026-09-08/). As classificações antigas foram preservadas no inventário JSON como históricas; não representam testes executados nesta revisão.\n\n- 219 action_ids únicos, 38 famílias: 189 ações no escopo ativo desta fase do MVP, das quais 187 usam backend/E2E e duas são preferências locais do cliente; há ainda três ações MFA no gate formal, 22 operações de import/export adiadas e cinco ações de shell somente Flutter. Nenhum item adiado foi contado como concluído.\n- Conclusão certificada no inventário: Front-end 0/219, backend 0/212 ações aplicáveis e integração 0/187 ativas (também 0/190 incluindo o gate formal). \`account.settings\`, \`account.theme\` e as cinco ações de shell são não aplicáveis ao backend/integrado. Zero certificado não significa zero implementado. Não há percentual confiável do trabalho implementado: 104/219 local-green e 3/38 famílias eram classificações históricas sem reauditoria integral de aceites.\n- pending-verification significa aceite completo ainda não certificado; não significa refazer o que está na coluna Feito. Abrir os commits/evidências antes de alterar código.\n- R2 privado é master; Supabase mantém catálogo, permissões e auditoria. Stream é cópia HOT seletiva conforme ADR 0032; Agora até 24 h. XLSX de todas as respostas do formulário é a única exportação real do MVP.\n- /dev usa fixtures; sem /dev usa composição produtiva. Todo remoto é produção. MFA interno aceita AAL1 conforme ADR 0019. Admin, Principal e Site estão fora deste recorte de implementação.\n- ETA por ação: ainda não recalculada por dependências e execução; não somar estimativas antigas. A janela 36–60 h do plano anterior não é compromisso validado.\n\n`;
const summary=`## Pacotes preservados e gates transversais\n\n- Agenda: reader f8a04b3a/controller 4daeafb9 integrados. View ca4c82ab preservado; tentativa bbb9379d revertida por fe6f6b51 após quatro diferenças golden. Corrigir somente o delta visual antes de reintegrar.\n- Forms: f84d1dd7 preservado fora de dev; execução anterior terminou +101/-1 no caso duplicate-dependent (102 casos). O log anterior 100/101 estava incorreto. Reproduzir no runner correto antes de concluir causa.\n- Preflight Forms 97769124 fora de dev: execução anterior +48/-23; conferir versão PowerShell/Pester e evidência do runner antes de atribuir defeitos ao script. Locais 9e689374: zero casos descobertos naquela execução não certifica nem reprova SQL.\n- Backend: replays nominais, catálogo/ledger, RLS/grants, auditoria, concorrência, runtime HTTP e cleanup continuam gates por pacote; nenhum novo replay ou deploy foi executado nesta revisão documental. Advisors antigos não são estado remoto fresco.\n- R2: inventário nominal, gateway/decoder, upload/read, autorização atual, checksum, TTL, revogação e cleanup por finalidade.\n- Decisões específicas abertas ficam em docs/open-questions.md; não usar números OQ antigos por analogia. Os gates gerais anteriores SUP-GEN/INT-GEN estão preservados nos arquivos históricos e continuam sujeitos a revisão por pacote.\n\n`;
function header(k){return `---\ntitle: "Pendências Coelo — ${['Front-end','Back-end','Front-end + Back-end'][k]}"\nsource: "AGENTS.md; ADR 0019; ADR 0032; tracker-corrections-2026-09-08.json; inventario-etapa-2.json"\nstatus: "open"\ngenerated_at: "2026-09-08"\nupdated_at: "2026-09-08"\naction_count: 219\nfamily_count: 38\nactive_mvp_action_count: 189\nactive_e2e_action_count: 187\nclient_only_mvp_action_count: 2\nbackend_applicable_action_count: 212\nformal_mvp_gate_action_count: 3\ndeferred_post_mvp_action_count: 22\nflutter_only_action_count: 5\n---\n\n# Pendências Coelo — ${['Front-end','Back-end','Front-end + Back-end'][k]}\n\n`;}
for(let k=0;k<3;k++) {
  let body=header(k)+common+summary.replace('execução anterior +48/-23; conferir versão PowerShell/Pester e evidência do runner antes de atribuir defeitos ao script. Locais 9e689374: zero casos descobertos naquela execução não certifica nem reprova SQL.', 'execução central anterior +48/-23, mas a evidência do autor registra 71/71 sob Pester 3.4.0. Reconciliar versões e invocação antes de atribuir defeitos ao script. Locais 9e689374: Test-LocationRemoteSnapshot.Tests.ps1 contém assertions no nível superior, não casos Pester. Executar diretamente como script PowerShell; zero descobertas via Pester foi invocação inadequada, não defeito comprovado de Locais. A checagem é estática e não substitui replay SQL nominal.');
  body=body.replace('189 ações executáveis nesta fase do MVP','189 ações no escopo ativo desta fase do MVP, algumas ainda dependentes de decisão ou evidência');
  body+='## Matriz vigente por ação\n\n';
  body+= k===2?'| Família / tela / subtela | action_id | Escopo | Feito e limite da prova | Próximo passo Front-end | Próximo passo Back-end | Estado E2E | Fonte |\n|---|---|---|---|---|---|---|---|\n':'| Família / tela / subtela | action_id | Escopo | Feito e limite da prova | Pendência desta camada | Estado | Fonte |\n|---|---|---|---|---|---|---|\n';
  for(const a of actions) {
    const source=a.evidence;
    const c=k===2?[`${a.family} / ${a.screen}`,a.id,a.scope,a.done,a.fe,a.be,a.integratedStatus,source]:[`${a.family} / ${a.screen}`,a.id,a.scope,a.done,k===0?a.fe:a.be,k===0?a.frontendStatus:a.backendStatus,source];
    body+='| '+c.map(clean).join(' | ')+' |\n';
  }
  body+='\n## Regra de encerramento\n\nFront-end exige seus aceites de UI, estados, composição e regressão. Back-end exige os provedores aplicáveis, autorização, persistência, negativas e auditoria. E2E exige a mesma ação pela UI real, reload, tenant A/B e revogação. Só promover a linha com evidência nominal.\n';
  fs.writeFileSync(`${dir}/${names[k]}`,body);
}
fs.writeFileSync(`${dir}/inventario-etapa-2.json`,JSON.stringify({sourceCommit:base,generatedAt:'2026-09-08',counts,layerCounts,actions},null,2)+'\n');
console.log(JSON.stringify({actions:actions.length,counts,files:names}));
