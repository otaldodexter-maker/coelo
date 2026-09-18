"""Transfer the three selected R12 items after actual closure; preview is read-only."""
import argparse
import json
from pathlib import Path
import subprocess

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apply',action='store_true')
parser.add_argument('--preview',action='store_true')
args=parser.parse_args()
root=Path(__file__).resolve().parents[4]
folder=Path(__file__).resolve().parent
delivery_path=root/'docs/reviews/entrega-atual.json'
delivery=json.loads(delivery_path.read_text(encoding='utf-8'))
catalog_path=folder/'R12-owner-items.json'
catalog=json.loads(catalog_path.read_text(encoding='utf-8'))
r13_path=folder/'R13-owner-items.json'
r13=json.loads(r13_path.read_text(encoding='utf-8'))
current={i['id']:i for i in delivery['ownerItems']}
selected=['owner.r12-07','owner.r12-41','owner.r12-43']
pending=[]
for key in selected:
    item=current[key]
    complete=item['status']=='done' and item['fe']=='verified' and item['be'] in ('done','not-applicable') and item['e2e'] in ('verified-e2e','flutter-only')
    if not complete: pending.append(key)
print(json.dumps(dict(mode='apply' if args.apply else 'preview',transfer=pending,completed=[i for i in selected if i not in pending]),ensure_ascii=False))
if not args.apply: raise SystemExit(0)
closure=folder/'R12-fechamento.md'
if not closure.exists() or not any(line.startswith('status:') and 'encerrada' in line for line in closure.read_text(encoding='utf-8').splitlines()[:12]):
    raise SystemExit('R12-fechamento.md must record actual closed status before transfer')
byid={i['id']:i for i in r13}
evidence='docs/reviews/etapa-2-operacao/next-round/R13-pendencias.md'
for item in catalog:
    if item['id'] not in pending: continue
    live=current[item['id']]
    item.update({k:live[k] for k in ('status','fe','be','e2e','evidence','nextGate')})
    item.update(destinationRound='R13',owner='C0 R13')
    byid[item['id']]=dict(item,sourceRound='R12',transferredAtClosure='docs/reviews/etapa-2-operacao/next-round/R12-fechamento.md')
    live.update(destinationRound='R13',owner='C0 R13',destinationEvidence=evidence)
r13=sorted(byid.values(),key=lambda i:i['id'])
r13_path.write_text(json.dumps(r13,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
catalog_path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
md='''---
source: Owner 2026-09-13; R13-owner-items.json; R12-fechamento.md
status: pendências R13; execução não iniciada
generated_at: 2026-09-13
---

# R13 — Pendências após fechamento R12

'''+f'{len(r13)} compromissos preservados. IDs de origem mantidos, sem novo action_id ou ganho funcional. Fontes e estados atualizados abaixo; R13 não iniciada.\n\n| Item | Ações | FE / BE / E2E | Evidência | Primeiro gate |\n|---|---|---|---|---|\n'
def cell(text): return str(text).replace('|','/').replace('\n',' ')
for i in r13:
    md+='| '+' | '.join(map(cell,[i['id'],', '.join(i['actionIds']) or 'gate/condição',i['fe']+' / '+i['be']+' / '+i['e2e'],i['evidence'],i['nextGate']]))+' |\n'
(folder/'R13-pendencias.md').write_text(md,encoding='utf-8')
receipt=folder/'R12-transferencia-final-R13.json'
receipt.write_text(json.dumps(dict(transferred=pending,notTransferredCompleted=[i for i in selected if i not in pending],totalR13=len(r13)),indent=2)+'\n',encoding='utf-8')
item=current['owner.r12-close-transfer-open-r13']
item.update(status='done',evidence='docs/reviews/etapa-2-operacao/next-round/R12-transferencia-final-R13.json',nextGate='')
for path in [item['evidence'],evidence]:
    if path not in delivery['evidenceFiles']: delivery['evidenceFiles'].append(path)
delivery_path.write_text(json.dumps(delivery,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inventory=json.loads((root/'docs/reviews/inventario-etapa-2.json').read_text(encoding='utf-8'))
affected={aid for key in pending for aid in current[key]['actionIds']}
deltas=[]
for a in inventory['actions']:
    if a['id'] not in affected: continue
    for layer,field in [('frontend','fe'),('backend','be'),('integrated','done')]:
        d=dict(action_id=a['id'],camada=layer,delta=a[field]+' | Aberto no fechamento R12; destino C0 R13, ver R13-pendencias.md.',evidencia=evidence)
        if layer in a.get('certifications',{}): d['certificacao']=a['certifications'][layer]
        deltas.append(d)
delta_path=folder/'R12-transferencia-final-delta.json'
delta_path.write_text(json.dumps(deltas,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
if deltas: subprocess.run(['node','docs/reviews/apply-tracker-delta.cjs',str(delta_path)],cwd=root,check=True)
print('Transfer recorded; integrator must commit/push, validate trackers and run delivery_gate after push.')
