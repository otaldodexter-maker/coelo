---
title: "R16 — checkpoint de 17/09/2026 (fim da execução FE/BE/E2E do MVP)"
source: "R16-execucao.md; R16-handoff-forms.md; R16-handoff-agora.md; relatórios finais das sessões (mensagens de 17/09 ~21:00 BRT); validate-trackers.cjs em 21f4485ad; ADR 0043; ADR 0044"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R16 — checkpoint de 17/09/2026

Corte integrado em `dev` pela coordenadora (`coelo-2c`) ao fim da execução paralela da
R16 (duas sessões, FORMS e AGORA; `R16-execucao.md`). A meta do Owner para a rodada —
**FE 199/199, BE 186/186, E2E 186/186 do MVP** — foi atingida com prova na rota real
em produção. A R16 continua a rodada vigente (ADR 0043): Owner items, resíduos H e
UI/UX ficam em reserva para a revisão de telas antes da Etapa 3, por decisão do Owner
("Foco da R16"). Uma R17 exige decisão explícita do Owner.

## Contadores (validate-trackers, `21f4485ad`)

| Métrica | Mesa R16 (abertura da execução) | Fim da execução 17/09 | Δ |
|---|---|---|---|
| FE verificado | 198/199 (99,5%) | **199/199 (100%)** | +1 |
| BE concluído | 185/186 (99,5%) | **186/186 (100%)** | +1 |
| E2E verificado | 184/186 (98,9%) | **186/186 (100%)** | +2 |
| Owner items done | 39/53 | 39/53 | 0 (reserva, por decisão) |

Denominadores do MVP após a ADR 0044 (33 ações de escopo `v1` fora). Ações `flutter-only`
(13) continuam certificadas por FE na rota real.

## action_ids certificados nesta execução (evidência em produção)

- `agora.publish` — Sessão AGORA (`coelo-5a`): spec `070-now-guardian-reader.md`; **lote 81**
  `20260917203000_now_guardian_reader_v1` (função irmã `app_private.now_reader_actor`
  reconhece o responsável por `guardian_links` ativo + `child_contexts` ativo +
  `guardian_context_permissions.can_view`, sem membership; `now_actor` de escrita
  inalterado; `list_visible_now_publications` e `redeem_now_media_read_ticket` com
  assinatura/grants iguais); pgTAP 21/21 no espelho fiel (+ removal 18/18, projection 9/9,
  happens 33/33 sem regressão); prova por PostgREST: `qa-r15-responsavel` lê a story
  `d9580375` (200, `can_remove false`, ticket de mídia único), 2ª chamada estável,
  cross-tenant (instituição real e inexistente) → 403 42501, equipe → `[]`.
  Evidência: `evidence/etapa-2/r16-agora/agora-publish-guardian-reader-20260917.md`.
- `forms.location-answer` — Sessão FORMS (`coelo-2a`): v4 do form `4555ba07` publicada
  pelo editor (versão `e0107c9d` com o item Local `90d33a71`), agendamento "Uma vez"
  17/09 20:00 → ocorrência única `c42cf334` (cron reconciliou 11 participações), resposta
  com Local pela rota real como `qa-r06-formularios` (resposta `b1d52e77`), reload relendo;
  negativas por PostgREST: 400 22023 (opção inexistente), 400 23514 (0/2 opções), 409 PT409,
  P0002 (inexistente / participação alheia / janela fechada); cross-tenant sem massa (não
  existe ocorrência de outro tenant em produção). Nenhum SQL, nenhum lote.
  Evidência: `evidence/etapa-2/r16-forms/forms-location-answer-20260917.md` (capturas 00–15).

## Produção

- Lote 81 — `20260917203000_now_guardian_reader_v1` (AGORA, 23:33 UTC; dump prévio
  `Coelo-backups/schema-producao-20260917-r16-agora-before.sql`, SHA-256 `0c6c6468…`;
  autorização nominal prévia do Owner em `R16-execucao.md`). Ledger CLI reparado e listado.
- Candidato `20260917113000_qa_r15_guardian_membership_v1` continua **não aplicado**.
- Nenhuma Edge alterada. Massa alterada só pela tela/PostgREST (form `4555ba07` v2 publicada,
  agendamento `once`, ocorrência `c42cf334`, resposta `b1d52e77`).

## Bloqueios por causa

- Nenhum bloqueio ficou aberto. Uma negativa do classificador a um comando PowerShell
  combinado (AGORA) foi resolvida executando os passos um a um; nada contornado.

## Resíduos registrados (para a fila R16 já existente; nenhum novo action_id)

- `form-diario`: as 24 ocorrências `scheduled` de 18/09–11/10 do agendamento "Diário" da
  R15 permanecem (o gerador só insere; sem tela para cancelar); `7256b047` (versão antiga)
  segue `open` até 24/09.
- `forms-v2-qa`: `form_get_occurrence_for_response`/`form_open_response_draft` com id
  inexistente → HTTP 500 P0002 (mesmo mapeamento já anotado para `form_get_editor`).
- Editor de Formulários sem feedback após "Publicar agora" (confirmação só na Visão geral).
- `espelho-cli`: `Sync-SupabaseCliMigrations.ps1 -Mode Prepare` falha por
  `migration count mismatch` mas copia a migration antes da contagem; `-Mode Clean` limpa.
- Espelho restaurado de dump schema-only precisa da pessoa técnica `Coelo Sistema`
  (`c0e10000-…0001`) para as suítes de `follow_links`; falhas pré-existentes alheias ao
  Agora: `now_publication_mvp_test` 18/19/52, `now_media_private_r2_v1_test` 16/17,
  `principal_internal_actor_bridge_v1_test` 7/9.
- Fora de escopo, já na fila: `recipients-bug`, `can-remove`, onboarding de responsável
  no Principal (spec 064 / Etapa 3, OQ-048).

## Relatórios finais das sessões

- FORMS (`coelo-2a`): push `0479cd56a` → `dev` `21f4485ad`. FE verified / BE done / E2E
  verified-e2e. Sem SQL, sem lote. Chrome e servidor 3014 encerrados; worktree limpa.
- AGORA (`coelo-5a`): pushes `c539fc40d` → `dev` `b9f7258b5` e `daddde1a0` → `dev`
  `560a154aa`. Lote 81 aplicado e provado. Porta 3015 nunca aberta (prova por PostgREST;
  OQ-048 inviabiliza tela para conta só-responsável). Espelho `coelo_mirror_r16_agora` parado.

## Git

- `dev` = `origin/dev`; stash vazio; só `dev` no GitHub; worktrees `r16-forms` e `r16-agora`
  removidas com árvore limpa após bundles `Coelo-backups/r16-fechamento/
  r16-agora-publish-20260917.bundle` e `r16-forms-location-answer-20260917.bundle`
  (verificados); branches `r16/*` apagadas (remotas e locais).
