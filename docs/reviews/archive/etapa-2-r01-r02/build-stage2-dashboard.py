"""Build the C00 measurement view from canonical action records; never certify code."""
from pathlib import Path
import argparse
import collections
import datetime
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
OP = ROOT / 'docs/reviews/etapa-2-operacao'
METRICS = OP / 'reports/R01-fechamento-metricas.json'
INVENTORY = ROOT / 'docs/reviews/inventario-etapa-2.json'
OWNERSHIP = OP / 'assignments/ownership.json'
INTEGRATION = OP / 'reports/R01-fechamento-integracao.json'
OWNER_NAMES = {'C01': 'Identidade e acesso', 'C02': 'Forms, mídia e cuidado', 'C03': 'Operações', 'C04': 'Estruturas e pessoas', 'C05': 'Comunicação e Principal'}
MARKER_START = '<!-- stage2-dashboard:start -->'
MARKER_END = '<!-- stage2-dashboard:end -->'

# Summaries explain existing evidence. Per-action canonical text stays authoritative.
SUMMARIES = {
 'auth': ('Entrada e recuperação', 'Proteções de sessão, recuperação e logout corrigidas.', 'Validar visual/navegação e Auth/SMTP reais; qualificação local I021 pendente.'),
 'shell': ('Navegação e contexto', 'Shell e controles compartilhados receberam correções.', 'Completar navegação, permissões, troca de contexto, foco e regressões do cliente.'),
 'institutions': ('Instituições', 'Diretório, mapa e correções locais existentes.', 'Criação/edição bloqueadas; 25 de 39 strings descartadas na edição; status, arquivos e visuais pendentes.'),
 'units': ('Unidades', 'Formulários e correções de estado existentes.', 'Composição indisponível e 15 RPCs ausentes; mapa/cópia/status e aceites completos.'),
 'groups': ('Turmas', 'Cliente, formulários e leituras locais existentes.', 'Composição, localização, seleção de membros e contagem correta dos resultados de gravação.'),
 'people': ('Pessoas', 'Correções de busca, teclado, dados inventados e identidade integradas.', 'Filtros sem servidor, criação/edição, vínculos e correção de avatar retida.'),
 'access_profiles': ('Perfis de acesso', 'Erros seguros e correlação de perfil/contexto integrados.', 'Atribuição e critérios completos de cliente, autorização e persistência.'),
 'access_models': ('Modelos de acesso', 'Correlação, busca e adiamento de MFA tratados; prova SQL local existente.', 'Concluir critérios visuais, concorrência e provedores reais por ação.'),
 'invites': ('Convites', 'Identidade, busca e descarte de respostas antigas corrigidos.', 'Entrega de convite/SMTP, revogação e negativas reais; aceites visuais restantes.'),
 'activities': ('Atividades', 'Correções de cliente e replay SQL local de 46 assertivas integrados.', 'Composição/adapters candidatos, localização e prova com duas conexões reais.'),
 'assessments': ('Avaliações', 'Recuperação de erros e fila de fechamento corrigidas.', 'Erro no save de configuração, critérios visuais e persistência/negativas reais.'),
 'students': ('Alunos', 'Leitura CHILD e correção de erro do acompanhamento existentes.', 'Vincular, transferir, editar e revogar continuam sem implementação; composição do acompanhamento.'),
 'attendance': ('Assiduidade', 'Correções de lifecycle e controles locais existentes.', 'Critérios reais de chamada, correção, encerramento e isolamento; exportação geral adiada.'),
 'daily_routine': ('Rotina diária', 'Cliente e preservação de paginação existentes.', 'Erro no diretório, composição produtiva e validação das operações reais.'),
 'agenda': ('Agenda', 'Rotas existentes e WIP identificado e preservado.', 'Revisar/integrar WIP, calendário produtivo, comandos, localização e visuais.'),
 'chat': ('Chat', 'Clientes e anexos candidatos; escrita de recibos e contador existentes.', 'Projetar/exibir recibos, editar/revogar, consumidor real de mídia e integração/visuais.'),
 'notices': ('Avisos / Comunicados', 'Cliente e correção de layout compacto integrados.', 'Aceites visuais abertos, agendamento/publicação/arquivo reais e negativas.'),
 'forms_authoring': ('Formulários — editor', 'Editor, galeria e datas civis receberam correções.', 'Mídia de pergunta, limites numéricos/texto, Visão geral/Publicar/Testar/Local e aceites completos.'),
 'forms_responses': ('Formulários — respostas', 'Leituras internas, resposta e XLSX têm lotes implementados/testados.', 'Limites numéricos, WIP de data/texto, respostas com mídia/local, versões e ciclo completo do XLSX.'),
 'forms_files': ('Formulários — arquivos', 'Núcleo comum de upload, reader e parte da composição integrados.', 'Consumidores reais, question-image I021, expiração, exclusão física e órfãos no R2.'),
 'acontece': ('Acontece', 'Cliente, teclado e recuperação de erro integrados; candidatos preservados.', 'Remoção real, mídia/composição e falhas de aceitação visual.'),
 'agora': ('Agora', 'Cliente e recuperação de erro/retry integrados.', 'Composição visual aprovada, expiração, mídia R2/Stream aplicável e reverificação conjunta.'),
 'momentos': ('Momentos', 'Cliente e recuperação de erro integrados; mídia candidata existente.', 'Remoção real, retenção/purga de originais, contrato de mídia e feed real.'),
 'principal_profile': ('Principal — Para Você e perfil', 'Clientes existentes; edição de perfil cobre biografia.', 'Demais campos/contrato de perfil, feed e circulação de dados reais.'),
 'child_safety': ('Segurança infantil', 'Cadeia de correções Safety preservada; executor relata testes locais.', 'Revisar/integrar cadeia completa e validar ações/negações com persistência real.'),
 'health_care': ('Perfis de cuidado', 'Correções locais e contratos existentes.', 'Qualificação care049, permissões internas e CRUD completo comprovado.'),
 'medication': ('Medicação', 'Correções locais preservadas.', 'Fluxos completos, permissões e evidências reais de medicação.'),
 'imports': ('Importações gerais', 'Indisponibilidade honesta prevista no MVP.', 'Implementação real adiada; manter botões e mensagem sem iniciar operação.'),
 'profile_files': ('Arquivos de perfil', 'Importar/exportar têm indisponibilidade do cliente certificada.', 'Demais aceites da indisponibilidade; execução real permanece adiada.'),
 'audit': ('Auditoria', 'Cliente, erros, paginação e bloqueio da exportação geral integrados.', 'SQL Audit ainda 0/145 executados; qualificação real e critérios visuais.'),
 'support': ('Suporte', 'Cliente e status idêntico como operação sem efeito integrados.', 'Contrato produtivo, respostas/fechamento reais e visuais pendentes.'),
 'account': ('Minha conta', 'Preferências locais e correções de logout existentes.', 'Perfil/sessões, aceites visuais e lifecycle; MFA permanece gate formal.'),
 'catalog': ('Catálogo', 'Ferramentas e host existentes; auditoria parcial registrada.', 'Conferir fingerprints/publicação e decidir aplicabilidade real de backend sem inventar provedor.'),
 'plans': ('Planos', 'Cliente e correções de contexto/idempotência existentes.', 'Erro no diretório, identidade 039/051, semântica arquivar/restaurar e vínculos somente leitura.'),
 'meal_plans': ('Cardápios', 'Cliente e recuperação de erro no diretório integrados.', 'Publicação idempotente retida, mídia e operações reais; visuais restantes.'),
 'internal_users': ('Usuários internos', 'Correlação de identidade e descarte de busca antiga integrados.', 'Critérios completos de criação/edição/suspensão; MFA no gate formal.'),
 'error_pages': ('Páginas de erro', 'Telas e ações de erro com provas parciais existentes.', 'Completar mensagens seguras, foco, acessibilidade, retry e contratos aplicáveis.'),
 'locations': ('Locais', 'Pacote seletivo, leitor e correções locais integrados.', 'Ligação nas superfícies, capacidades por ação, filtros, vínculos e agenda/reservas.'),
}

