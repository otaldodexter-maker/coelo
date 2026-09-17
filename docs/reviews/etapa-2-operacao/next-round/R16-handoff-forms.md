---
title: "R16 — handoff da sessão FORMS (forms.location-answer)"
source: "R16-prompts.md (Prompt 1); R16-execucao.md; R16-pendencias.md (Foco da R16); ADR 0044; R15-handoff-bloco-a.md (roteiro); inventario-etapa-2.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R16 — handoff da sessão FORMS

Sessão FORMS (Fable 5.1, `coelo-2a`), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r16-forms`,
branch `r16/forms-location-answer`, base `dev cd5b7493e`, servidor `127.0.0.1:3014`, Chrome CDP `9414`,
perfil `%TEMP%\coelo-r16-forms-chrome`. Sem escrita SQL em produção (só tela + PostgREST com a identidade
`qa-r06-formularios`). Só a sessão FORMS escreve aqui; a coordenadora integra por cherry-pick.

## Reivindicações

| Tela | action_ids | Owner items | Desde |
|---|---|---|---|
| Formulários › Editor (publicar) › Visão geral (Distribuir) › Responder (`/forms/:id/occurrences/:occ/respond`) | forms.location-answer | — | 17/09 20:15 BRT |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| (este) | forms.location-answer FE verified + BE done + E2E verified-e2e: v4 publicada pelo editor (prévia com "Em qual local?"), Distribuir → agendamento "Uma vez" 17/09 20:00 (ocorrência única c42cf334 na versão publicada nova e0107c9d), resposta com Local "[R04-QA] Local Sala Azul" pelo deep link como qa-r06-formularios (resposta b1d52e77, option 0792b3e5), reload relendo; negativas 400 22023 (opção inexistente), 400 23514 (0/2 opções), 409 PT409, P0002 (inexistente / participação alheia / janela fechada) | — | r16-forms/forms-location-answer-20260917.md; deltas-forms-location-answer-20260917.json; capturas 00–15 |

## Avisos para a outra sessão e para a coordenadora

- Massa em produção alterada (sem SQL; só tela + PostgREST): form `4555ba07…` publicado na versão `e0107c9d…` (version 2; `49c338d7…` superseded; `management_version 5`); agendamento `2860c35a…` agora `once` 17/09 20:00 (mv3); ocorrência nova `c42cf334…` (`open` até 24/09 23:00Z) com 11 participações; resposta `b1d52e77…` da pessoa `9f944691…` (texto "R16 FORMS resposta com Local" + Local `fc446535…`). Nenhum lote/migration; nenhuma Edge alterada.
- Ocorrência alheia (outro tenant) não existe em produção (leitura D1) — a negativa 403 cross-tenant ficou "sem massa"; escopo provado por P0002 (inexistente/participação alheia) e janela fechada.
- Ambiente: `tap` do driver não responde (login por `clickxy` + `enter_text`); primeiro clique após abrir popup não registra; sem travamento do SwiftShader nesta sessão (perfil novo).

## Bloqueios

- Nenhum.

## Sobra

- Resíduo `form-diario` (fora do foco da R16, já listado na fila R16 da ADR 0044): as 24 ocorrências `scheduled` de 18/09–11/10 geradas pelo "Diário" da R15 permanecem (o gerador só insere; sem tela para cancelar); a de 17/09 `7256b047…` (versão antiga) segue `open` até 24/09.
- Resíduos sem action_id: editor sem feedback após "Publicar agora" (confirmação só na Visão geral); `form_get_occurrence_for_response`/`form_open_response_draft` com id inexistente → HTTP 500 P0002 (mesmo mapeamento já anotado para `form_get_editor`).

## Contadores

`validate-trackers.cjs` PASS após o delta: FE 199/199, BE 186/186, E2E 185/186 (faltando só `agora.publish`, sessão AGORA); Owner 39/53 inalterado.
