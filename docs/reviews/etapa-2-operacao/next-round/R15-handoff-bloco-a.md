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
| Conta (`/profile`) | account.profile | r12-46 | 17/09 11:00 BRT |
| Formulários (create/edit, delete-file, expire-file, location-answer) | forms.* | r12-39, r12-40 | 17/09 11:20 BRT |
| errors.409 | errors.409 | — | 17/09 11:30 BRT |
| auth.recover/reset (E8) | auth.recover, auth.reset | r12-47 | depois |
| (liberado para a C1 em 17/09 ~12:10 BRT, a pedido da coordenadora) | momentos.view/publish/remove/create | — | — |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 900608be9 | (código) Usuários internos: `/internal-users/:id/edit` carrega o catálogo de instituições também na edição (`_loadRemote` + `loadInstitutions` na rota); antes o passo "Acesso ao Superadmin" ficava em "Catálogo de instituições indisponível" e perfil/escopos somente leitura, o que impedia `access-profiles.assign` pela rota real. +2 testes de widget (vermelho → verde, 23/23); goldens do diretório seguem na deriva do cabeçalho (ADR 0041 C1). | — | apps/superadmin/test/features/platform_users/presentation/platform_user_form_context_test.dart |
| (este) | access-profiles.edit FE verified + E2E verified-e2e (v1→v2 pela tela, reload, 409 PT409 sem mutação após lote 75, 400 22023 instituição alheia); access-profiles.assign FE verified + E2E verified-e2e (perfil QA atribuído a `bf6008f0…`, memberships relidos, reload, Owner restaurado, 409 SAI_CONCURRENT_CHANGE / 403 SAI_PERMISSION_DENIED) | r12-20, 21, 22, 24, 25, 26, 27 → done | r15-bloco-a/access-profiles-edit-assign-20260917.md; deltas-access-profiles-20260917.json; capturas 00–18 |
| (este) | institutions.access-denied e institutions.error: FE verified, BE done, E2E verified-e2e (deep link inexistente → Acesso não autorizado sem dado + reload; RPC bloqueada por CDP → Não foi possível carregar + Tentar novamente recupera; 403 SAI_PERMISSION_DENIED por PostgREST sem enumeração); ADR 0041 A4 capturado (aviso "Arquivos em desenvolvimento") | — | r15-bloco-a/institutions-error-access-denied-20260917.md; deltas-institutions-20260917.json; deltas-institutions-backend-20260917.json; capturas institutions-00–06 |
| (este) | account.profile: BE done + E2E verified-e2e (FE já verified): foto PNG real via seletor nativo (CDP) → R2 privado (account-media), avatar do cabeçalho após confirmação, reload, nova sessão, remover foto, sigla, celular inválido/válido, asset alheio/removido → denied | r12-46 → partial (só máscara/normalização do Celular pendente) | r15-bloco-a/account-profile-20260917.md; deltas-account-20260917.json; capturas account-00–07 |
| (este) | forms.create e forms.edit FE verified + E2E verified-e2e (BE já done): editor real, renomear seção, mover pergunta, salvar, reload, prévia; 409 PT409 FORMS_STALE_VERSION, 400 23514 instituição alheia; forms.delete-file FE verified + BE done + E2E verified-e2e (upload real → excluir → reload sem imagem; 404 FORM_MEDIA_NOT_FOUND) | r12-39, r12-40 → done | r15-bloco-a/forms-create-edit-delete-file-20260917.md; deltas-forms-20260917.json; capturas forms-00–07 |
| 0a853525b / ab96072de | (código) sincroniza de dev os 22 repositórios com `PT409` (6c2f02ee0) e cobre `PT409 → conflict` no teste do cliente de Formulários; `notices` fica na versão da base + PT409 (a de dev exige `PrincipalForYouReader`, ausente aqui) | — | apps/superadmin/test/features/forms/data/supabase_forms_api_test.dart |
| (este) | errors.409 FE verified (flutter-only): conflito real 409 PT409 pela tela; antes do mapeamento a tela mostrava o genérico "Não foi possível concluir a ação" (00), depois "O formulário foi alterado em outra sessão. Recarregue…" (01) | — | r15-bloco-a/errors-409-20260917.md; deltas-errors-409-20260917.json |

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
- errors.409/OQ-047: qualquer tela cujo repositório não mapeie `PT409` mostra o genérico "Não foi possível concluir a ação" em conflito real; dev já cobre 22 repositórios (6c2f02ee0); conferir mapeadores fora de `data/` ao adicionar RPCs.
- Formulários: rótulos padrão do formulário novo parecem estado de erro ("Seção sem dados disponíveis"); campo Instituição do editor quebra em coluna estreita; URL fica em `/forms/new` após o primeiro save; `superadmin_forms_editor_v2`/`save_draft_v2` negam (403) a identidade QA via PostgREST enquanto a tela usa `form_get_editor`/`form_save_draft`; `form_get_editor` com id inexistente → 500 P0002.
- Conta: Celular sem máscara/normalização (só 7–40 caracteres; servidor grava como digitado); Edge `account-media` responde 422 (não 403) para asset alheio; avatar do cabeçalho fica vazio ~1 s após login novo até a leitura assinada.
- Usuários internos: chip flutuante "Mensagens" cobre o botão "Continuar" do assistente em 1424×1125;
  detalhe em produção com títulos/textos "demonstrativo"/"nesta demonstração"; edição demora vários
  segundos em "Carregando o cadastro interno protegido".

## Em andamento (17/09 ~14:15 BRT)

- `forms.expire-file`: asset `9e437fa9…` (question-image do form `90b905a1…`) deixado **pendente** às 16:53Z
  (PUT do R2 bloqueado por CDP); tela mostra "Imagem 1 não confirmada" após reload; `form-media resolve` →
  409 FORM_MEDIA_NOT_READY. Aguardando o worker do cron (ticket 30 min + 5 min) para provar 404 + reload sem
  a imagem; rascunho da evidência em `r15-bloco-a/forms-expire-file-20260917.md`.
- `forms.location-answer`: form `4555ba07…` ("[R04-QA] Formulario Local editado", v4 com pergunta Local)
  ganhou ocorrências novas pela tela (agendamento existente trocado para "Diário" → 31 ocorrências; a de
  17/09 é `7256b047-9e17-443d-b943-731243971f95`, `open`, 11 elegíveis). **Bloqueio de massa**: nenhuma das
  11 pessoas da audiência tem conta e a pessoa de `qa-r06-formularios` não é participante → `form_get_occurrence_for_response`
  devolve "unavailable"; não há tela que liste ocorrências ao respondente (deep link apenas) e
  `form_occurrences` nega 42501 via PostgREST (correto). Pedido à coordenadora: leitura D1 do vínculo
  pessoa↔conta QA para criar o vínculo pela tela Pessoas, ou usar a conta do responsável QA R15 (AP-1).
- `auth.recover`/`auth.reset` (E8): servidor QA também em `127.0.0.1:8765` (allowlist já contém
  `http://127.0.0.1:8765/reset-password`); aguarda o Owner na caixa `adrieldasbc@live.com` e a senha nova.

## Bloqueios

- `forms.location-answer` — massa: respondente com conta dentro da audiência (ver acima).
- `auth.recover/reset` — Owner (caixa de e-mail e senha nova).

## Contadores

`validate-trackers.cjs` PASS após os deltas: FE 197/232, BE 176/219, E2E 170/186, Owner 30/53
(r12-20/21/22/24/25/26/27/39/40 → done; r12-46 partial). `entrega-atual.json` e `R12-owner-items.json` regravados pelo
`sync-r12-owner-records.cjs` (projeção).
