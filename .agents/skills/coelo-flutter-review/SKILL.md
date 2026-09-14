---
name: coelo-frontend
description: Use when reviewing, correcting, implementing, estimating, or verifying Coelo front-end behavior in Flutter/Dart or Astro, including routes, states, responsiveness, accessibility, architecture, tests, and visual regressions.
metadata:
  source: "AGENTS.md; docs/agent/current-state.md; docs/agent/review-workflow.md; docs/design/design-system.md"
  status: "active"
  generated_at: "2026-09-14"
---

# Coelo Front-end

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
