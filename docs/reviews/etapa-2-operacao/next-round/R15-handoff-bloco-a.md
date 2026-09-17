---
title: "R15 — handoff do Bloco A (rota real já pronta)"
source: "R15-prompts.md (Prompt A); R15-pendencias.md; ADR 0041; ADR 0042; inventario-etapa-2.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
audience: "team"
---

# R15 — handoff do Bloco A

Sessão A (Fable 5.1), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r15-bloco-a`, branch
`r15/bloco-a`, base `dev 57162cee4`, servidor `127.0.0.1:3014`, Chrome CDP `9414`, perfil
`%TEMP%\coelo-r15-a-chrome`. Sem escrita SQL em produção (só tela + PostgREST com identidade QA). Só a
Sessão A escreve aqui; a coordenadora integra por cherry-pick.

## Reivindicações

| Tela | action_ids | Owner items | Desde |
|---|---|---|---|
| Perfis de acesso (`/profiles`, `/profiles/platform/:id[/edit]`, `/internal-users/:id/edit`) | access-profiles.edit, access-profiles.assign | r12-20, 21, 22, 24, 25, 26, 27 | 17/09 08:50 BRT |
| Instituições › Erro / Acesso negado | institutions.error, institutions.access-denied | A4 (aviso Arquivos) | 17/09 10:20 BRT |
| Conta (`/account`) | account.profile | r12-46 | depois |
| Formulários (expire/delete-file, create/edit, location-answer) | forms.* | r12-39, r12-40 | depois |
| Momentos, errors.409, auth.recover/reset (E8) | momentos.*, errors.409, auth.recover/reset | r12-47 | depois |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 900608be9 | (código) Usuários internos: `/internal-users/:id/edit` carrega o catálogo de instituições também na edição (`_loadRemote` + `loadInstitutions` na rota); antes o passo "Acesso ao Superadmin" ficava em "Catálogo de instituições indisponível" e perfil/escopos somente leitura, o que impedia `access-profiles.assign` pela rota real. +2 testes de widget (vermelho → verde, 23/23); goldens do diretório seguem na deriva do cabeçalho (ADR 0041 C1). | — | apps/superadmin/test/features/platform_users/presentation/platform_user_form_context_test.dart |
| (este) | access-profiles.edit FE verified + E2E verified-e2e (v1→v2 pela tela, reload, 409 PT409 sem mutação após lote 75, 400 22023 instituição alheia); access-profiles.assign FE verified + E2E verified-e2e (perfil QA atribuído a `bf6008f0…`, memberships relidos, reload, Owner restaurado, 409 SAI_CONCURRENT_CHANGE / 403 SAI_PERMISSION_DENIED) | r12-20, 21, 22, 24, 25, 26, 27 → done | r15-bloco-a/access-profiles-edit-assign-20260917.md; deltas-access-profiles-20260917.json; capturas 00–18 |
| (este) | institutions.access-denied e institutions.error: FE verified, BE done, E2E verified-e2e (deep link inexistente → Acesso não autorizado sem dado + reload; RPC bloqueada por CDP → Não foi possível carregar + Tentar novamente recupera; 403 SAI_PERMISSION_DENIED por PostgREST sem enumeração); ADR 0041 A4 capturado (aviso "Arquivos em desenvolvimento") | — | r15-bloco-a/institutions-error-access-denied-20260917.md; deltas-institutions-20260917.json; deltas-institutions-backend-20260917.json; capturas institutions-00–06 |

## Avisos para as outras sessões

- Antes do lote 75 (OQ-047, Bloco B, 12:30 UTC), `superadmin_access_profile_save` com versão defasada
  respondia `504 upstream request timeout` (retry do PostgREST em 40001), sem mutação; depois do lote,
  `409 PT409 ACCESS_PROFILE_STALE_VERSION`. `superadmin_internal_user_update` devolve envelope SAI
  (`ok:false`, `SAI_CONCURRENT_CHANGE` 409) com HTTP 200.
- Massa em produção alterada: perfil `281699f2…` renomeado para "R15 A Perfil QA renomeado" (v2, 2
  capacidades: `institution.role_models.read/delete`); usuário interno `bf6008f0…` (QA R14BlocoC) passou
  v1→v4 e voltou ao perfil Owner (memberships do perfil QA vazios ao final).
- Ambiente: deep link após carga fria passa por `/login` transitório e volta à rota; o renderer SwiftShader
  travou uma vez (Chrome reiniciado, sessão preservada pela caixa "Manter sessão aberta"). `tap` do driver
  não responde; usar `clickxy`, `enter_text` e `Input.dispatchKeyEvent`. `Emulation.clearDeviceMetricsOverride`
  não restaurou o viewport — restaurar com o tamanho original explícito.

## Resíduos encontrados (sem action_id novo; não bloqueiam)

- Perfis: tooltip aberto por foco de teclado não fecha ao avançar o foco (empilha); rótulo "Excluir" na
  matriz × nome "Inativar modelos Admin." no catálogo; `reason` da auditoria vem `[redacted]` no detalhe.
- Usuários internos: chip flutuante "Mensagens" cobre o botão "Continuar" do assistente em 1424×1125;
  detalhe em produção com títulos/textos "demonstrativo"/"nesta demonstração"; edição demora vários
  segundos em "Carregando o cadastro interno protegido".

## Bloqueios

- Nenhum aberto no fechamento desta fatia.

## Contadores

`validate-trackers.cjs` PASS após os deltas: FE 193/232, BE 174/219, E2E 166/186, Owner 28/53
(r12-20/21/22/24/25/26/27 → done). `entrega-atual.json` e `R12-owner-items.json` regravados pelo
`sync-r12-owner-records.cjs` (projeção).
