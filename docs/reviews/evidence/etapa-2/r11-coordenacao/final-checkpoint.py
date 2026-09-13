from pathlib import Path
from datetime import datetime, timezone
import json
import subprocess

root=Path(__file__).resolve().parents[5]
now=datetime.now(timezone.utc)
started=datetime.fromisoformat('2026-09-13T10:47:39-03:00')
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip()
record=dict(at=now.isoformat(),startedAt=started.isoformat(),elapsedMinutes=round((now-started).total_seconds()/60,2),head=head,writer='C0',quotaInitialUsed=87,quotaLastMeasuredUsed=92,quotaUsedDeltaPercentagePoints=5,quotaCeiling=98,freezeAt=95,quotaWindowMinutes=10080,quotaResetsAt=1789820315,runtimePid=39272,port=3000,qaChromePid=31192,qaCdpPort=9427,ownerChromePid=18924,flutterSlot='idle',sqlRemoteApplied=False,edgeDeployed=False,cloudflareDeployed=False,photoPersistenceImplemented=False,stage='closing-partial-awaiting-final-gate')
Path(__file__).with_name('final-checkpoint.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
with (root/'docs/reviews/etapa-2-operacao/next-round/R11-checkpoint.md').open('a',encoding='utf-8') as out:
    out.write(f'''\n## Checkpoint de entrega {now.isoformat()}

C0, HEAD{head}, {record['elapsedMinutes']}min desde T0. Cota medida92%, abertura87%, delta5p.p.; teto98/congelamento95/reserva3 preservados. Entrada em fechamento parcial por gates remotos: PITR falso confirmado12:36BRT; nenhuma resposta a decisao recebida; Auth sem mensagem real; fotoR2 sem contrato existente e aberta. Nao abrir vizinho condicional nem R12/Etapa3. Limite e maximo, sem consumo artificial ate95/98.

Flutter59 casos unicos PASS (novo teclado/Tab/rodape acima de300px); pgTAP41 asserts unicos PASS, reportados separadamente. UI31 subaceites:11P/5F/14B/0S/1U, sem novo action_id E2E. Memoria77artigos PASS, suite12P/1S. SQL41 e builds locais nao certificam producao. Proximo gate: commit/push dos MDs/registro e delivery_gate; depois confirmar SHA remoto. Matrices175FE/159BE/148E2E, denominadores231/224/199.

Runtime39272/3000 serve codigo d20bcfcf2, QAChrome31192/CDP9427; ChromeOwner18924 preservado, slotFlutter ocioso. Quatro candidatos locais, backups schema/data externos concluídos, referencias/codigo no checkout consolidado; nenhum deploy remoto. WIP deste checkpoint: docs de fechamento/pendencias, projecao team, evidencia e teste de teclado, a publicar. Nenhuma alteracao de produto retida fora de commit anterior. Reconciliacao final em R11-fechamento.md/entrega-atual.json; historicos de branches preservados.
''')
print(json.dumps(record))
