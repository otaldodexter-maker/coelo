---
name: coelo-frontend-backend
description: Use when a Coelo task crosses front-end and back-end, including Flutter/Dart or Astro with Supabase/Postgres, Auth, RLS, Edge Functions, Cloudflare, remote persistence, security, or end-to-end behavior.
metadata:
  source: "AGENTS.md; docs/agent/current-state.md; docs/agent/review-workflow.md; decisions/0032-mvp-private-media-r2.md; decisions/0041-owner-decisions-r14-mesa-20260916.md"
  status: "active"
  generated_at: "2026-09-14"
  updated_at: "2026-09-16"
---

# Coelo Front-end + Back-end

Artefatos de execução não são fonte de decisão; em limpeza, siga o backlog em
`docs/agent/artifact-cleanup-backlog-20260914.md` e não carregue snapshots por
inferência.

Esta é a porta de entrada curta para aceites que cruzam camadas. Não contém
logs de rodada, prompts, percentuais ou fila copiada. Estado e pendências ficam
em `docs/agent/current-state.md` e nos rastreadores apontados por ele.

## Fluxo

1. Leia `docs/agent/current-state.md` e `docs/agent/source-of-truth.md`.
2. Declare app, menu, tela, subtela/estado, `action_id`, objetivo, incluído,
   fora de escopo, ordem, parada e evidência esperada.
3. Leia `references/review-scope.md` uma vez e escolha a profundidade: ação
   localizada cruza os IDs e linhas afetadas; auditoria/conclusão ampla lê os
   três rastreadores integralmente.
4. Coordene as autoridades FE e BE sem recursão: carregue cada skill/referência
   uma vez, reutilize o contexto e não reative a integrada a partir das folhas.
5. Use `coelo-ui` para família visual, `coelo-knowledge` para memória durável
   e Cloudflare/Wrangler somente se a ação usar o recurso.
6. Prove UI normal, persistência, autorização/RLS, reload e demais critérios do
   contrato. Separe estados FE, BE e E2E; teste local não certifica produção.

## Escopo atual

Na Etapa 2 o app é `apps/superadmin`; Coelo (Principal) é um menu/família
visual hospedado nele. `apps/admin`, `apps/principal` e `apps/site` só entram
com recorte explícito. A rodada vigente e o ambiente responsável estão sempre
em `docs/agent/current-state.md`; não usar uma rodada histórica como fila atual.

As referências detalhadas desta skill ficam em:

- `references/review-scope.md` — entrada, retomada, profundidade, recursão e a
  sessão QA autenticada da rota real (onde as credenciais vivem, como carregar);
- `references/medicao-confiavel.md` — métricas e denominadores;
- `references/delivery-gate.md` — somente integração/publicação/entrega formal.

## Segurança e autoridade

Frontend apenas solicita e renderiza; backend/RLS valida ator, tenant,
ownership, hierarquia e regra de negócio. Nenhum segredo entra no cliente,
Git ou log. Mídia nova do MVP segue ADR 0032; decisões de importação/exportação
seguem ADR 0031; decisões de produto da R13 seguem ADR 0038; contratos e
aceites decididos pelo Owner na R14 seguem ADR 0041 (busca de pessoa, pessoa
sem conta, snapshot de rotina na chamada, arquivar, notificações de medicação,
"ver como"). Uma decisão do Owner registrada em ADR nunca é reaberta por uma
sessão; se a implementação encontrar conflito, registre em `open-questions.md`.

Histórico, handoff, checkpoint, prompt, screenshot, backup e artefato só são
proveniência quando uma fonte atual os apontar. Não declarar entrega por
documentação, mock, `/dev`, golden, fixture, rota aberta ou percentual.

## Fechamento

O delivery gate em `references/delivery-gate.md` é exigido apenas quando o
escopo incluir integração, publicação ou entrega formal. Quando aplicável,
execute com o relatório explícito:

```powershell
python docs/reviews/delivery_gate.py docs/reviews/entrega-atual.json
```

Antes de concluir, confira diff, testes, checkout/destino, skills no checkout
final, commits/push/deploy e pendências por camada. Atualize fonte canônica,
estado e rastreadores conforme o contrato; não misture histórico para zerar
contagens.
