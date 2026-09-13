"""Project the current inventory into a per-action handoff; no status promotion."""
from pathlib import Path
from collections import defaultdict
from datetime import datetime, timezone
import json

ROOT = Path(__file__).resolve().parents[5]
INV = ROOT / 'docs/reviews/inventario-etapa-2.json'
OUT = ROOT / 'docs/reviews/etapa-2-operacao/next-round/R10-estado-por-tela.md'
data = json.loads(INV.read_text(encoding='utf-8'))
gates = {}

def gate(ids, fe, be, e2e):
    for action in ids.split():
        gates[action] = (fe, be, e2e)

gate('auth.recover auth.reset', 'Aceite FE preservado.',
     'Conferir pacote Auth vigente e provar entrega SMTP, expiração/uso único do link e nova sessão. Não reabrir trabalho de senha neste pedido documental.',
     'Recuperar/redefinir pela rota normal com credencial sintética e sem expor tokens.')
gate('shell.switch-context', 'Provar troca pela rota normal com contexto autorizado e estado recarregado.',
     'Sem endpoint próprio; depende da sessão e do contexto.', 'Aceite cliente ainda pendente; não é nova implementação presumida.')
gate('institutions.status', 'Ativar/desativar, cancelar e reler estado pela interface.',
     'Validar transição autorizada, conflitos e auditoria no contrato vigente.', 'Estado persistido, reload e negativa de escopo.')
gate('institutions.files', 'Concluir consumidor de arquivos, estados e fluxo pela interface.',
     'Conferir gateway/R2 privado, MIME/limites, ownership, reautorização e retenção.', 'Upload/leitura/reload e negação real no domínio Instituições.')
gate('institutions.error units.error', 'Provocar erro real e provar mensagem segura, retry e ausência de sucesso falso.',
     'Contrato já existe; conferir negativa/envelope e idempotência atuais.', 'Falha e recuperação pela rota normal.')
gate('institutions.access-denied units.access-denied', 'Provar acesso negado sem dados residuais ou ações indevidas.',
     'Reutilizar negativas válidas com paridade atual de sessão/capacidade/escopo.', 'Rota normal/deep link negado, sem vazamento.')
gate('institutions.locations-map', 'Selecionar Local autorizado, abrir mapa/detalhe e recarregar vínculo.',
     'Contrato de Locais existente; provar associação institucional, ownership e escopo.', 'Não inferir da prova de Local da unidade ou turma.')
gate('access-profiles.edit', 'Aceite FE preservado.', 'Aceite BE preservado.', 'Salvar edição pela UI, reler e conferir negativa pertinente.')
gate('access-profiles.assign', 'Atribuir perfil no fluxo de usuário interno e reler o resultado.',
     'Aceite BE existente; atribuição usa profile_id do comando de usuário interno.', 'Prova própria de atribuição; listagem não basta.')
gate('invites.resend', 'Reenviar convite expirado pela UI e conferir resultado/reload.',
     'Contrato aceita expirado, não convite pending vigente; preparar contexto sintético válido.', 'Recibo de reenvio sem divulgar link ou token.')
gate('activities.publish', 'Provar salvar/publicar no estado correto, sem travar retry ou rascunho.',
     'Publicação já provada no BE; conferir paridade do contrato existente.', 'Publicar pela UI normal e reler estado ativo.')
gate('activities.assessment', 'Layout/read-by-id corrigidos; salvar UPDATE do mesmo draft ainda falha.',
     'Diagnosticar SAI_INTERNAL_ERROR em produção com dados sanitizados; payload/replay local passaram. Aceite BE histórico não certifica esse UPDATE.',
     'Salvar e recarregar o draft retido; não criar outro para contornar.')
gate('assessments.entry assessments.gradebook assessments.detail',
     'Exibir aluno elegível, lançar resultado e abrir detalhe/diário com reload.',
     'Reconciliar activity_group_participants e snapshot do diário retido. Contexto/unidade/turma já estão ativos.',
     'Nota persistida pelo repository real, escopo negado e reload; sem recriar diário/configuração.')
gate('assessments.close assessments.reopen', 'Executar fechamento e reabertura após diário válido.',
     'Provar transições, versão, autorização e auditoria no diário existente.', 'Depende de participante e nota persistida; ainda não executado.')
gate('chat.create-group', 'Aceite FE preservado.', 'Aceite BE preservado.', 'Criar grupo pela UI e confirmar membros, lista/reload e escopo.')
gate('chat.attach', 'Fotos inline provadas; falta upload MP4 real e play/pause/reload pela UI.',
     'SQL61 e Edge implantados, R2 privado confirmado; completar prova MP4 da cadeia de mídia e negativas.',
     'Desbloquear picker pelo canal suportado; não injetar arquivos nem alterar segurança global.')
