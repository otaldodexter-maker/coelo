---
source: "Sessão 9 da R14 (Opus 5), 16/09/2026; ADR 0041 B1 (owner.r12-02); specs/054-archive-activity-routine-models.md; OQ-033 opção B; OQ-047 (PT409)"
status: evidence
generated_at: 2026-09-16
---

# Arquivar/Restaurar modelos de Atividade (`activities.list`) e de Rotina (`daily-routine.list`) — B1, 16/09/2026

Trabalho **local** (worktree `r14/visual-arquivar`): spec, migration, pgTAP no espelho próprio e FE com testes. **Nada
aplicado em produção**; nenhuma rota real (incidente PostgREST 504); nenhum estado por `action_id` alterado. A aplicação
em produção e a prova de rota real ficam para a coordenadora pelo rito (dump prévio, `db push --dry-run`, ledger,
`ordem-de-aplicacao-producao.txt`).

## Contrato

`specs/054-archive-activity-routine-models.md` (draft-for-review). Nomes verificados no dump de schema de produção de
16/09 (SHA-256 `f1f677ca…`): `public.activity_templates` (status `record_status`, **sem** versão de gestão; leitor
`superadmin_activity_template_options` devolve só `active`; comandos no contexto interno com
`activities.templates.manage`), `public.routine_models` (`status` text com `archived`, `management_version`; ator
people-based `require_routine_actor('routine.manage_models')`; `superadmin_routine_directory` devolvia arquivados
misturados quando `p_status` era nulo; Arquivar reenviava o modelo inteiro por `save_model`, que usa `40001`).

## Backend — migration `packages/coelo_database/migrations/20260916193000_archive_models_v1.sql`

Forward-only, idempotente (aplicada 2× no espelho sem erro), preflight, `lock_timeout 5s`/`statement_timeout 120s`:

| Família | Objeto | Regra |
|---|---|---|
| Atividade | `activity_templates.management_version bigint not null default 0` | `expected_version` dos comandos |
| Atividade | `app_private.superadmin_internal_activity_template_lifecycle_receipts` | recibo por `request_id` (hash de template+versão+comando); RLS forçada, sem policies/grants |
| Atividade | `public.superadmin_activity_template_directory_v1(uuid)` | mesmo envelope das opções, **todos os status** + `management_version` + `archived_at`; `activities.read`; o leitor de opções do formulário não muda |
| Atividade | `public.superadmin_activity_template_archive_v1(uuid,bigint,uuid)` / `_restore_v1` → `app_private.superadmin_activity_template_lifecycle_v1` | `activities.templates.manage`; escopo `institution` só alcança modelos da própria instituição (nunca `platform`) — fora disso `P0002`; versão defasada **`PT409`**; estado inválido `55000`; replay devolve o mesmo resultado; reuso da chave com outro pedido `22023`; status anterior guardado em `template_payload->'lifecycle'` e restaurado; `audit_append_superadmin_internal` (`activity.template.archive|restore`) |
| Rotina | `app_private.routine_model_lifecycle` | status anterior (`draft/active/inactive`) + ator; RLS forçada, sem grants |
| Rotina | `public.superadmin_routine_model_archive_v1(uuid,uuid,bigint)` / `_restore_v1` → `app_private.superadmin_routine_model_lifecycle_v1` | `require_routine_actor('routine.manage_models')`; `routine_receipt` (replay); `routine_scope_allowed` (fora `P0002`); **`PT409`**; `55000`; `management_version + 1`; `audit.audit_logs` (`routine.model.archive|restore`, before/after) |
| Rotina | `app_private.superadmin_routine_directory` (create or replace) | corpo idêntico ao dump exceto: `p_status` nulo ⇒ `status <> 'archived'` em `model` e `application`; `p_status='archived'` devolve só arquivados; `launch` inalterado |

Grants: wrappers `public` com `execute` para `authenticated`/`service_role` e revogados de `public`/`anon`; funções
`app_private` sem grant. Nenhuma tabela exposta muda de policy; derivados (`activity_definitions`,
`routine_applications`, `routine_launches`) não são tocados.

### pgTAP — `packages/coelo_database/supabase/tests/archive_models_v1_test.sql`: **63/63** no espelho

