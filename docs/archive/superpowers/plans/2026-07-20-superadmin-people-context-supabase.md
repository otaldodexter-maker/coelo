---
title: "Superadmin People Context Supabase Implementation Plan"
source: "docs/superpowers/specs/2026-07-20-superadmin-floating-navigation-people-context-design.md"
status: "approved-for-implementation"
generated_at: "2026-07-20"
---

# Superadmin People Context Supabase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Materializar no Supabase os vinculos profissionais, contextos infantis, relacoes familiares, solicitacoes e convites necessarios ao futuro diretorio global de Pessoas.

**Architecture:** Preservar `people` como identidade global e normalizar autorizacao em memberships, papeis e escopos. Novas tabelas publicas recebem RLS, grants explicitos e policies de leitura restritas a `platform.read`; mutacoes permanecem server-side. Views `security_invoker` oferecem leitura global minimizada ao Superadmin.

**Tech Stack:** PostgreSQL 17, Supabase, SQL migrations, RLS, SQL validation scripts.

## Global Constraints

- Nomes fisicos em ingles e textos de UI em portugues.
- Nenhum seed de pessoa, crianca, vinculo, convite ou instituicao.
- `service_role` nunca entra no cliente Flutter.
- Tabelas publicas novas exigem grants explicitos e RLS.
- Views expostas usam `security_invoker = true`.
- Identidade global nunca e duplicada por tenant ou papel.
- Fluxos de escrita sensiveis ficam para RPC/Edge Function posterior; esta migration expoe somente leitura ao cliente autenticado com `platform.read`.

---

### Task 1: Escrever o teste SQL estrutural em estado RED

**Files:**
- Create: `packages/coelo_database/tests/2026-07-20-people-context-foundation-validation.sql`

**Interfaces:**
- Consumes: tabelas existentes `people`, `institutions`, `units`, `groups`, `institution_memberships`, `invitations`.
- Produces: validacao executavel das novas tabelas, FKs, constraints, RLS, grants, views e cenarios de integridade.

- [ ] **Step 1: Criar validacoes estruturais**

O script deve iniciar com `begin;`, falhar com `raise exception` quando qualquer objeto estiver ausente e terminar com `rollback;`. Validar estas tabelas:

```sql
array[
  'institution_roles',
  'institution_permissions',
  'institution_role_permissions',
  'institution_role_assignments',
  'guardian_links',
  'child_contexts',
  'child_unit_links',
  'child_group_links',
  'guardian_context_permissions',
  'child_unit_access_requests',
  'child_unit_access_request_children'
]
```

Validar tambem `person_directory`, RLS em todas as tabelas, ausencia de `anon`, `SELECT` para `authenticated`, ausencia de `INSERT/UPDATE/DELETE` para `authenticated` e policy com `app_private.has_platform_permission('platform.read')`.

- [ ] **Step 2: Adicionar cenarios transacionais**

O script deve criar dados dentro da transacao e comprovar:

```sql
-- mesma pessoa adulta em duas instituicoes;
-- mesma pessoa com membership profissional e guardian_link;
-- crianca aceita na unidade com status awaiting_allocation e sem grupo;
-- child_group_link rejeitado quando o grupo nao pertence a unidade;
-- solicitacao rejeitada sem guardian_link ativo;
-- convite por instituicao independente para o mesmo target_person_id.
```

- [ ] **Step 3: Executar no remoto e confirmar RED**

Executar o script com a ferramenta Supabase `execute_sql` no projeto `evvbomzejfijozbtgvpt`.

Expected: falha em `public.institution_roles is missing` ou no primeiro objeto novo ausente.

### Task 2: Criar a migration minima da fundacao de contexto

**Files:**
- Create: `packages/coelo_database/migrations/20260720180000_people_context_foundation.sql`

**Interfaces:**
- Consumes: enums `person_type`, `record_status`, FKs e `app_private.has_platform_permission(text)`.
- Produces: tabelas e views listadas na Task 1.

- [ ] **Step 1: Criar enums de lifecycle especificos**

```sql
create type public.child_unit_link_status as enum (
  'pending', 'awaiting_allocation', 'active', 'inactive', 'revoked'
);
create type public.access_request_status as enum (
  'pending', 'accepted', 'declined', 'cancelled'
);
create type public.invitation_state as enum (
  'pending', 'accepted', 'revoked', 'expired'
);
```

Usar blocos `do $$ ... exception when duplicate_object then null; end $$;` para migrations reexecutaveis em ambientes de validacao.

- [ ] **Step 2: Criar catalogos e atribuicoes institucionais**

Criar:

```sql
institution_roles(
  id, institution_id, code, name, description, is_system,
  status, created_at, updated_at
)
institution_permissions(
  id, code, module_code, screen_code, action_code, description,
  risk_level, requires_mfa, status, created_at, updated_at
)
institution_role_permissions(
  id, role_id, permission_id, effect, conditions_json,
  granted_by, created_at, revoked_at, status
)
institution_role_assignments(
  id, membership_id, role_id, scope_kind,
  scope_unit_id, scope_group_id, starts_at, expires_at,
  granted_by, status, created_at, updated_at
)
```