gate('circulars.attach', 'Executar picker, upload, anexo no compositor e reload.',
     'Cadeia R2 já possui provas; conferir paridade/negativas atuais do consumidor.', 'Picker bloqueado pela permissão fileURLs da extensão.')
gate('forms.location-answer', 'Responder item Local publicado em ocorrência válida e recarregar.',
     'Provar Local autorizado, participação/ocorrência, persistência e negativa de escopo.', 'Decisão de Local já resolvida; não aguarda nova decisão do Owner.')
gate('forms.upload forms.resolve-file', 'Upload/download/reabertura pela UI; cobrir os modos Foto/câmera e anônimo pertinentes.',
     'BE done com cadeia e lote60; preservar prova de ownership/reautorização/TTL.', 'Picker e consumidor real ainda pendentes; API isolada não fecha UI.')
gate('forms.expire-file forms.delete-file', 'Mostrar expiração/remoção e impedir acesso após reload.',
     'Verificar execução vigente de expiração e limpeza física R2, retenção e auditoria; não reaplicar lotes existentes.',
     'Estado terminal e arquivo indisponível pela UI, sem órfão acessível.')
gate('acontece.create', 'Criar com mídia na tela reconstruída e recarregar.', 'BE done; reutilizar cadeia vigente de mídia e escopo.', 'Prova nova do compositor atual; aprovação do compositor antigo não basta.')
gate('agora.view momentos.view', 'Aceite FE preservado.', 'Aceite BE preservado.', 'Visualizar publicação real com mídia/contexto no host atual e reload.')
gate('agora.create agora.publish momentos.create momentos.publish',
     'Criar/publicar com mídia privada no compositor atual e recarregar.',
     'Fundação existente; confirmar implantação vigente, ativo real, autorização e consumidor. Não redeployar só por nota histórica.',
     'Picker suportado e cadeia real completa; mocks não certificam publicação.')
gate('agora.expire', 'Provar desaparecimento/estado expirado após reload.',
     'Cron já registrado; verificar execução e transição real. Recurso retido vence 13/09/2026 12:24:39 BRT.',
     'Conferir relógio na retomada; nunca antecipar expires_at nem usar TTL da URL como prova.')
gate('momentos.remove', 'Retirar publicação real e reler feed/estado.',
     'Correção lote58 já aplicada; provar consumidor e negativa pertinente, sem reaplicar.', 'Autor autorizado, retirada persistida e reload no host atual.')
gate('principal.for-you', 'Aceite FE preservado; CTA depende do contrato.',
     'Conciliar pendência H13 de Comunicação com a ponte de contexto existente.', 'Provar conteúdo autorizado após decisão, sem refazer P17/P35.')
gate('principal.profile-edit', 'Salvar Sobre e recarregar no sujeito/contexto autorizado.',
     'Provar escrita de Sobre; H02 de dados oficiais exige decisão nominal.', 'Sobre é gate independente; não bloquear por toda a decisão H02.')
gate('catalog.list catalog.validate catalog.sync catalog.publish',
     'Conferir exemplos/índice, validação/sincronização e publicação no destino canônico; preservar aceites FE já registrados.',
     'Definir e conferir provedor/destino, acesso e publicação. Supabase N/A não torna todo BE N/A.',
     'Destino e contrato existentes, validação atual e prova da ação publicada; sem inventar infraestrutura.')
gate('errors.403 errors.404 errors.409 errors.500 errors.503 errors.retry',
     'Aceite FE existente preservado; verificar comportamento no erro real da ação.',
     'Provar resposta segura do backend, escopo, minimização e conflito/falha conforme o código.',
     'Acionar erro/retry real na rota normal, sem vazamento nem sucesso falso.')
gate('plans.assign', 'Conciliar ação com contrato aprovado; não criar atribuição por inferência.',
     'Decisão nominal de atribuição; sem cobrança ou escrita fora da spec051.', 'Owner define contrato antes da implementação.')

def pending(a):
    return a['frontendStatus'] != 'verified' or a['backendStatus'] not in ('done','not-applicable') or a['integratedStatus'] not in ('verified-e2e','flutter-only')

def safe(value):
    return str(value).replace('|','/').replace('\n',' ').strip()

families=defaultdict(list)
for action in data['actions']:
    families[action['family']].append(action)
