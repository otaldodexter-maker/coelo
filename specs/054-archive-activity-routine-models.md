---
title: "Arquivar e restaurar modelos de Atividade e de Rotina (inativação reversível)"
source: "decisions/0041-owner-decisions-r14-mesa-20260916.md (B1, owner.r12-02); docs/open-questions.md (OQ-033 opção B, OQ-047); dump de schema de produção de 16/09/2026 (SHA-256 f1f677ca…): public.activity_templates, public.routine_models, app_private.superadmin_create_scoped_activity_template, app_private.superadmin_activity_template_options, app_private.superadmin_routine_save_model, app_private.superadmin_routine_directory; docs/reviews/evidence/etapa-2/r12-coordenacao/activity-model-actions-diagnostic-r12.md"
status: "draft-for-review"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
lifecycle: "current"
---

# Arquivar e restaurar modelos de Atividade e de Rotina

## Objetivo e decisão de produto

ADR 0041 B1 (`owner.r12-02`), aplicando OQ-033 opção B: **Arquivar** um modelo de
Atividade (`activities.list` › Modelos) ou de Rotina (`daily-routine.list` ›
Modelos) é uma **inativação reversível**:

- o modelo sai da lista padrão e passa a aparecer só no filtro/aba
  "Arquivados";
- "Restaurar" devolve o modelo à lista padrão com a mesma configuração;
- quem pode editar o modelo pode arquivá-lo e restaurá-lo (mesma permissão);
- atividades e rotinas já derivadas do modelo continuam válidas: nada em
  `activity_definitions`, `routine_applications` ou `routine_launches` é tocado;
- toda mutação exige `expected_version`, é idempotente por `request_id`, é
  auditada e a tela recarrega a lista após o sucesso.

Não há exclusão física. Esta spec não cria ciclo de vida para outras entidades
(spec de ciclo de vida da R15, OQ-033) nem altera Admin/Principal.

## Estado físico atual (dump de 16/09)

| Família | Tabela | Status | Versão | Leitura da lista | Comando existente |
|---|---|---|---|---|---|
| Atividade | `public.activity_templates` | `public.record_status` (`draft/active/inactive/suspended/archived`) | **não tem** `management_version` | `superadmin_activity_template_options(p_institution_id)` devolve só `status='active'` | `superadmin_create_scoped_activity_template` (contexto interno, `activities.templates.manage`, recibo + `audit_append_superadmin_internal`) |
| Rotina | `public.routine_models` | `text` (`draft/active/inactive/archived`) | `management_version bigint` | `superadmin_routine_directory(p_entry_kind,…,p_status,…)`: com `p_status` nulo devolve **todos** os status, inclusive `archived` | `superadmin_routine_save_model` (ator people-based `require_routine_actor('routine.manage_models')`, recibo `routine_command_receipts`, `audit.audit_logs`; versão defasada = `serialization_failure` 40001) |

Hoje "Arquivar" de Rotina no Superadmin reenvia o modelo inteiro por
`save_model` com `status='archived'`; Atividades não tem Arquivar. Os dois
diretórios mostram arquivados misturados (Rotina) ou nunca (Atividade).

## Contrato

### Estados

`status` continua sendo a única fonte. `archived` é o estado arquivado; a
restauração devolve o status anterior ao arquivamento:

- Atividade: guardado em `template_payload->'lifecycle'` (`archived_from`,
  `archived_at`); restaurar remove a chave e volta a `archived_from`
  (`active` se ausente).
- Rotina: `routine_models` já tem `draft/active/inactive`; o status anterior é
  guardado em `app_private.routine_model_lifecycle(model_id, archived_from,
  archived_at, archived_by_person_id)` e restaurar volta a ele (`active` se a
  linha não existir, caso de modelos arquivados pelo `save_model` antigo).

### Migration `20260916HHMMSS_archive_models_v1.sql` (forward-only, idempotente)

Atividade (contexto interno; mesma permissão da edição/criação de modelo:
`activities.templates.manage`):

- `alter table public.activity_templates add column if not exists
  management_version bigint not null default 0`.