Adicionar indices parciais para unicidade de `code` global/local e constraints de escopo: instituicao nao aceita unit/group; unidade exige unit e proibe group; grupo exige unit e group.

- [ ] **Step 3: Criar tabelas familiares e infantis**

```sql
guardian_links(
  id, guardian_person_id, child_person_id, relation_type,
  status, created_at, updated_at, revoked_at
)
child_contexts(
  id, child_person_id, institution_id, local_identifier,
  status, created_at, updated_at, archived_at
)
child_unit_links(
  id, child_context_id, unit_id, status,
  accepted_by, accepted_at, created_at, updated_at, revoked_at
)
child_group_links(
  id, child_unit_link_id, group_id, status,
  starts_at, ends_at, created_at, updated_at
)
guardian_context_permissions(
  id, guardian_link_id, child_context_id,
  can_view, can_message, can_react,
  status, starts_at, expires_at, created_at, updated_at
)
```

Adicionar uniques ativos e FKs com delete adequado. Usar trigger `security invoker` com `set search_path = public, pg_temp` para garantir `person_type = 'child'` e coerencia instituicao-unidade-grupo.

- [ ] **Step 4: Criar solicitacoes e evoluir convites**

```sql
child_unit_access_requests(
  id, requested_by, unit_id, message, status,
  decided_by, decided_at, created_at, updated_at, cancelled_at
)
child_unit_access_request_children(
  request_id, guardian_link_id, child_person_id, created_at
)
```

Evoluir `invitations` com `invitation_state`, `unit_id`, `group_id`, `invited_by`, `target_contact_hash`, `masked_destination`, `sent_at`, `last_sent_at`, `send_count` e `accepted_by`. Adicionar FK de `institution_id` e check que exige `target_person_id` ou `target_contact_hash`.

- [ ] **Step 5: Criar view global minimizada**

```sql
create view public.person_directory
with (security_invoker = true)
as
select
  person.id,
  person.person_type,
  person.display_name,
  person.status,
  exists (
    select 1 from public.person_auth_links auth_link
    where auth_link.person_id = person.id and auth_link.status = 'active'
  ) as has_active_login,
  (select count(*) from public.institution_memberships membership
   where membership.person_id = person.id and membership.status = 'active') as institution_count,
  (select count(*) from public.guardian_links link
   where link.guardian_person_id = person.id and link.status = 'active') as child_count
from public.people person
where person.deleted_at is null;
```

- [ ] **Step 6: Adicionar RLS, grants, policies, indices e catalogo**

Para cada tabela nova:

```sql
alter table public.<table> enable row level security;
revoke all on table public.<table> from anon, authenticated;
grant select on table public.<table> to authenticated;
grant all on table public.<table> to service_role;
create policy <table>_platform_read on public.<table>
  for select to authenticated
  using ((select app_private.has_platform_permission('platform.read')));
```

Revogar `anon` da view, conceder `SELECT` a `authenticated` e registrar tabelas/colunas em `schema_tables`/`schema_columns` sem seed de dominio.

- [ ] **Step 7: Aplicar no projeto Supabase**

Aplicar o SQL versionado com `supabase_apply_migration` usando nome `people_context_foundation`. O historico remoto usa a versao gerada pela plataforma; o repositorio preserva a versao local `20260720180000` e o mesmo nome descritivo.

Expected: migration aplicada uma unica vez e historico remoto contendo `people_context_foundation`.

### Task 3: Validar schema, seguranca e performance

**Files:**
- Modify: `packages/coelo_database/tests/2026-07-20-people-context-foundation-validation.sql`

**Interfaces:**
- Consumes: migration aplicada.
- Produces: evidencia de schema valido e lista de advisors.

- [ ] **Step 1: Executar o teste SQL completo**

Executar com `supabase_execute_sql`.

Expected: retorno sem exception; todas as insercoes de validacao revertidas pelo `rollback`.

- [ ] **Step 2: Confirmar migration e tabelas remotas**

Usar `supabase_list_migrations` e `supabase_list_tables` no projeto `evvbomzejfijozbtgvpt`.

Expected: migration presente, novas tabelas com `rls_enabled = true` e zero linhas apos rollback.

- [ ] **Step 3: Executar advisors**

Usar `supabase_get_advisors` para `security` e `performance`.

Expected: nenhuma nova vulnerabilidade critica; corrigir avisos causados por esta migration antes de continuar.

- [ ] **Step 4: Verificar diff e commit**

Run: `git diff --check`

Expected: sem erros.

```bash
git add packages/coelo_database/migrations packages/coelo_database/tests
git commit -m "feat(database): add people context foundation"
```
