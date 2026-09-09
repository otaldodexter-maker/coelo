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
 inv=load(INVENTORY); metric=load(METRICS); ownership=load(OWNERSHIP)
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
  row=[title,ratio(len(ids&fe),len(ids)),ratio(len(ids&be),len(ids&applicable_be)),ratio(len(ids&e2e),len(ea),zero),ratio(len(fa&complete_fe),len(fa),zero),ratio(len(ba&complete_be),len(ba),zero),ratio(len(ea&complete_e2e),len(ea),zero)]
  rows.append(row)
  gaps.append([title,done,missing])
  records.append({'family':family,'name':title,'action_ids':sorted(ids),'classes':dict(classes),'frontend_examined_ids':sorted(ids&fe),'backend_examined_ids':sorted(ids&be),'backend_sql_local_ids':sorted(ids&sql),'integration_exercised_ids':sorted(ids&e2e),'frontend_completed_active_ids':sorted(fa&complete_fe),'backend_completed_active_ids':sorted(ba&complete_be),'e2e_completed_active_ids':sorted(ea&complete_e2e),'frontend_active_denominator':len(fa),'backend_active_denominator':len(ba),'e2e_active_denominator':len(ea),'frontend_completed_deferred_ids':sorted((ids-fa)&complete_fe),'done_summary':done,'missing_summary':missing})
  # Every action has its own actual screen label in the inventory (219 total).
  detailrows=[]
  for a in aa:
   i=a['id'];o=own[i];status='Adiada' if o['classification']=='adiada' else 'Gate formal' if o['classification']=='gate formal' else 'Ativa'
   e2e_status=('Exercitada e concluída' if i in complete_e2e else 'Exercitada parcialmente / não concluída' if i in e2e else 'Não exercitada / não concluída') if i in applicable_e2e else 'Adiada' if status=='Adiada' else 'Gate formal' if status=='Gate formal' else 'N/A'
   detailrows.append([f"{a['screen']} (`{i}`)",status,'Sim, parcial' if i in fe else 'Sem registro nominal','N/A' if not o['backend_applicable'] else 'Sim, parcial' if i in be else 'Sem registro nominal','Concluído'+(' (indisponibilidade adiada)' if status=='Adiada' else '') if i in complete_fe else 'Pendente','N/A' if not o['backend_applicable'] else 'Concluído' if i in complete_be else status if status!='Ativa' else 'Pendente',e2e_status,a['fe'],a['be']])
   details.append({'action_id':i,'screen':a['screen'],'family':family,'classification':o['classification'],'fe_examined':i in fe,'be_examined':i in be,'e2e_exercised':i in e2e,'fe_completed':i in complete_fe,'be_completed':i in complete_be,'e2e_completed':i in complete_e2e,'frontend_missing':a['fe'],'backend_missing':a['be'],'done':a['done'],'evidence':a['evidence'],'last_evidence_at':a.get('lastEvidenceAt'),'handoff_received_at':a.get('lastHandoffReceivedAt')})
  records[-1]['details_markdown']=f'### {title}\n\n'+table(['Tela / ação','Escopo','FE examinado','BE examinado','FE concluído','BE concluído','Integração real / E2E','Falta no cliente','Falta no backend'],detailrows)
 headers=['Tela / módulo','FE examinado','BE examinado','Integração exercitada','FE concluído¹','BE concluído¹','E2E concluído¹']
 numeric=table(headers,rows)
 gaps_md=table(['Tela / módulo','Já entregue (parcial)','Para finalizar'],gaps)
 legend=f'''Cálculo conferido em **{now}** a partir de IDs únicos e evidências de R01. Sem novos testes ou certificações nesta apresentação. [IDs, denominadores e faltas por ação](etapa-2-operacao/reports/R01-painel-por-tela.json).

**Examinado = pelo menos um critério revisado ou testado**, inclusive com falha; não significa todos os testes executados. O BE inclui análise estática e20ações com SQL local dentro das63 examinadas. **Integração exercitada** conta tentativas registradas pela UI normal com backend real, mesmo se falharem; não é merge de Git. No registro atual,0/187. Ausência de registro não prova ausência de código ou que ninguém nunca abriu a tela.

**FE concluído** = todos os critérios próprios do cliente. **BE concluído** = todos os critérios e provedores próprios do backend. **E2E concluído** = UI normal + backend real + persistência/reload + negativas aplicáveis. E2E é o nome da cadeia completa, não um segundo nome para concluir uma camada isolada.

¹ Colunas de conclusão mostram apenas ações **ativas**: FE0/194, BE0/187, E2E0/187. A auditoria mantém os denominadores totais FE219 eBE212 para comparação com o fechamento. Há22adiadas e3gates formais separados;7açõesN/A ao backend. As únicas2certificações FE históricas são a indisponibilidade de `profile-files.import/export`, ambas adiadas; não aumentam a conclusão ativa. N/A não é0%; Adiado não é concluído.

Uma linha agrega uma família de telas/ações. São **38 famílias e219ações/superfícies**, não38testes. O detalhe de cada ação, inclusive o que falta, está no [painel completo](etapa-2-operacao/reports/R01-painel-por-tela.md) e na matriz oficial abaixo. Os contadores não medem percentual de código incorporado em Git: commits selecionados/publicação estão nos manifestos de integração; WIP/candidatos preservados podem ainda estar fora de dev.
'''
 panel='# Painel por tela da Etapa 2\n\n'+legend.replace('etapa-2-operacao/reports/','')+'\n## Exame e conclusão por tela\n\n'+numeric+'\n\n## O que falta em cada tela\n\n'+gaps_md+'\n\n## Todas as219ações/superfícies\n\nCada ação possui critério próprio. Nos IDs individuais, “Sim” equivale a1/1na presença de alguma auditoria, não100%dos critérios; por isso o detalhe usa texto para evitar essa confusão. Fontes e datas estão no JSON correspondente e na matriz de pendências.\n\n'+'\n\n'.join(r.pop('details_markdown') for r in records)
 metadata=f'---\ntitle: "Painel por tela — Etapa 2"\nsource: "inventario-etapa-2.json; assignments/ownership.json; reports/R01-fechamento-metricas.json"\nstatus: "derived-measurement; no-new-certification"\ngenerated_at: "{now}"\n---\n\n'
 payload={'source':'canonical inventory + ownership + R01 final metric evidence','status':'derived-measurement; no-new-certification','generated_at':now,'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [INVENTORY,OWNERSHIP,METRICS]},'totals':{'frontend_examined':len(fe),'frontend_applicable':len(all_ids),'backend_examined':len(be),'backend_applicable':len(applicable_be),'backend_local_sql':len(sql),'integration_exercised':len(e2e),'frontend_completed_active':len(complete_fe&active),'frontend_active':len(active),'backend_completed_active':len(complete_be&active),'backend_active':len(active&applicable_be),'e2e_completed_active':len(complete_e2e&active),'e2e_active':len(applicable_e2e)},'families':records,'actions':details}
 if write:
  (OP/'reports/R01-painel-por-tela.md').write_text(metadata+panel+'\n',encoding='utf-8')
  (OP/'reports/R01-painel-por-tela.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
  common='## Painel por tela — exame e conclusão separados\n\n'+legend+'\n'+numeric+'\n\n### Entregas parciais e trabalho restante\n\n'+gaps_md
  for name in ['coelo-flutter-pendencias.md','coelo-supabase-pendencias.md','coelo-flutter-integrado-supabase-pendencias.md']:
   path=ROOT/'docs/reviews'/name;s=path.read_text(encoding='utf-8')
   block=MARKER_START+'\n'+common+'\n'+MARKER_END+'\n\n'
   if MARKER_START in s:s=re.sub(re.escape(MARKER_START)+r'.*?'+re.escape(MARKER_END)+r'\n*',lambda _:block,s,flags=re.S)
   else:s=s.replace('## Matriz vigente por ação\n',block+'## Matriz vigente por ação\n',1)
   path.write_text(s,encoding='utf-8')
 print(json.dumps({'validated':True,'write':write,'families':len(records),'actions':len(details),'totals':payload['totals']},ensure_ascii=False))

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true');main(parser.parse_args().write)
