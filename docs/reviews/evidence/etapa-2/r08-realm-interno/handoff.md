---
fonte: R08 G5; recibos G0/G1/G2/G3/G4/C0; origin/dev 477e6c8df
status: handoff final
generated_at: 2026-09-12T14:40:00-03:00
---

# Handoff final — R08 Realm interno e segurança

## Resultado

O recorte G5 foi entregue. A revisão pós-lotes 49–55, a raiz de escopo do ator
interno e seus consumidores compartilhados foram provados no espelho; os
candidatos forward-only nasceram somente de defeitos medidos. Fixtures de G1/G2,
convites expirados, expiração de mídia e Chat foram preparadas/revisadas. G5 não
aplicou SQL, não fez deploy, não executou pgTAP, Docker, Dart ou Chrome.

O último gate H28 foi executado pelo G0 sobre o corpo final
`df0a281cb`/blob `707cc8b4`: 11/11 estrutural, 10/10 funcional e regressões
8/8 + 11/11 + 4/4, total 44/44, todas com rollback e exit 0. O C0 aplicou o
lote 59 em produção às 14:31, com backup, ledger `20260912143000`, assinatura
única de 17 argumentos, owner `postgres`, `security definer`, EXECUTE para
`authenticated`, negação para `anon` e `neighborhood.state_code` presente.
O commit integrado é `477e6c8df`; não reaplicar o SQL.

O fluxo answer-image do ator interno também fechou em produção: `form-media`
v21, suíte integrada 56/56, download dos mesmos 68 bytes/SHA e reopen com o
mesmo asset, sem repetir upload/finalize/save/cleanup. O runner de Avaliações
`d59e17f62` recebeu ACK técnico G5; o assignment nominal foi entregue ao C0,
que permanece dono do arquivo ACK e de qualquer execução mutante.

## Entregas da branch G5

- `49bd4c83d`: resolvedor do ator interno em answer-image;
- `5927718f2`: validade do PUT R2 ligada à URL recém-assinada;
- `6d0deecd2`: `p_edit_secret=null` explícito na RPC de download/finalize;
- `cebde7c56`, `bcf9038b0`, `3eb8bb7d3`, `e1cad10e2`: fixture H28 funcional e
  correções de constraints medidas;
- `d4e436eb2`, `f157e3a97`: evidências, preflight read-only, hashes e liberação
  da composição lote 59.

A branch está publicada em `origin/work/etapa2-r08-realm-interno`. A evidência
do lote 59 aplicado está em `origin/dev` no commit `477e6c8df`; a evidência
final do espelho G0 está em `c34fc20d4`.

## Dados sintéticos e limpeza futura

Foram preservados os formulários/assets de question-image e answer-image e a
identidade interna P51 `0ddeebc0-ee10-4565-96e0-ef11cacfc734`, com seus vínculos
associados. Os IDs e a ordem de limpeza estão no
`synthetic-cleanup-manifest.md`. A fixture H28 inteira usou rollback e não deixou
dados. Nenhuma chave, token, senha ou URL assinada foi versionada.

A limpeza futura de sintéticos foi somente preparada; não deve ser executada
antes do encerramento formal da Etapa 2. A worktree deve ser preservada conforme
ordem do Owner.

## Pendências honestas

- A suíte histórica `superadmin_people_directory_test.sql` continua obsoleta
  (permissões antigas e assinatura removida de 12 argumentos); não é regressão
  do lote 59 e não foi mascarada.
- A execução mutante de Avaliações depende do ACK nominal C0 e segue fora da
  autoridade G5.
- H19 continua aguardando decisão de produto sobre quem pode ser responsável
  por plano de medicação; nenhum papel foi inferido.
- Correção de senha, revisão histórica de credenciais, endurecimento amplo e
  limpeza de sintéticos permanecem fora desta entrega.

A decisão de papel referente a 180060 não foi reaberta. Nenhuma nova regra
durável aprovada surgiu neste fechamento; o gate `/coelo-knowledge` não exigiu
duplicar a projeção em `docs/knowledge/`. R09 foi preparada pela coordenação,
mas não iniciada por G5.
