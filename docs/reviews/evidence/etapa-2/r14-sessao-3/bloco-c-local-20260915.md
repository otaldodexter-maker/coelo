# R14 Sessão 3 — Bloco C: prova local e bloqueios de rota

Data: 2026-09-15  
Worktree: `C:\Users\adrie\Documents\Coelo.worktrees\r14-c`  
Branch: `r14/bloco-c`  
Servidor preparado: `127.0.0.1:3016`  
Base publicada confirmada antes da execução: `origin/dev 5839a0ef2`  
Banco usado nas provas SQL: espelho Docker `supabase_db_coelo_mirror_r14`.

Após a execução paralela, a worktree foi atualizada por fast-forward para o
`origin/dev` publicado `e592063d6`.

O registro desta prova foi publicado nos commits `2e0aaaab3`, `d1025286d` e
`5ba0b5ddf` em `origin/dev`.

## Apoio de acesso QA remoto

Action ID: `superadmin.internal-users.create`.
Usuário sintético criado no Auth remoto pelo fluxo oficial
`internal-user-create`: `qa-r14-c-owner-20260915@coelo.me`, UID
`edb2c331-8b64-4779-a084-d32646eb415d`, criado em 2026-09-15 16:23:20 conforme
o dashboard Auth Users. A rota de detalhe confirmou nome `QA R14BlocoC`, cargo
`QA-Owner-R14-C`, perfil `Owner`, alcance `Global à plataforma`, convite
`Pendente` e credencial `Sem acesso`.

O link seguro de definição de senha apareceu somente no diálogo da aplicação;
não foi copiado, persistido ou exposto. A UI não expôs um correlation/action
UUID individual, portanto nenhum UUID foi inventado. O cadastro é massa de
apoio e não é prova dos action_ids `access-profiles.*`.

O servidor solicitado `127.0.0.1:3016` foi diagnosticado sem alteração de
produção: o preflight do Edge Function retornou 204 sem
`Access-Control-Allow-Origin`. A rota foi então exercitada em
`127.0.0.1:3014`, origem já allowlisted, e o detalhe autenticado do usuário foi
observado no Chrome com o CDP disponível em 9415. Fica pendente para R15 a
allowlist governada de 3016 e a repetição das provas com essa origem.

## Child safety

Action IDs: `child-safety.create`, `child-safety.edit`, `child-safety.suspend`.  
Owner items: `owner.r12-13`, `owner.r12-15`, `owner.r12-16`.

O diagnóstico inicial do 504 encontrou drift no espelho: o trigger de
sincronização de `follow_links` exigia a pessoa global
`c0e10000-0000-4000-8000-000000000001`, ausente na massa sintética. O fixture
nominal foi corrigido somente nos testes, sem mascarar timeout e sem tocar
produção. No espelho foram rebaselineadas as migrations já publicadas
`20260910170500`, `20260910170600`, `20260910170700`, `20260910171800`,
`20260910171900` e `20260910172100`. A migration de grant Owner `20260910172000`
foi tentada e rejeitada pelo próprio guard por capacidades Owner não relacionadas;
ela não foi forçada.

Resultados:

- `child_safety_platform_decision_v1_test.sql`: 25/25.
- `child_safety_production_test.sql`: 63/63.
- Sem alteração de ledger remoto, sem SQL em produção e sem promoção E2E.

O 504 não foi reproduzido após o rebaseline; isso prova a causa de drift do
espelho, não a certificação da rota autenticada. A tela continua liberada para
outra sessão até existir login e prova real de create/edit/suspend, escopo,
reload e `action_id` observável.

## Forms

Action IDs: `forms.expire-file`, `forms.delete-file`.  
Não foram repetidos `forms.upload` nem `forms.resolve-file`, pois já possuem
prova publicada em `r14-sessao-1/forms-upload-resolve-20260915.md`.

- `forms_question_media_terminal_unbind_v1_test.sql`: 7/7.
- `forms_question_media_retry_delete_v1_test.sql`: 9/9.

As provas cobrem mismatch, expiração, remoção do binding, retry idempotente,
delete nominal e negativa cross-tenant; permanecem locais ao espelho e não
promovem a certificação de rota/worker físico.

## Access profiles

Action IDs: `access-profiles.create`, `access-profiles.edit`,
`access-profiles.assign`.  
Owner items: `owner.r12-19` a `owner.r12-27`.

O teste de consumidor de modelos passou 9/9 após alinhar a expectativa ao
contrato atual: o código técnico é gerado internamente e não é um campo da
tela. Não houve criação, edição ou atribuição real confirmada. A tela de login
local foi aberta, mas não havia sessão autenticada/credencial QA disponível no
alvo CUA; portanto `/profiles` e `/internal-users/:id/edit` permanecem
explicitamente liberadas para outra sessão.

## Avaliações

Action IDs: `assessments.close`, `assessments.reopen`.  
Owner item: `owner.r12-49`.

O diário usado foi `d2c945d8-3809-4d84-b836-2bc6da7c381d`, sem duplicar diário,
participante ou vínculo, preservando a hierarquia Escola R04 Estrutura →
Unidade Centro R04 → Turma R05 Estrutura → período `R08 sintético`.
Na rota normal `/assessments/entry` o envio para fechamento foi confirmado e,
em `/assessments/closing/<diary-id>`, a revisão foi concluída com a razão
`R14 fechamento autorizado - QA em massa sintética`, gerando o evento imutável
`Revisado`, versão 11, às 17:11. A reabertura anterior permanece como evento
`Devolvido ao professor`, versão 9, razão `R14 reabertura autorizada`.
O reload da URL direta confirmou novamente o histórico e a versão 11. Os
action_ids são `assessments.close` e `assessments.reopen`; a promoção do
contador central continua a cargo da coordenação.

## Ambiente e liberação

Não foi feita alteração em cabeçalho/contadores da R14, `current-state.md`,
checkpoint ou `entrega-atual.json`. Os contadores locais permanecem FE 184/231,
BE 166/225, E2E 157/193 e Owner 15/53. Avaliações têm prova real de close/reopen;
as telas de perfis de acesso e segurança infantil ficam liberadas
explicitamente. Forms upload/resolve também ficam liberadas e não foram
reivindicadas novamente.
