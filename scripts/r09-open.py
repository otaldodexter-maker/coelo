import json
from pathlib import Path
from datetime import datetime

p = Path('docs/reviews/etapa-2-operacao/comunicacao/coordenacao.json')
d = json.loads(p.read_text(encoding='utf-8-sig'))
now = datetime.now().astimezone().isoformat()
d.update(revision=d['revision'] + 1, round='E2-R09-20260912', role='C0 Coordenacao R09', model='gpt-6-astra', reasoningEffort='medium', updatedAt=now)
d['posseR09'] = dict(worktree='C:/Users/adrie/Documents/Coelo.worktrees/e2-r09-coordenacao', branch='work/etapa2-r09-coordenacao', baseAoAbrir='f9f1bc0f13e8616e482f19e81a904a7d4b4ad099', T0='2026-09-12T15:17:09-03:00', execucaoAte='2026-09-12T19:17:09-03:00', fechamentoAte='2026-09-12T19:47:09-03:00', threadId='01a096d5-dfe4-7d42-aa97-62137c233882', status='ativa', escopo='apps/superadmin -> menu -> tela/subtela/estado -> action_id; CRUD real, persistencia, reload, RLS e hierarquia', fora='outros apps, R10, senha, exportacoes gerais, endurecimento amplo', regraDeEscrita='C0 exclusivo dev, inventario, tres rastreadores, fila SQL, composicao e deploy; executoras somente dominio e handoff proprio', evidencia='rota normal, CRUD real, reload e negativa de tenant/hierarquia; FE/BE/E2E separados', estimativa='janela maxima autorizada; delta inspecionado apos primeiro gate runtime; consumo pode antecipar', preservacao='nove worktrees R08 limpas e zero commits fora de origin/dev; reutilizar por fast-forward, sem remover ignorados nem worktrees')
gates = {'G0':'login/leitura/reload pelo canal permitido', 'G1':'groups.members/location ou institutions.status', 'G2':'people.create/edit e H28 focal', 'G3':'attendance.mark/correct/finish', 'G4':'meal-plans CRUD ou chat.create-group/attach', 'G5':'negativas reais e hierarquia G1/G2/G3/G4/G6/G7; BE pelos gates proprios', 'G6':'circulars.attach fixture NOVA R09 autorizada e retida', 'G7':'plans.assign se spec051 resolver; senao account.sessions propria', 'G8':'testes focais na base integrada'}
d['frentesR09'] = {}
for g, old in d['frentesR08'].items():
    d['frentesR09'][g] = dict(grupo=old['grupo'], threadId=old['threadId'], model='gpt-6-astra', reasoningEffort='medium', branch=old['branch'], worktree='C:/Users/adrie/Documents/Coelo.worktrees/e2-r08-'+old['grupo'], json=old['json'], ackRevision=old['ackRevision'], primeiroGate=gates[g], status='vaga inicial' if g in ['G0','G5','G1'] else 'fila sem polling', modelConfigured=False)
d['slotsR09'] = dict(chrome=dict(dono='G0', pid=None, inicio=now, expira='2026-09-12T15:47:09-03:00', estado='remedir runtime R08 antes de usar'), flutterTest=dict(dono='nenhum', estado='livre mediante medicao G0'), sqlEspelho=dict(dono='G0', estado='remedir baseline; proximo lote60'), e2eLiberado=False, sqlLiberado=False, ativas=['G0','G5','G1'], fila=['G2','G3','G4','G6','G7','G8'])
d['consumoR09'] = dict(inicialUsedPercent=49, amostras=[dict(at='2026-09-12T15:17:09-03:00', usedPercent=49)], bucket='codex semanal compartilhado', reduzirEm=70, fecharEm=75, metaEncerrarAte=85, regra='primeiro corte tempo/consumo; maior taxa das ultimas duas amostras; sem reset/reserva')
d['ownershipR09'] = d['ownershipR08'].copy()
d['historicoDeRevisoes'][str(d['revision'])] = now + ' abertura nominal R09 C0; posse e fila G0-G8; consumo49; worktrees preservadas'
p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print('R09 posse revision',d['revision'])
