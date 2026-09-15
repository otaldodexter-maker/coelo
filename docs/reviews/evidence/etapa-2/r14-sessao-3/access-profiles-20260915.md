# R14 Sessão 3 — Perfis de acesso: prova focal e bloqueio

Data: 2026-09-15
Worktree: `C:\Users\adrie\Documents\Coelo.worktrees\r14-c`
Branch: `r14/bloco-c`

## Escopo e reivindicação

Action IDs exclusivos desta prova: `access-profiles.create`,
`access-profiles.edit` e `access-profiles.assign`. Owner items:
`owner.r12-19` a `owner.r12-27`. A conferência dos handoffs R14 confirmou que
a Sessão 1 não executou Perfis, a Sessão 3 os liberou explicitamente e não há
reivindicação ativa conflitante. O executor de código permanece C01; esta
execução é a retomada autorizada da Sessão 3 em sua worktree.

Fora do escopo: child-safety, forms, assessments, Cardápios, Agora, Chat,
Conta/avatar/Celular, Auth/e-mail e Planos comerciais.

## Contrato oficial e rota

`specs/018-profiles-permissions-superadmin.md` e `decisions/0017-access-profile-governance.md`
definem:

- `/profiles` para criação/edição; o cliente chama
  `superadmin_access_profile_detail` e `superadmin_access_profile_save`;
- `/internal-users/:id/edit` para atribuição, usando
  `superadmin_internal_user_update` com `profile_id`; não existe RPC de
  atribuição separada no cliente;
- `request_id`, `expected_version`, motivo, draft completo, auditoria,
  idempotência e derivação server-side de ator/tenant;
- autorização por capacidade, ownership/tenant, escopo máximo e negativa
  cross-tenant; Principal permanece read-only e não recebe perfil reutilizável.

## Prova local

Comando executado em `apps/superadmin`:

```text
flutter test test/features/access_profiles/data test/features/access_profiles/domain test/features/access_profiles/presentation/access_profile_form_context_test.dart test/features/access_profiles/presentation/access_profile_form_continuation_test.dart test/features/access_profiles/presentation/access_profile_form_receipt_test.dart test/features/access_profiles/presentation/access_profile_view_model_test.dart test/features/access_profiles/presentation/model_command_consumer_test.dart test/app/router/access_profile_routes_test.dart test/app/router/access_profile_authorization_revision_test.dart test/app/router/access_profile_editor_authorization_test.dart test/features/platform_users/data/supabase_platform_user_repository_test.dart --reporter compact
```

Resultado: **312 testes PASS**. A prova cobre envelope de save, geração do
identificador técnico, versionamento/conflito, replay/idempotência, estados de
erro, autorização/redução de contexto, rota injetada, persistência de draft no
view-model, `profile_id` no update de usuário interno e negativas modeladas.
Não há dados reais ou credenciais no artefato.

O lote amplo anterior também executou, mas falhou somente em três goldens
visuais (`access_profile_golden_test.dart`): cards responsivos, tab hover e
editor/revisão. A comparação mostra divergência de referência em dados do
header (`Owner Coelo` versus `Conta Superadmin`), MFA/rodapé e textos
posicionados. Goldens não foram regenerados nem promovidos sem aprovação do
Owner; isso não é evidência de falha de contrato de comando.

## Rota real, persistência e negativas

Não certificadas nesta retomada. A aba CUA disponível está em
`http://127.0.0.1:3016/login`, sem sessão autenticada QA; não foi possível abrir
`/profiles` ou `/internal-users/:id/edit`, executar mutação sintética, recarregar
ou observar o `action_id` real. Portanto não houve mutação remota e nenhuma
credencial foi criada, transmitida ou registrada.

Estado por camada: FE local coberto pelos 312 testes, mas aceite visual ainda
pendente; BE contrato coberto por testes de cliente, sem nova aplicação remota;
E2E **blocked** por sessão/CDP/origem. A prova remota anterior registrou que
`127.0.0.1:3016` não estava na allowlist CORS (preflight 204 sem
`Access-Control-Allow-Origin`); não há autorização para alterar produção por
inferência.

O replay Supabase descartável oficial foi tentado com o alvo
`20260901200206` e os três testes pgTAP de Perfis. O guard abortou antes de
iniciar Docker porque esse alvo está no manifesto histórico, mas não identifica
uma migration única em `packages/coelo_database/migrations/` da cadeia
canônica atual. Resultado concreto: `target version must identify exactly one
canonical migration`. Nenhum recurso, ledger ou banco remoto foi alterado; não
foi usado fallback de cópia de migration.

## Encaminhamento

Sem delta de tracker: a mudança de estados continua exclusiva de
`apply-tracker-delta.cjs`, e não há base para promoção. A prova funcional
independente está preservada; o aceite visual e a rota autenticada devem ser
retomados na R16 com sessão QA válida, origem allowlisted/CDP correto, mutação
synthetic-only, reload, negativa cross-tenant e evidência minimizada.
