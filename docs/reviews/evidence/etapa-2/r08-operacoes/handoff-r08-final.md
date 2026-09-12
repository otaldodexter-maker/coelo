---
source: G7 Operações R08
status: handoff
generated_at: 2026-09-12T14:32:00-03:00
---

# Handoff final G7 — R08

## Entregue

- Catálogo: destino real corrigido e prova focal publicada.
- Help Center: somente os dois A nominais comparados/regravados.
- Sessões: prova limitada a identidades sintéticas próprias; nenhuma sessão alheia foi afetada.
- Revisões independentes: Perfil About, runner de Avaliações, H28 Pessoas e encerramento de worktrees.
- H28: fixture/contrato e 19 testes focais passaram na base integrada. C0 aplicou o lote 59 às 14:31, com espelho final 44/44, backup/ledger/ACL confirmados e `contextFiltersAvailable:true`.
- R09: plano e prompts individuais G0--G8 revisados independentemente e publicados.

## Commits G7 relevantes

`343ccfe40`, `de80eedd7`, `133c3516d`, `8ec701dc0`, `4427a92ed`, `05e69e705`, `fff7cd1a7`, `b99a67f4e`, `22d119de5`, `4e5fd7177` e `3bdf43fc6`.

## Pendente explícito

- `account.sessions`: revogação/reload E2E só pode recertificar no runtime com identidade sintética própria.
- `support.*`: reuso das provas válidas; somente retestar com delta de rota/estado.
- `catalog.publish`: depende de autorização nominal de hospedagem externa.
- `plans.assign`: permanece decisão específica da spec051, distinta de SMTP/ativar/restaurar.
- imports/exportações gerais: continuam indisponíveis honestamente; não criar job, parser, arquivo ou RPC.
- H28: aplicado pelo C0; não reaplicar SQL. Qualquer regressão parte da base pós-lote e recebe prova focal.
- Censo Flutter: R09, na primeira janela útil com SHA fixo e slot único.

## Estado de fechamento

Worktree G7 preservada, branch publicada e `git status --short` limpo no último check. Não houve remoção de worktree, alteração do checkout principal, deploy, SQL remoto, segredo, chave ou identidade não sintética por G7.