Espelho `coelo_mirror_r14_visual` (portas 619xx) restaurado do dump de 16/09 (0 erros) + catálogo de referência
`mirror-r14/supabase/seed.sql`; permissões de Rotina semeadas na fixture (rollback total). Cobertura: estrutura (coluna,
tabelas, RLS forçada, privilégios, grants dos wrappers, ausência de `serialization_failure`, PT409 presente,
`security definer` + `search_path` vazio, leitor de opções segue só `active`); Atividade: arquivar (status, versão,
lifecycle no payload, recibo único, auditoria interna com ator/objeto/instituição), replay, diretório v1 lista o
arquivado com versão, opções não o listam, `55000` em duplo arquivamento e em restaurar não arquivado, `PT409`,
`22023`, restaurar volta ao status anterior e limpa o lifecycle, ator restrito a A não alcança B nem modelo Coelo
(`P0002`, linhas intocadas) mas arquiva o de A, sem sessão `42501`; Rotina: lista padrão 2 → 1 após arquivar, `archived`
devolve 2 (inclusive o arquivado pelo save antigo), `active` filtra, `archived_from=draft`, recibo único, auditoria com
before/after, `PT409`, `55000` ×2, restaurar volta a `draft` e o legado volta a `active`, leitor `42501` sem mutação.

Testes pré-existentes no espelho (`daily_routine_directory_can_manage_v1_test`, `activity_template_unit_scope_test`,
`activity_template_create_test`) falham **antes** de qualquer função desta fatia (FK `follow_links` na pessoa técnica
Coelo ausente na fixture antiga e ACL do espelho) — deriva de fixture/ambiente, não regressão.

## Frontend

- Atividades: `ActivityTemplateOption.managementVersion`/`isArchived`; interfaces `ActivityTemplateDirectoryReader`
  (leitor v1) e `ActivityTemplateLifecycleRepository` (`archiveTemplate`/`restoreTemplate`) implementadas por
  `SupabaseActivityDirectoryRepository`/`SupabaseActivityCommandRepository`; `_mapError` ganha `PT409` → conflito,
  `P0002` → não encontrado, `55000` → estado inválido. Diretório de modelos: aba **Arquivados** (enum compartilhado
  `CoeloAdminDirectoryStatusTab.archived`, fora de `defaults` — os demais diretórios não mudam), "Todos"/"Inativos"
  sem arquivados, card/linha com **Arquivar** (não arquivado) ou **Restaurar** (arquivado; sem Começar/Duplicar),
  diálogo de confirmação, recarga após sucesso; router: `activityTemplateLifecycle` com avisos por erro.
- Rotina: `RoutineDirectoryItem.managementVersion`; `RoutineModelLifecycleRepository` (`archiveModel`/`restoreModel`)
  em `SupabaseRoutineRepository` (`PT409` → conflito, `55000` → `invalidState`); filtro **Status** com "Arquivados" na
  toolbar (`daily-routine-status-filter`); router usa os comandos v1 para modelos (`_archiveRoutineEntry` /
  `_restoreRoutineEntry`), mantendo `save_application` para rotinas aplicadas.

Testes: `supabase_activity_template_lifecycle_test` 6/6 (RPCs, parâmetros, mapeamento de erros, fail-closed, leitor v1
vs opções); `supabase_routine_data_test` +3 (comandos v1, `management_version` no diretório, `PT409`/`55000`);
`activity_template_archive_test` 6/6 (leitor v1, aba Arquivados, Arquivar → confirmação → callback com a versão
carregada → recarga, Restaurar, tabela, sem callbacks); `daily_routine_directory_cards_test` +1 (filtro envia
`archived` e volta a nulo). Pastas `daily_routine` + `activities` + rotas: **+527 ~4 -10** — as 10 falhas são
pré-existentes: 9 goldens de `activity_golden_test` (deriva do cabeçalho, fora da C1; só
`activity_directory_models_light_1440` mudou de 5.517 para 8.019 px pela aba Arquivados desta fatia —
`capturas/atividades-modelos-1440-local.png`) e `activity_routes_test` "Editar atividade" (o botão virou
`FilledButton` em `c58ab61ca`, 12/09, e o teste espera `OutlinedButton`). Goldens de Rotina regravados pela toolbar com o
filtro Status (`capturas/rotina-toolbar-filtro-status-1440.png`). `coelo_ui_admin` 158/158.

## Estado

`owner.r12-02` → `partial / FE local-green + BE local-green (espelho)`. Pendente para a coordenadora: aplicar
`20260916183000` em produção pelo rito, provar Arquivar/Restaurar/filtro Arquivados/reload/negativa na rota real dos
dois diretórios. Sobra: Restaurar de rotinas aplicadas (spec de ciclo de vida da R15); goldens de Atividades exigem
estender a C1.