- `app_private.superadmin_internal_activity_template_lifecycle_receipts`
  (`request_id` pk, `internal_identity_id`, `template_id`, `command`
  `archive|restore`, `request_hash` 32 bytes, `result_json`, `correlation_id`,
  `created_at`); RLS habilitada e forçada, sem policies (deny-by-default), sem
  grants para `anon`/`authenticated`.
- `public.superadmin_activity_template_directory_v1(p_institution_id uuid)`
  → `app_private.…` (STABLE, SECURITY DEFINER, `search_path=''`,
  `activities.read`): mesmo envelope de `superadmin_activity_template_options`
  (`institutions`, `units`, `taxonomy`, `templates`) mas `templates` inclui
  **todos os status** e cada item traz `management_version`. O leitor de
  opções do formulário continua devolvendo só `active` (arquivado não instancia
  atividade nova; `superadmin_duplicate_activity_template` já exige `active`).
- `public.superadmin_activity_template_archive_v1(p_template_id uuid,
  p_expected_version bigint, p_idempotency_key uuid)` e
  `public.superadmin_activity_template_restore_v1(…)` → `app_private.…`
  (SECURITY DEFINER, `search_path=''`): `require_superadmin_internal_context
  ('activities.templates.manage')`; modelo de escopo `institution`/`unit` só
  visível ao ator com escopo `platform` ou com `scope_institution_id` igual;
  modelo `platform` só por ator `platform`; fora disso `no_data_found`
  (não enumera). Versão: `management_version <> p_expected_version` →
  `raise exception using errcode='PT409', detail='ACTIVITY_TEMPLATE_STALE_VERSION'`
  (OQ-047: nunca 40001). Estado: arquivar exige `status <> 'archived'`, restaurar
  exige `status = 'archived'`; senão `object_not_in_prerequisite_state`
  (`ACTIVITY_TEMPLATE_STATE_INVALID`). Efeito: `status`, `template_payload
  ->'lifecycle'`, `management_version + 1`, `updated_at`. Idempotência:
  `pg_advisory_xact_lock('activity-template-lifecycle:'||key)`, recibo com
  `request_hash = sha256(template_id, expected_version, command)`; reuso da chave
  por outro ator → `insufficient_privilege`; outro hash → `invalid_parameter_value`.
  Auditoria: `audit_append_superadmin_internal(…, 'activities.templates.manage',
  aal, 'activity.template.archive'|'activity.template.restore', 'success', null,
  correlation, institution_id, 'activity_template', id, after_json)`. Retorno:
  `{id, status, management_version, archived_at}`.
- Grants: `revoke all … from public; grant execute … to authenticated,
  service_role` nos wrappers `public` (como os demais comandos da família);
  os `app_private` ficam sem grant a `authenticated`.

Rotina (ator people-based; mesma permissão da edição: `routine.manage_models`):

- `app_private.routine_model_lifecycle(model_id pk → routine_models,
  archived_from text, archived_at timestamptz, archived_by_person_id)`; RLS
  forçada, sem policies, sem grants.
- `public.superadmin_routine_model_archive_v1(p_request_id uuid, p_model_id uuid,
  p_expected_version bigint)` e `public.superadmin_routine_model_restore_v1(…)`
  → `app_private.…`: `require_routine_actor('routine.manage_models', false)`;
  `pg_advisory_xact_lock(model_id)`; `routine_receipt(p_request_id, actor,
  'archive_model'|'restore_model')` (replay devolve a mesma resposta); modelo
  fora do escopo (`routine_scope_allowed('routine.manage_models', …)`) →
  `no_data_found`; versão defasada → `PT409` (`ROUTINE_MODEL_STALE_VERSION`);
  estado inválido → `object_not_in_prerequisite_state`
  (`ROUTINE_MODEL_STATE_INVALID`). Efeito: `status`, `management_version + 1`,
  `updated_at`, linha em `routine_model_lifecycle` (arquivar) ou removida
  (restaurar, voltando a `archived_from`). Recibo em `routine_command_receipts`;
  auditoria em `audit.audit_logs` (`routine.model.archive`/`routine.model.restore`,
  `before_json`/`after_json`). Retorno: `{id, status, management_version}`.
