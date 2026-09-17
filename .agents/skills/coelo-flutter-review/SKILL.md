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

Mapeamento de conflito no cliente: repositórios e mapeadores de erro tratam
`PT409` ao lado de `40001`/`SAI_CONCURRENT_CHANGE` (o backend passou a
responder `PT409` em 17/09/2026, lote 75). Sem isso a tela mostra o genérico
"Não foi possível concluir a ação" em vez da mensagem de conflito com
Recarregar; `errors.409` foi provado na rota real exatamente por essa via.

Goldens (E4, ADR 0042): regravar só quando o `isolatedDiff` medido por imagem
ficar restrito ao cabeçalho global (iniciais do avatar, canto superior
direito); diff em filtro, rótulo ou página inteira em `text_200` não é E4 e
fica com quem cuida da família. Registrar cada regravação na evidência com a
suíte, o número de referências e a reexecução verde. Ver
`references/golden-failure-triage.md`.

Estado da Etapa 2 (frontend): Após a Mesa R16 (ADR 0044, 17/09/2026): FE 198/199 (99,5%), BE 185/186 (99,5%), E2E 184/186 (98,9%), Owner 39/53 — 33 ações fora do MVP têm escopo `v1` e ficam fora dos denominadores; a Etapa 2 se mede pelo E2E do MVP e FE/BE seguem por code review e revisão tela a tela na Etapa 3. Corte anterior — Corte da R16 (17/09/2026, `dev` `37d762976`): FE 207/232, BE 185/219, E2E 184/186, Owner 39/53 (R15: +18 FE, +13 BE, +22 E2E, +18 Owner num dia). Fila vigente: `R16-pendencias.md`. Restam
goldens fora do E4 (notice_directory, forms, invites, meal_plans, platform_users) e
testes pré-existentes (`invite_responsive_test` procura um toggle removido na R14;
routers do Principal). O shell do Superadmin só aceita identidade interna
(`superadmin_auth_bootstrap_context`), sem fallback para conta só de responsável.

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
