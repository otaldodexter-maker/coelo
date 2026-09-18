---
source: Owner 2026-09-13 — consolidar R12/R13 como R12, Luna médio, commits e pendências
status: "historical"
lifecycle: "historical"
generated_at: 2026-09-13
updated_at: 2026-09-14
---

> Prompt histórico. Não executar este arquivo nem iniciar Luna/C0 a partir
> dele. A fila vigente está em `R14-pendencias.md` e
> `docs/agent/current-state.md`; este prompt não autoriza execução.

# R12 consolidada — execução direta em Luna médio

Você é **C0, único executor de produto**, em **Luna, esforço médio**. Execute
integralmente a R12 consolidada neste chat. A antiga R13 foi incorporada à R12.
Este envio autoriza implementar, testar, atualizar MDs/skills e commit/push em
dev, dentro das autorizações remotas existentes. Não pedir nova confirmação
do recorte. Não encerrar só com plano, auditoria, cota, PID ou eventos.

## Fonte única e preservação

Raiz C:/Users/adrie/Documents/Coelo. Ler AGENTS.md, RTK.md e:
- docs/reviews/etapa-2-operacao/next-round/R12-consolidacao.md;
- R12-plano-de-rodada.md, R12-pendencias.md e R12-owner-items.json na mesma pasta;
- entrega-atual.json, inventário e três matrizes nos recortes afetados.

Aplicar as skills .agents/skills/rtk, coelo-supabase, coelo-flutter-review,
coelo-flutter-supabase-review, coelo-knowledge, coelo-tutor, ponytail e coelo-ui
por seus SKILL.md. Reutilizar leituras. Tutor orienta clareza, sem aula/quiz ou
memória didática inventada. Coelo UI é autoridade visual.

Preservar tudo da R01–R13: commits, refs, WIP/ignorados, fontes e provas válidas.
Fazer fetch; confirmar dev=origin/dev, status, stash/worktrees e slots. Trabalhar
no checkout consolidado, sem novas worktrees. Não reset/clean/force-push nem
reaplicar patches/SQL históricos. R12-07/41/43 estão entregues visualmente;
chat.attach tem delta f8c209a17 e29 testes únicos, mas continua aberto.

## Execute produto agora

Registrar T0, SHA, modelo/bucket/cota e recorte por apps/superadmin > menu >
tela > subtela/estado > action_id no R12-checkpoint.md. A unidade de avanço é
um aceite provado, não quantidade de comandos ou mensagens.

Começar pelo primeiro gate de R12-52/chat.attach: inspecionar referência de
mídia/compositor e delta existente, reaproveitar os testes válidos, construir
código atual e provar pela rota normal; implementar/corrigir o primeiro aceite
faltante. Se depender de bloqueio externo real, registrar e ir a uma fatia
independente (R12-44 Convites somente tabela é independente de SMTP). Seguir
a ordem por dependências do plano até acabar trabalho viável ou atingir o corte.

Não monitorar a si mesmo esperando outro agente. **Não existe outro executor
fazendo o trabalho por você.** Não armar r12-luna-dispatch.py, não usar release,
não criar outro CLI/chat/supervisor. Os mecanismos anteriores estão retirados
deste fluxo manual. Outro processo realmente ativo deve ser identificado, não
inferido de histórico. Um Chrome QA e um flutter test, pesados serializados;
preservar Chrome do Owner. Atualizar o app real quando exigido pelo aceite.

Todo remoto é produção. Reusar sintéticos retidos. Backend valida tenant,
ownership/RLS/IDOR; esconder botão não autoriza. SQL depende dos gates vigentes
pgTAP/PITR/backup/ordem; Cloudflare exige autorização nominal aplicável. Não
inventar exceções, dados, links de Auth ou sucesso. PITR/SMTP bloqueiam só seus
dependentes. Não enviar mensagens a terceiros para provar UI.

## Cota e continuidade

Luna médio; medir o bucket real na abertura, a cada fatia/checkpoint e antes
de comando caro. Se iniciar no normal, trabalhar até99%; a fase seguinte é
Luna reserva médio. Se já iniciar em reserva, usar o teto99% desse bucket.
Antes do limite, persistir checkpoint/WIP, MDs e commits; perto de97% priorizar
fechamento para caber até99%. Não comprar créditos/API nem resgatar resets.

A troca normal→reserva deve preservar o mesmo contexto e um único escritor,
usando apenas controle de modelo realmente disponível no chat. Se a interface
não permitir a troca, entregar checkpoint e instrução exata de retomada na
reserva; não afirmar que migrou nem deixar supervisor fictício em execução.
Não parar em95/96/98% por regra antiga nem encerrar só por bloqueio isolado.
Na reserva, continuar R12 e, se houver saldo, demais gates viáveis da Etapa2
até99% ou parada do Owner. Não gastar cota artificialmente. Não iniciar Etapa3.

## Entrega obrigatória a cada avanço e no corte

Atualizar fonte canônica, owner-items, entrega-atual, inventário/três matrizes
via apply-tracker-delta.cjs e referências das quatro skills FE/BE/FE+BE/Knowledge.
Guardar conhecimento durável aprovado por audiência; no-op quando não mudar.
Preservar R01–R13 e reportar feito/aberto por camada e tela. Subir percentuais
somente com aceites reais, IDs únicos/base/data, sete métricas e testes únicos
P/F/B/S/U; repetir testes verdes só com motivo material. Código local/golden/
screenshot/API isolada não certifica E2E, e aprovação A é do Owner.

Commit/push a cada fatia e checkpoint, sem WIP esquecido. No corte, reconciliar
pendências e preparar R14-prompt-unico.md, plano e catálogo para Claude Opus
médio, sem dispará-la. Cerca de12% de uso lá é estimativa do Owner, a confirmar
na abertura. Registrar SHA/ambiente/provas/primeiro gate e instruções de retomada.

Concluir memória, conferir skills no destino, Git/remoto/stash/worktrees e
executar após commit/push: rtk proxy python -X utf8 docs/reviews/delivery_gate.py
docs/reviews/entrega-atual.json. FAIL impede declaração de entrega; parcial
deve dizer exatamente o que falta. Não declarar produto concluído porque a
consolidação documental passou. Não terminar dizendo que outro agente seguirá.
