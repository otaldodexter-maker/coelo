# R14 Sessão 3 — Bloco C: prova local e bloqueios de rota

Data: 2026-09-15  
Worktree: `C:\Users\adrie\Documents\Coelo.worktrees\r14-c`  
Branch: `r14/bloco-c`  
Servidor preparado: `127.0.0.1:3016`  
Base publicada confirmada antes da execução: `origin/dev 5839a0ef2`  
Banco usado nas provas SQL: espelho Docker `supabase_db_coelo_mirror_r14`.

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

Os commits anteriores da Sessão 3 preservam a prova do mesmo diário
`d2c945d8`, a hierarquia Instituição → Unidade → Turma → período e as guardas
de não duplicação, mas a observação foi rebaixada por divergência de alvo CDP.
Sem nova sessão autenticada estável, close/reopen não é promovido.

## Ambiente e liberação

Não foi feita alteração em cabeçalho/contadores da R14, `current-state.md`,
checkpoint ou `entrega-atual.json`. Os contadores locais permanecem FE 184/231,
BE 166/224, E2E 157/192 e Owner 15/53. As telas de avaliações, perfis de acesso
e segurança infantil ficam liberadas explicitamente; Forms upload/resolve
também ficam liberadas e não foram reivindicadas novamente.