lines=['---','source: docs/reviews/inventario-etapa-2.json; R10-fechamento.md; R10-pendencias.md',
       'status: revisão documental pós-R10; sem nova certificação funcional',
       'generated_at: 2026-09-13','---','', '# Estado por tela e subtela após R10','',
       'Recorte: Etapa 2, apps/superadmin, incluindo Coelo (Principal) hospedado. '
       'Admin, Principal independente e Site não foram auditados. Base de produto c8c38e28b; '
       'esta projeção cobre todos os 231 action_ids conhecidos, sem inventar telas fora do inventário.','',
       'Verified/done são aceites já registrados, não testes repetidos hoje. Pending-verification '
       'não significa código inexistente. Local-green significa implementação/prova local sem '
       'aceite final. As pendências de FE, BE e E2E são separadas; não somar camadas.','',
       'Avanço R10: 177/231 FE, 162/224 BE e 150/199 E2E. As ações completas aparecem '
       'com “sem pendência funcional registrada”, limitado à régua MVP e evidência histórica. '
       'Aprovação visual e revisão profunda de segurança permanecem separadas.','',
       '## Correções e ressalvas que não geram novo action_id','',
       '- Filtros Origem/Periodicidade, espaçamento, Editar atividade, abertura do detalhe, '
       'fotos inline e identidade do cabeçalho foram corrigidos. Cabeçalho provado com duas identidades/reload.',
       '- groups.list: lista/navegação aceitas, mas contadores Alunos/Atividades do card seguem '
       'incorretos. FE: corrigir projeção/renderização; BE: conferir origem das contagens e vínculos.',
       '- access-profiles.delete: CRUD sem atribuições aceito. Realocação com atribuições não foi '
       'exercitada; seis divergências da suíte histórica de perfis e 16 ocorrências do validador visual continuam registradas.',
       '- Flutter foi servido localmente; push em dev não equivale a deploy público. SQL61–63 e Edge chat-media implantados.','',
       '## Resumo por família','',
       '| Família | FE aceito/ações | BE aceito/aplicável | E2E aceito/MVP aplicável | Ações com gate aberto |',
       '|---|---:|---:|---:|---:|']
for family, actions in families.items():
    fe=sum(a['frontendStatus']=='verified' for a in actions)
    be=[a for a in actions if a['backendStatus']!='not-applicable']
    e2e=[a for a in actions if a['scope']=='mvp' and a['integratedStatus']!='flutter-only']
    lines.append(f"| {family} | {fe}/{len(actions)} | {sum(a['backendStatus']=='done' for a in be)}/{len(be)} | {sum(a['integratedStatus']=='verified-e2e' for a in e2e)}/{len(e2e)} | {sum(pending(a) for a in actions)} |")
lines+=['','## Todas as telas e subtelas','',
        'O action_id preserva o vínculo com as três matrizes e suas evidências. Responsável '
        'por implementação/prova: C0 com técnico focal. Gates de decisão: Owner. Permissão '
        'da extensão: operador do navegador; C0 executa a prova depois de liberada.','']
for family, actions in families.items():
    lines += [f'### {family}', '', '| Tela/subtela e action_id | Estados FE / BE / E2E | Falta no FE | Falta no BE | Próximo gate integrado |', '|---|---|---|---|---|']
    for a in actions:
        if a['scope']=='deferred-post-mvp':
            tasks=('Manter botão visível e indisponibilidade honesta; aceite FE já registrado se verified.',
                   'Operação real adiada; não implementar importação/exportação agora.',
                   'Não bloqueia o MVP; exceção de XLSX das respostas de Formulários tem ação própria.')
        elif a['scope']=='gate-formal-mvp':
            tasks=('UX honesta e AAL1 vigente.', 'MFA adiado conforme decisão formal.', 'Retomar no gate formal do MVP; não fingir MFA ativo.')
        elif not pending(a):
            tasks=('Sem pendência funcional registrada.', 'Sem pendência funcional registrada.' if a['backendStatus']=='done' else 'Não aplicável como ação própria.', 'Aceite registrado; ressalvas transversais acima.')
        else:
            tasks=gates.get(a['id'])
            if tasks is None:
                raise RuntimeError('Gate não mapeado: '+a['id'])
        lines.append('| '+ ' | '.join(map(safe,[a['screen']+' — `'+a['id']+'`',a['frontendStatus']+' / '+a['backendStatus']+' / '+a['integratedStatus'],*tasks]))+' |')
    lines.append('')
lines += ['## Fonte e atualização','',
          'Inventário e três rastreadores são a fonte de estados/certificações. Esta visão '
          'complementa os registros históricos com o primeiro gate conhecido; não apaga '
          'evidências antigas nem concede novo aceite. Sem alteração de denominadores.', '']
OUT.write_text('\n'.join(lines),encoding='utf-8')
print(f'{len(data["actions"])} ações, {len(families)} famílias; relatório gerado: {OUT.name}')
