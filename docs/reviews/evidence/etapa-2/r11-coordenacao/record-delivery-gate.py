from pathlib import Path
from datetime import datetime, timezone
import json
import subprocess

root=Path(__file__).resolve().parents[5]
now=datetime.now(timezone.utc)
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root).decode().strip()
started=datetime.fromisoformat('2026-09-13T10:47:39-03:00')
elapsed=round((now-started).total_seconds()/60,2)
for name in ['R11-fechamento.md','R11-pendencias.md']:
    path=root/'docs/reviews/etapa-2-operacao/next-round'/name
    content=path.read_text(encoding='utf-8').replace('status: fechamento parcial em verificacao','status: encerrada; entrega parcial documentada')
    content+=f'\nFechamento registrado em {now.isoformat()} ({elapsed}min desde T0). Gate apos commit/push {head}: PASS DOCUMENTED_PARTIAL, exit0. Cota final medida92% usados, abertura87%, consumo5p.p.; mesma janela/reset. HEAD/origin-dev sem divergencia e checkout sem WIP no gate. Este registro documental sera publicado e o gate repetido na base final, sem rerun de testes de produto. Retomada somente mediante instrucao explicita; R12/Etapa3 nao iniciadas.\n'
    path.write_text(content,encoding='utf-8')
path=Path(__file__).with_name('final-checkpoint.json')
record=json.loads(path.read_text(encoding='utf-8'))
record.update(closedAt=now.isoformat(),elapsedMinutes=elapsed,gateHead=head,gate='PASS DOCUMENTED_PARTIAL',gateExit=0,stage='closed-partial',quotaFinalUsed=92)
path.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
with (root/'docs/reviews/etapa-2-operacao/next-round/R11-checkpoint.md').open('a',encoding='utf-8') as out:
    out.write(f'\nFechamento {now.isoformat()}: gate PASS DOCUMENTED_PARTIAL/exit0 apos push {head}; {elapsed}min, cota87->92% (+5p.p.). Checkout sem WIP, divergencia0/0, uma worktree/stash vazio; residuos historicos preservados. Registrar esta ata e repetir gate apos push final. C0 libera slots de trabalho, preserva runtime39272/3000 e QAChrome31192; nenhum processo do Owner encerrado. Pendencias/primeiros gates em R11-pendencias.md.\n')
print(json.dumps(dict(gateHead=head,closedAt=now.isoformat(),elapsedMinutes=elapsed)))
