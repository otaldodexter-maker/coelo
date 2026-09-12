# Handoff R08 — Estrutura (G1)

Data: 2026-09-12, entrega antecipada pelo Owner para fechamento C0 às 15:00.

## Entregue

- `activities.create`: migração do formulário para o rodapé canônico
  `SuperadminFormActionFooter`; teste focal 22/22.
- `groups.location`: correção e prova integrada por C0; não alterar novamente
  nesta frente.
- PNGs A: 45/45 regravados sob P53=A — 31 Atividades, 12 detalhes
  Unidade/Turma e 2 paginação de Instituições; teste combinado 20/20. Hashes
  materializados em `png-a-object-hashes-20260912.md`.
- Avaliações / `activities.assessment`: runner autenticado recebeu dry-run,
  plano estrito, replay idempotente e resume seguro. G4 fakeproof e G5 revisão
  técnica aprovaram o SHA `d59e17f62`.
- Sob ACK nominal C0, a cadeia API única foi executada com exit 0:
  configuração `833a89d8-466f-4ff4-8ab9-4ffb7f33a1cb` ativa v2; período
  `c4e38ada-e062-4466-a22d-88dca177fa30` aberto; diário
  `d2c945d8-3809-4d84-b836-2bc6da7c381d` draft v1. Reloads autoritativos
  foram validados pelo runner; logout 204.

## Evidências e commits

- execução e dados do ACK: `assessments-api-execution-20260912.json` e
  `assessments-api-execution-20260912.md`, commit `35922525b`;
- guards/resume e smoke offline: `assessments_api_runner.py`,
  `assessments_api_runner_smoke_test.py`, `assessments-resume-safety-20260912.md`;
- alvo de ACK (somente UUIDs, sem segredos): `assessments-ack-input-20260912.json`,
  commit `99566bed8`;
- checkpoint comunicável mais recente antes da integração: `15244b682`;
- base integrada materializada nesta worktree: merge `b7715ec6a` de
  `origin/dev` `477e6c8df`.

## Pendente e limites

- Não executados: Chrome/rota de UI, lançamento de notas e transições
  submit/review/return/publish; não são certificados por esta prova API.
- `groups.location` na UI não foi reaberto; a correção/prova C0 permanece a
  referência.
- Recursos sintéticos de Avaliações acima devem ser retidos até o encerramento
  formal da Etapa 2; não houve exclusão, credencial, segredo ou chave criada.
- R09 foi apenas preparada pelo C0 e não foi iniciada por G1.

## Estado da worktree

Branch `work/etapa2-r08-estrutura`; worktree preservada conforme instrução.
Sem WIP local ao concluir este handoff. O próximo responsável deve começar por
uma autorização explícita para o próximo gate, não reaplicar SQL lote 59 nem a
cadeia de Avaliações já executada.