def load(path):
 return json.loads(path.read_text(encoding='utf-8'))

def ratio(n, d, empty='N/A'):
 return f'{n}/{d} — **{100*n/d:.1f}%**'.replace('.', ',') if d else empty

def cell(value):
 return str(value).replace('|', '\\|').replace('\n', ' ')

def table(headers, rows):
 return '\n'.join(['| '+' | '.join(headers)+' |', '| '+' | '.join(['---']*len(headers))+' |'] + ['| '+' | '.join(cell(v) for v in row)+' |' for row in rows])

def main(write=False):
 inv=load(INVENTORY); metric=load(METRICS); ownership=load(OWNERSHIP); integration=load(INTEGRATION)
 actions=inv['actions']; own={a['action_id']:a for a in ownership['actions']}
 all_ids={a['id'] for a in actions}; assert len(actions)==len(all_ids)==len(own)==219
 families=list(dict.fromkeys(a['family'] for a in actions)); assert set(families)==set(SUMMARIES)
 fe=set(metric['frontend_audited_partial_ids']);be=set(metric['backend_union_partial_ids']);sql=set(metric['backend_local_sql_audited_partial_ids'])
 e2e=set(metric['unchanged_historical_certification']['e2e_audited_ids'])
 for ids in [fe,be,sql,e2e]: assert ids<=all_ids
 assert sql<=be
 complete_fe={a['id'] for a in actions if a['frontendStatus']=='verified'}
 complete_be={a['id'] for a in actions if a['backendStatus']=='done'}
 complete_e2e={a['id'] for a in actions if a['integratedStatus']=='verified-e2e'}
 assert complete_fe==set(metric['unchanged_historical_certification']['frontend_completed_ids'])
 active={i for i,a in own.items() if a['classification']=='ativa'}
 applicable_be={i for i,a in own.items() if a['backend_applicable']}
 applicable_e2e={i for i,a in own.items() if a['e2e_applicable'] and a['classification']=='ativa'}
 now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=-3))).isoformat(timespec='seconds')
 rows=[];gaps=[];details=[];records=[]
 for family in families:
  aa=[a for a in actions if a['family']==family];ids={a['id'] for a in aa};fa=ids&active;ba=fa&applicable_be;ea=ids&applicable_e2e
  title,done,missing=SUMMARIES[family]
  classes=collections.Counter(own[i]['classification'] for i in ids)
  zero='Adiado' if classes['adiada']==len(ids) else 'N/A'
  row=[title, ' / '.join(sorted({own[i]['executor'] for i in ids})),done,missing,'Adiado' if zero=='Adiado' else 'Ainda não calculável']
  rows.append(row)
  gaps.append([title,done,missing])
  records.append({'family':family,'name':title,'action_ids':sorted(ids),'classes':dict(classes),'frontend_examined_ids':sorted(ids&fe),'backend_examined_ids':sorted(ids&be),'backend_sql_local_ids':sorted(ids&sql),'integration_exercised_ids':sorted(ids&e2e),'frontend_completed_active_ids':sorted(fa&complete_fe),'backend_completed_active_ids':sorted(ba&complete_be),'e2e_completed_active_ids':sorted(ea&complete_e2e),'frontend_active_denominator':len(fa),'backend_active_denominator':len(ba),'e2e_active_denominator':len(ea),'frontend_completed_deferred_ids':sorted((ids-fa)&complete_fe),'done_summary':done,'missing_summary':missing})
  records[-1]['criteria_approval_percentage']=None
  records[-1]['criteria_percentage_unavailable_reason']='Required criteria and approved evidence are not yet fully reconciled by action and layer.'
  # Every action has its own actual screen label in the inventory (219 total).
  detailrows=[]
  for a in aa:
   i=a['id'];o=own[i];status='Adiada' if o['classification']=='adiada' else 'Gate formal' if o['classification']=='gate formal' else 'Ativa'
   e2e_status=('Exercitada e concluída' if i in complete_e2e else 'Exercitada parcialmente / não concluída' if i in e2e else 'Não exercitada / não concluída') if i in applicable_e2e else 'Adiada' if status=='Adiada' else 'Gate formal' if status=='Gate formal' else 'N/A'
   detailrows.append([f"{a['screen']} (`{i}`)",status,a['done'],a['fe'],a['be'],e2e_status,a['evidence'],a.get('lastEvidenceAt','Sem data nominal')])
   details.append({'action_id':i,'screen':a['screen'],'family':family,'classification':o['classification'],'fe_examined':i in fe,'be_examined':i in be,'e2e_exercised':i in e2e,'fe_completed':i in complete_fe,'be_completed':i in complete_be,'e2e_completed':i in complete_e2e,'frontend_missing':a['fe'],'backend_missing':a['be'],'done':a['done'],'evidence':a['evidence'],'last_evidence_at':a.get('lastEvidenceAt'),'handoff_received_at':a.get('lastHandoffReceivedAt')})
  records[-1]['details_markdown']=f'### {title}\n\n'+table(['Tela / ação','Escopo','Já feito / evidência registrada','Falta no front-end','Falta no back-end','Validação ponta a ponta','Fonte da evidência','Última evidência'],detailrows)
 headers=['Tela / módulo','Frente','Já feito — alcance parcial','O que ainda falta','Percentual dos critérios aprovados']
 numeric=table(headers,rows)
 owner_rows=[];owner_records=[]
 for owner in sorted({o['executor'] for o in own.values()}):
  ids={i for i,o in own.items() if o['executor']==owner};fa=ids&active;ba=fa&applicable_be;ea=ids&applicable_e2e
  owner_rows.append([f'{OWNER_NAMES[owner]} ({owner})',len(fa),'Ainda não calculável','Ver entregas e faltas nas telas abaixo'])
  owner_records.append({'owner':owner,'frontend_approved_ids':sorted(fa&complete_fe),'frontend_active_ids':sorted(fa),'backend_approved_ids':sorted(ba&complete_be),'backend_active_ids':sorted(ba),'e2e_approved_ids':sorted(ea&complete_e2e),'e2e_active_ids':sorted(ea)})
 owner_table=table(['Frente de implementação','Ações ativas atribuídas','Percentual dos critérios aprovados','Onde acompanhar'],owner_rows)
 gaps_md=table(['Tela / módulo','Já entregue (parcial)','Para finalizar'],gaps)
 tests=integration['tests']
 test_rows=[]
 for key,label in [('forms_client','Forms — cliente'),('forms_dto','Forms — conversão de dados'),('forms_domain','Forms — regras de domínio'),('operations_first_batch','Operações — primeiro lote')]:
  result=tests[key]
  test_rows.append([label,result['pass'],result['failed'],'Lote local; não cobre todos os aceites da tela'])
 result=tests['identity_structures_communication_operations']
 test_rows.append(['Identidade + estruturas + comunicação + operações',result['rerun_pass'],result['rerun_failed'],'Reexecução após correção; lote conjunto, não contagem por frente'])
 tests_md=table(['Lote de testes','Passaram','Falharam','Alcance'],test_rows)
 certification=table(['Conclusão completa registrada','Ações aprovadas / ativas aplicáveis'],[
  ['Front-end — todos os aceites do cliente',ratio(len(complete_fe&active),len(active))],
  ['Back-end — todos os aceites dos provedores',ratio(len(complete_be&active),len(active&applicable_be))],
  ['Ponta a ponta — UI normal, backend real, persistência/reload e negativas',ratio(len(complete_e2e&active),len(applicable_e2e))]])
 legend=f"""Apresentação atualizada em **{now}**. Evidências de fechamento: **{integration['generated_at']}**, código `{integration['code_head']}`. Esta atualização explica os registros existentes; não executou novos testes nem aprovou novas ações.

**Houve avanço: existem correções entregues e testes aprovados. O aplicativo ainda tem implementação, integração e validação pendentes.** Leia a tabela por tela para distinguir essas partes.

- **Já feito:** comportamento implementado ou corrigido; quando ainda é candidato/WIP, isso aparece no texto. Os commits efetivamente integrados e publicados estão no [manifesto de integração](etapa-2-operacao/reports/R01-fechamento-integracao.json).
- **Testes que passaram:** prova limitada ao lote e ambiente indicados. Um lote passar não aprova automaticamente a tela inteira.
- **O que falta:** critérios ainda abertos de implementação, integração ou validação. O detalhe separa front-end e back-end por ação.
- **Percentual dos critérios aprovados: ainda não calculável.** Falta reconciliar a lista completa de critérios exigidos com as evidências de aprovação por ação e camada. Não é 0% de implementação. Só poderá chegar a 100% quando todos os critérios do recorte estiverem aprovados.

São **38 famílias de telas e 219 ações**, não 219 testes. Há **194 ações ativas, 22 adiadas e 3 gates formais** (dependem de decisão formal). Das ativas, 187 entram no backend/E2E e 7 não se aplicam ao backend. As contagens históricas de ações examinadas não representam aprovação.

**Como ler os nomes:** E2 = Etapa 2; R01 = rodada 1; C = identificador da conversa. C00 coordena, integra e atualiza as pendências; C01–C05 implementam; C06 coordena operacionalmente as frentes Claude; C07 apoia a validação visual. R02 identificará a próxima rodada. Esses códigos não são percentuais nem quantidades de testes.
"""
 proof_intro=f"Resultados registrados no fechamento de 09/09, ambiente local, código `{integration['code_head']}`. Os lotes podem se sobrepor: não somar seus números para calcular cobertura do app. O lote conjunto teve inicialmente 2 falhas; a reexecução abaixo passou após correção. Logs e hashes estão no [manifesto](etapa-2-operacao/reports/R01-fechamento-integracao.json)."
 cert_intro='Esta é uma medida diferente: conta apenas ações com TODOS os aceites comprovados. Os zeros abaixo são de certificação completa registrada, não de trabalho realizado. Front-end pode ser aprovado sem backend; backend pode ser aprovado sem UI. As 2 aprovações históricas de indisponibilidade de importar/exportar arquivos de perfil estão entre as adiadas e não entram nas ações ativas.'
 common='## Avanço da Etapa 2 — entregas, testes e faltas\n\n'+legend+'\n### Testes aprovados em lotes delimitados\n\n'+proof_intro+'\n\n'+tests_md+'\n\n### Frentes de implementação\n\n'+owner_table+'\n\n### O que foi feito e falta por tela\n\n'+numeric+'\n\n### Certificação completa — medida separada\n\n'+cert_intro+'\n\n'+certification
 panel=common.replace('etapa-2-operacao/reports/','').replace('## Avanço da Etapa 2', '# Avanço da Etapa 2',1)+'\n\n## Detalhe das 219 ações\n\nO registro de trabalho e suas fontes não equivale à aprovação de todos os aceites. A evidência original e sua data permitem conferir o alcance.\n\n'+'\n\n'.join(r.pop('details_markdown') for r in records)
 metadata=f'---\ntitle: "Painel por tela — Etapa 2"\nsource: "inventario-etapa-2.json; assignments/ownership.json; reports/R01-fechamento-metricas.json; reports/R01-fechamento-integracao.json"\nstatus: "derived-measurement; no-new-certification"\ngenerated_at: "{now}"\n---\n\n'
 payload={'source':'canonical inventory + ownership + R01 final metric evidence','status':'deliveries-and-bounded-test-evidence; full-certification-separate','generated_at':now,'percentage_policy':'Criteria approval percentage is unavailable until the full required criteria ledger is reconciled; 100% requires all criteria approved. Known full-action certification counts remain separate.', 'criteria_approval_percentage':None, 'criteria_denominator':None, 'implementation_percentage':None, 'test_batches':tests, 'test_evidence_source':str(INTEGRATION.relative_to(ROOT)), 'test_code_baseline':integration['code_head'], 'test_evidence_at':integration['generated_at'],'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [INVENTORY,OWNERSHIP,METRICS,INTEGRATION]},'historical_review_only':{'frontend_reviewed_count':len(fe),'backend_reviewed_count':len(be),'backend_local_sql_count':len(sql),'integration_exercised_count':len(e2e),'use_as_approval_percentage':False},'totals':{'frontend_approved':len(complete_fe&active),'frontend_active':len(active),'backend_approved':len(complete_be&active),'backend_active':len(active&applicable_be),'e2e_approved':len(complete_e2e&active),'e2e_active':len(applicable_e2e)},'owners':owner_records,'families':records,'actions':details}
 if write:
  (OP/'reports/R01-painel-por-tela.md').write_text(metadata+panel+'\n',encoding='utf-8')
  (OP/'reports/R01-painel-por-tela.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
  for name in ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md']:
   path=ROOT/'docs/reviews'/name;s=path.read_text(encoding='utf-8')
   block=MARKER_START+'\n'+common+'\n'+MARKER_END+'\n\n'
   if MARKER_START in s:s=re.sub(re.escape(MARKER_START)+r'.*?'+re.escape(MARKER_END)+r'\n*',lambda _:block,s,flags=re.S)
   else:s=s.replace('## Matriz vigente por ação\n',block+'## Matriz vigente por ação\n',1)
   path.write_text(s,encoding='utf-8')
 print(json.dumps({'validated':True,'write':write,'families':len(records),'actions':len(details),'totals':payload['totals']},ensure_ascii=False))

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');main(parser.parse_args().write)
