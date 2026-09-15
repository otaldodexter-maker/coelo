---
source: R13-prompt-execucao-20260914.md; R13-pendencias.md; R14-catalogo.md
status: historical; superado pela fila R14; não executar
lifecycle: "historical"
generated_at: 2026-09-14
updated_at: 2026-09-14
---

# Plano de abertura R14

Este plano registrou a preparação após o fechamento formal da R13. A fila viva
da R14 está em `R14-pendencias.md`; não iniciar agente, migration, QA,
publicação ou nova fila a partir deste arquivo.

## Limite de transferência preparado pelo Owner

Ao encerrar a cota da R13, registrar como destino preparado da R14 — sem
executar e sem renumerar — Circular `H04`; Formulários `H10`/`H11`, readers de
Planos/reader self da Conta e Local interno condicional; Principal `H27`/`P54`/
`H02`; perfis `owner.r12-19`–`owner.r12-27`; Segurança infantil;
`assessments.close/reopen`; foto R2 de `owner.r12-46`; SQL c de
`owner.r12-18`, `owner.r12-33`, `asset_id`/Edge Function; e `H03`, `H07`, `H09`,
`H12`, `H14`, `H16`, `H18`–`H20`, `H22`, `H24`–`H26`, `H28`.

Ficam na R13 desta cota Saúde/Cuidado, Cardápios, `owner.r12-36`/`37`, OQ-031,
H08 Duplicar Aviso, `owner.r12-47` e Avisos H08/H23/H13 se houver margem. A
transferência só ocorre com fechamento e confirmação do estado não terminal.

## Ordem de abertura

1. Confirmar `dev`, worktrees, stash, evidências, estado remoto e a revisão do
   fechamento da R13.
2. Regenerar o catálogo com os itens não terminais reais; preservar os mesmos
   `owner.r12-*`, `H*` e `action_id` e registrar origem, destino, estado,
   evidência e primeiro gate.
3. Reconciliar inventário e os três rastreadores antes de escolher a primeira
   subtela. Não usar percentuais ou filas gravados em snapshots antigos.
4. Declarar objetivo, incluído, fora de escopo, ordem, critério de parada e
   evidências; então escolher a skill de FE, BE ou FE+BE.
5. Resolver cada gate pela rota normal, persistência, isolamento por tenant,
   reload e prova aplicável. Atualizar fonte canônica, estado e rastreadores no
   mesmo ciclo.
6. No fechamento, executar o gate de entrega apenas se houver integração,
   publicação ou entrega formal.

R14 não recebe automaticamente pendências concluídas, decisões já respondidas,
artefatos de execução ou instruções de R12. Um bloqueio externo deve manter o
item explícito e permitir avançar nos itens independentes.