- `app_private.superadmin_routine_directory` (create or replace, corpo idêntico
  ao dump exceto o filtro): para `model` e `application`, `p_status` nulo passa a
  significar **`status <> 'archived'`** (lista padrão); `p_status='archived'`
  devolve só arquivados. `launch` não muda (não tem `archived`).

### Erros (mapeamento FE)

| Situação | SQLSTATE / detail | FE |
|---|---|---|
| sem sessão/permissão | `42501` / `SAI_AUTH_REQUIRED`, `SAI_PERMISSION_DENIED` | "Seu acesso não permite arquivar/restaurar este modelo." |
| fora do escopo ou inexistente | `P0002` | "Modelo indisponível." (não enumera) |
| versão defasada | **`PT409`** (HTTP 409, sem retentativa do PostgREST) | "O modelo mudou desde que a lista foi carregada. Atualize e tente de novo." + reload |
| estado inválido (já arquivado / não arquivado) | `55000` | "O modelo já está nesse estado." + reload |
| chave reutilizada | `22023` | tratado como indisponível |

### Telas

- **Atividades › Modelos** (`activities.list`): aba **Arquivados** ao lado de
  Todos/Ativos/Rascunhos/Inativos (tabs lineares do diretório; "Todos" e
  "Inativos" **não** incluem arquivados). Card e linha da tabela: ação
  **Arquivar** (não arquivado) / **Restaurar** (arquivado), com confirmação em
  diálogo, `expected_version` do item carregado, recarga da lista após sucesso.
  Arquivado não oferece "Criar atividade por este modelo" nem "Duplicar"
  (o leitor de opções e o comando de duplicar já exigem `active`). O diretório
  passa a ler `superadmin_activity_template_directory_v1`; o formulário segue com
  `superadmin_activity_template_options`.
- **Rotina diária › Modelos** (`daily-routine.list`): filtro de status ganha
  **Arquivados**; lista padrão (sem filtro) não mostra arquivados; card/linha com
  Arquivar/Restaurar (fatia C3 já expôs a ação e o callback). `onArchive` do
  modelo passa a chamar `superadmin_routine_model_archive_v1` com a
  `management_version` do item; `onRestore` chama `…_restore_v1`. Rotinas
  aplicadas (`application`) continuam arquivando pelo `save_application`
  existente (fora desta spec; nota OQ-047).

### Permissões e RLS

Nenhuma tabela exposta muda de policy. Os comandos são SECURITY DEFINER com
`search_path=''`, validam ator, permissão, escopo (instituição do modelo vs.
escopo do ator) e versão no servidor; o cliente só solicita e renderiza. As
tabelas novas em `app_private` têm RLS forçada sem policies.

## Testes exigidos

pgTAP `packages/coelo_database/tests/archive_models_v1_test.sql` (espelho
restaurado do dump de 16/09): coluna e tabelas criadas; RLS forçada e ausência
de grants; wrappers `public` existentes com grants a `authenticated`; arquivar
Atividade muda status/`management_version`/lifecycle e audita; restaurar
devolve ao status anterior; `PT409` em versão defasada; `55000` em estado
inválido; replay idempotente; escopo `institution` não alcança modelo de outra
instituição nem modelo `platform` (`P0002`); diretório v1 lista arquivados com
`management_version` e opções segue só `active`; Rotina: arquivar/restaurar com
recibo, auditoria, `PT409`, `55000`, `P0002` fora do escopo; diretório padrão
não devolve arquivados e `p_status='archived'` devolve.

Flutter: repositórios (parâmetros e mapeamento `PT409`/`55000`/`P0002`),
diretórios (aba/filtro Arquivados, confirmação, reload, ação por estado).

## Aplicação em produção

Fora desta fatia: migration + pgTAP verdes no espelho ficam para a
coordenadora aplicar pelo rito (dump prévio, `db push --dry-run`, ledger,
`ordem-de-aplicacao-producao.txt`) e provar na rota real. Nenhum estado por
`action_id` muda antes disso.
