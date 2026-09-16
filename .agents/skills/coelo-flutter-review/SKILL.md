---
name: coelo-frontend
description: Use when reviewing, correcting, implementing, estimating, or verifying Coelo front-end behavior in Flutter/Dart or Astro, including routes, states, responsiveness, accessibility, architecture, tests, and visual regressions.
metadata:
  source: "AGENTS.md; docs/agent/current-state.md; docs/agent/review-workflow.md; docs/design/design-system.md; decisions/0041-owner-decisions-r14-mesa-20260916.md"
  status: "active"
  generated_at: "2026-09-14"
  updated_at: "2026-09-16"
---

# Coelo Front-end

Artefatos de execução só entram quando a tarefa pedir evidência específica;
para limpeza, siga `docs/agent/artifact-cleanup-backlog-20260914.md`.

Esta é a porta de entrada curta da skill. Não contém logs de rodada, prompts,
percentuais ou fila copiada. Estado e pendências ficam em
`docs/agent/current-state.md` e nos rastreadores apontados por ele.

## Fluxo

1. Leia `docs/agent/current-state.md` e `docs/agent/source-of-truth.md`.
2. Declare app, menu, tela, subtela/estado, `action_id`, objetivo, incluído,
   fora de escopo, ordem, parada e evidência esperada.
3. Use `docs/agent/review-workflow.md` e o contrato detalhado em
   `../coelo-flutter-supabase-review/references/review-scope.md`.
4. Leia o tracker FE somente na profundidade exigida: cabeçalhos/ações afetadas
   para correção localizada; integralmente para auditoria ampla ou conclusão.
5. Para UI, carregue `coelo-ui` e somente as referências visuais necessárias.
6. Corrija, teste e prove o aceite FE. Não declare E2E por mock, `/dev`, golden,
   fixture ou rota aberta; registre dependências BE/E2E separadamente.
7. Golden vermelho: abra o `*_isolatedDiff.png` antes de atribuir a falha à
   tela e siga `references/golden-failure-triage.md`. Deriva do cabeçalho
   global não é defeito da tela nem autoriza regravar por conta própria.

Ações que são só tela (páginas de erro, troca de contexto do shell) têm escopo
`flutter-only`: o aceite terminal é FE na rota real e BE é `not-applicable`.
A classificação é decisão do Owner registrada em ADR, nunca inferida para
zerar pendência.

## Escopo atual e limites

Na Etapa 2 o app é `apps/superadmin`; Coelo (Principal) é um menu/família
visual hospedado nele. `apps/admin`, `apps/principal` e `apps/site` ficam fora
sem recorte explícito. `principal` continua sendo a nomenclatura canônica.

Use `coelo-ui` para distinguir família administrativa, Principal e Site.
Use `coelo-knowledge` somente quando uma regra durável mudar; atualize a fonte
canônica antes da projeção.

## Coordenação e fechamento

Esta é uma skill folha. Só use `coelo-frontend-backend` quando o aceite da
tarefa realmente atravessar FE e BE; a skill integrada coordena sem reativar
esta skill em ciclo. Para backend independente, não carregue a integrada.

O delivery gate em `../coelo-flutter-supabase-review/references/delivery-gate.md`
só é necessário quando o escopo incluir integração, publicação ou entrega
formal. Quando aplicável, execute com o relatório explícito:

```powershell
python docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json
```

Antes do fechamento, confira diff, testes, destino, skills no checkout final e
separe avanço local de aceite FE/BE/E2E. Histórico, artefatos e backups são
proveniência, nunca requisitos atuais.
