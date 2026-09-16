---
source: "Sessão 8 da R14 (Opus 5, backend), 16/09/2026; ADR 0041 D3; owner.r12-05; r14-coordenacao/attendance-activity-blocked-20260915.md; r14-sessao-1/attendance-create-20260915.md"
status: evidence
lifecycle: current
generated_at: 2026-09-16
---

# Assiduidade › Nova chamada › contexto Atividade (`attendance.create`; owner.r12-05) — escopo de `superadmin_attendance_context_options` (16/09/2026)

Ambiente: produção `evvbomzejfijozbtgvpt` só em leitura de metadados (ADR 0041 D1, `supabase db query
--linked`); espelho próprio `coelo_mirror_r14_seguranca` (dump de schema de hoje, SHA-256 `f1f677ca…`,
catálogo de referência) com massa sintética criada SÓ no espelho. Nenhuma criança/vínculo criado
(D6 negado). Nenhuma tela executada nesta fatia (ver bloqueio).

## 1. Divergência identificada (migration `20260910220700` × dump de produção)

Em `app_private.superadmin_attendance_context_options(date)`:

| Lista | Filtros de escopo |
|---|---|
| `institutions` | `i.status='active' and i.deleted_at is null` |
| `units` | `u.status='active'` + instituição ativa/não excluída |
| `groups` | `g.status='active'` + `u.status='active'` + instituição ativa/não excluída |
| `activities` (antes) | apenas `g.status='active'` (turma) — **sem** filtro de unidade/instituição |

Confirmação em produção (leitura): a atividade `95b98978` "Atividade R05 Estrutura (editada)" e a
`085da87e` "Atividade R06 Arroba" pertencem a **"Escola R04 Estrutura" (`190dd028`, `status = draft`)**,
unidade `f5284f2f` ativa, turmas `4214106c`/`ea3986b7` ativas. Por isso apareciam em `activities` com
`institution_id/unit_id/group_id` ausentes de `institutions/units/groups`, e a cascata do cliente
(que filtra a atividade pela turma escolhida) nunca oferecia "Atividade". É inconsistência de escopo
na RPC (não de massa): a lista de atividades não respeitava o estado da instituição.

## 2. Correção forward-only (`20260916154500_attendance_context_options_activity_scope_v1.sql`)

Decisão do Owner (D3): alinhar o escopo de `activities` ao de `groups`. A CTE de atividades passa a
juntar `units` (`status='active'`) e `institutions` (`status='active'`, `deleted_at is null`) e a
exigir coerência `link.unit_id = g.unit_id` e `link.institution_id = g.institution_id`. Corpo restante,
assinatura, `STABLE SECURITY DEFINER`, `search_path=''`, wrapper público e grants idênticos ao dump
de produção. Preflight/pós-verificação, `lock_timeout 5s`, `statement_timeout 120s`, idempotente
(aplicada 2× no espelho).

## 3. pgTAP no espelho (`attendance_context_options_activity_scope_v1_test.sql`)

Fixture: instituição ativa A (unidade A1 ativa + turma A1 + atividade vinculada; unidade A2 inativa +
turma A2 + atividade vinculada) e instituição C em `draft` (unidade/turma/atividade ativas); ator Owner
de plataforma com `attendance.read/manage`, RPC pública chamada como `authenticated`.

- Com o **corpo de produção** (defeito): **3/11 falham** — "atividade de instituição draft não é
  oferecida", "atividade de unidade inativa não é oferecida" e a invariante "nenhuma atividade
  oferecida tem escopo ausente de institutions/units/groups".
- Após a migration: **11/11** (atividade elegível oferecida com instituição, unidade e turma presentes
  nas listas; draft e unidade inativa excluídas; invariante válida; grants e SECURITY DEFINER preservados).
- Suíte v1 existente (`attendance_dashboard_access_and_context_options_v1_test.sql`) não roda no
  espelho por drift de catálogo (`unit_types.code='sede'` ausente; `anon` com execute por default
  privileges locais) — falhas anteriores à migration e não relacionadas.

## 4. Aplicação em produção — BLOQUEADA (ambiente/permissão)

Mesmo bloqueio da fatia 1: `db push --dry-run` inviável (51 versões remotas sem arquivo local) e
`supabase db query --linked -f` negado pelo classificador de permissões do executor. Nenhuma escrita
em produção. Comando pronto para o Owner/coordenadora:
`supabase db query --linked --workdir packages/coelo_database -f packages/coelo_database/migrations/20260916154500_attendance_context_options_activity_scope_v1.sql`
+ `supabase migration repair --status applied 20260916154500 --linked --workdir packages/coelo_database`.

## 5. Plano da prova pela tela (após a aplicação)

Após a correção, **nenhuma atividade elegível existe na massa do escopo QA** (as duas atividades
vinculadas pertencem à instituição `draft`). Conforme o recorte da sessão, a prova de `/attendance/new`
exige antes criar pela tela do superadmin uma atividade "R14 S8 …" e vinculá-la à turma
`368a5cea` (QA R04 Cuidado › Unidade QA R04) — `activities.create/link`, já `verified-e2e` — e então:
contexto "Atividade" na cascata, criação da chamada, reload, e negativa por PostgREST
(`superadmin_attendance_create_call` com atividade de outra instituição → 403 `42501`). Não executado
nesta sessão por depender da migration em produção.

## Separação FE / BE / E2E

- FE: sem alteração.
- BE: divergência confirmada em produção (leitura) e no espelho; migration + pgTAP 11/11 no espelho;
  **não aplicada em produção**. `attendance.create` permanece `done`/`verified-e2e` (contexto Turma);
  estados do inventário inalterados.
- E2E do contexto Atividade e `owner.r12-05`: pendentes até a aplicação + prova pela tela.
