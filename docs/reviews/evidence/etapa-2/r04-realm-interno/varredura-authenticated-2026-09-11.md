---
title: "Varredura dos grants de authenticated sem policy RLS (Rodada 4, realm-interno)"
source: "supabase db query --linked (somente leitura), information_schema.role_table_grants x pg_policies"
status: "pendencia de code review; somente leitura; nenhum revoke aplicado"
generated_at: "2026-09-11"
environment: "Supabase coelo / evvbomzejfijozbtgvpt (producao, sem clientes reais); PostgreSQL 17.6; sessao postgres do CLI"
janela_de_medicao: "2026-09-11 08:25-08:30 America/Sao_Paulo (11:25-11:30 UTC), relogio do servidor Postgres"
---

# Varredura dos grants de `authenticated` sem policy RLS

Continuacao da varredura prometida no cabecalho da migration
`20260910240600_revoke_authenticated_truncate_references_trigger_v1.sql`
(lote 13): registrar, como pendencia de code review, os privilegios
INSERT/UPDATE/DELETE/SELECT que `authenticated` ainda tem em tabelas sem policy
RLS correspondente. Mesmo metodo dos pacotes 240500 (`anon`) e 240600
(TRUNCATE/REFERENCES/TRIGGER). Nada foi revogado; a decisao do coordenador de
11/09 00:30 e nao aplicar pacote nesta rodada.

## Resumo

| Medida (tabelas distintas, schemas public/app_private/audit/analytics) | Preliminar 11/09 00:05 | Esta varredura |
| --- | ---: | ---: |
| Objetos com algum grant a `authenticated` | 140 | 140 (134 tabelas + 6 views, todos em `public`) |
| INSERT com grant e sem policy | 23 | 23 |
| UPDATE com grant e sem policy | 26 | 26 |
| DELETE com grant e sem policy | 18 | 18 |
| SELECT com grant e sem policy | 7 | 7 (1 tabela + 6 views) |
| Tabelas (relkind r) com grant e RLS desligada | 0 | 0 |
| TRUNCATE / REFERENCES / TRIGGER com grant | revogados no 240600 | 0 / 0 / 0 |
| Grants remanescentes a `anon` ou `PUBLIC` nesses schemas | - | nenhum |

Objetos distintos na Tabela B: 32 (26 tabelas e 6 views). `app_private`,
`audit` e `analytics` nao concedem nada a `authenticated`; `audit` e
`analytics` tampouco dao USAGE de schema a `authenticated`.

## 1. Metodo

Tudo por `supabase db query --linked` a partir de
`packages/coelo_database` no worktree `e2-r04-realm-interno`, com a sessao
`postgres` do CLI (papel de aplicacao com BYPASSRLS, ve todos os grants em
`information_schema.role_table_grants`). Consultas agregadas com `string_agg`
para nao gerar saida por linha de grant. Sem `--dry-run`, sem `db dump`, sem
DDL/DML.

Uma policy conta para um comando quando `cmd in (comando, 'ALL')` e `roles`
contem `authenticated` ou e exatamente `{public}` (policy sem clausula `TO`).
A consulta base da Tabela B:

```sql
with g as (
  select table_schema as s, table_name as t, privilege_type as cmd
  from information_schema.role_table_grants
  where grantee = 'authenticated'
    and table_schema in ('public','app_private','audit','analytics')
    and privilege_type in ('SELECT','INSERT','UPDATE','DELETE')
),
p as (
  select schemaname as s, tablename as t, cmd, roles
  from pg_policies
  where schemaname in ('public','app_private','audit','analytics')
),
missing as (
  select g.s, g.t, g.cmd
  from g
  where not exists (
    select 1 from p
    where p.s = g.s and p.t = g.t
      and (p.cmd = g.cmd or p.cmd = 'ALL')
      and ('authenticated' = any(p.roles) or p.roles = '{public}'::name[])
  )
),
meta as (
  select n.nspname as s, c.relname as t, c.relkind,
         c.relrowsecurity as rls, c.relforcerowsecurity as force
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('public','app_private','audit','analytics')
    and c.relkind in ('r','p','v','m')
)
select m.s, m.t, m.relkind, m.rls, m.force,
       string_agg(missing.cmd, ',') as sem_policy
from missing join meta m on m.s = missing.s and m.t = missing.t
group by 1,2,3,4,5
order by m.relkind, m.s, m.t;
```

A Tabela C inverte a direcao: expande `cmd = 'ALL'` em quatro comandos
(`unnest`), filtra policies para `authenticated`/`{public}` e mantem as que nao
tem grant do comando em `role_table_grants`. O predicado (`with_check` para
INSERT, `qual` para os demais) igual a `false` separa deny explicito de policy
permissiva.

Complementos usados nas observacoes: `pg_class.reloptions` das views
(`security_invoker`), `pg_depend`/`pg_rewrite` para as tabelas base de cada
view, `pg_proc.prosecdef` + `prosrc` (regex `insert into|update|delete from
<tabela>`) para contar RPCs security definer que escrevem em cada tabela,
`pg_roles.rolbypassrls`, `pg_stat_user_tables.n_live_tup`, e um grep no Dart
dos apps por `.from('<tabela>')`.

## 2. Confirmacao do 240600: TRUNCATE / REFERENCES / TRIGGER

```text
cmd=REFERENCES | n=0
cmd=TRIGGER    | n=0
cmd=TRUNCATE   | n=0
```

Nenhuma tabela dos quatro schemas concede TRUNCATE, REFERENCES ou TRIGGER a
`authenticated`. O lote 13 esta efetivo em producao. Privilegios ainda
concedidos a `authenticated`, por comando: SELECT 140, INSERT 42, UPDATE 42,
DELETE 20 objetos.

## 3. Tabela B: grant a `authenticated` sem policy do comando

Todas as 26 tabelas tem RLS ligada (`rowsecurity = true`); portanto o
comportamento hoje e deny-by-default para os comandos listados em "sem
policy". Coluna "RPCs secdef que escrevem": funcoes `security definer` em
`public`/`app_private` (dono `postgres`, que tem BYPASSRLS) cujo corpo faz
INSERT/UPDATE/DELETE na tabela.

### 3.1 Por tabela

| Tabela (`public.`) | RLS | FORCE | Grants atuais | Sem policy | Policy existente (cmd) | RPCs secdef que escrevem | Linhas |
| --- | :-: | :-: | --- | --- | --- | ---: | ---: |
| attendance_notice_attachments | on | **on** | S,I,U | INSERT, UPDATE | attendance_notice_attachments_read (SELECT) | 1 | 0 |
| attendance_notices | on | **on** | S,I,U | INSERT, UPDATE | attendance_notices_read (SELECT) | 2 | 0 |
| attendance_record_revisions | on | **on** | S,I,U | INSERT, UPDATE | attendance_record_revisions_read (SELECT) | 2 | 0 |
| attendance_records | on | **on** | S,I,U | INSERT, UPDATE | attendance_records_read (SELECT) | 2 | 0 |
| audience_segments | on | off | S,I,U,D | INSERT, UPDATE, DELETE | audience_segments_platform_read (SELECT) | 0 | 0 |
| channel_policies | on | off | S,I,U,D | INSERT, UPDATE, DELETE | channel_policies_platform_read (SELECT) | 0 | 0 |
| child_unit_transfer_items | on | off | S,I,U | UPDATE | *_context_insert (INSERT), *_context_read (SELECT) | 1 | 0 |
| child_unit_transfer_requests | on | off | S,I,U | UPDATE | *_context_insert (INSERT), *_context_read (SELECT) | 1 | 0 |
| conversation_members | on | off | S,I,U,D | INSERT, UPDATE, DELETE | conversation_members_platform_read (SELECT) | 0 | 0 |
| conversations | on | off | S,I,U,D | INSERT, UPDATE, DELETE | conversations_context_read (SELECT) | 3 | 1 |
| guardian_invitation_children | on | off | S,I,U | UPDATE | *_context_insert (INSERT), *_context_read (SELECT) | 0 | 0 |
| institution_memberships | on | off | S,I,U,D | INSERT, UPDATE, DELETE | institution_memberships_self_read (SELECT) | 3 | 1 |
| institution_settings | on | off | S,I,U,D | INSERT, UPDATE, DELETE | institution_settings_platform_read (SELECT) | 0 | 0 |
| message_child_contexts | on | off | S,I,U | INSERT, UPDATE | message_child_contexts_context_read (SELECT) | 2 | 0 |
| messages | on | off | S,I,U,D | INSERT, UPDATE, DELETE | messages_context_read (SELECT) | 5 | 3 |
| people | on | off | S,I,U,D | INSERT, UPDATE, DELETE | people_self_read (SELECT) | 5 | 10 |
| person_addresses | on | off | S,I,U,D | INSERT, UPDATE, DELETE | person_addresses_self_read (SELECT) | 0 | 0 |
| person_auth_links | on | off | S,I,U,D | **SELECT**, INSERT, UPDATE, DELETE | (nenhuma) | 0 (18 RPCs leem) | 0 |
| person_contacts | on | off | S,I,U,D | INSERT, UPDATE, DELETE | person_contacts_self_read (SELECT) | 0 | 0 |
| person_education_details | on | off | S,I,U,D | INSERT, UPDATE, DELETE | person_education_self_read (SELECT) | 0 | 0 |
| person_professional_details | on | off | S,I,U,D | INSERT, UPDATE, DELETE | person_professional_self_read (SELECT) | 0 | 0 |
| person_profile_details | on | off | S,I,U,D | INSERT, UPDATE, DELETE | person_profile_self_read (SELECT) | 0 | 0 |
| platform_permissions | on | off | S,I,U,D | INSERT, UPDATE, DELETE | platform_permissions_platform_read (SELECT) | 0 (30 RPCs leem) | 135 |
| schema_columns | on | off | S,I,U,D | INSERT, UPDATE, DELETE | schema_columns_authenticated_read (SELECT) | 0 | 24 |
| schema_tables | on | off | S,I,U,D | INSERT, UPDATE, DELETE | schema_tables_authenticated_read (SELECT) | 0 | 6 |
| usage_limits | on | off | S,I,U,D | INSERT, UPDATE, DELETE | usage_limits_platform_read (SELECT) | 0 | 0 |

Views com grant SELECT a `authenticated` (views nao tem policy nem
`rowsecurity`; o RLS que vale e o das tabelas base, porque todas sao
`security_invoker = true`, dono `postgres`):

| View (`public.`) | Tabelas base | Observacao |
| --- | --- | --- |
| attendance_pending_notices | attendance_notices | base com policy SELECT |
| attendance_summary | attendance_records, attendance_sessions | bases com policy SELECT |
| daily_routine_effective_applications | routine_applications, routine_application_revisions | bases com policy SELECT |
| institution_directory | groups, institution_addresses, institution_contacts, institution_subscriptions, institution_types, institutions, **plans**, units | `plans` nao tem SELECT para `authenticated`: leitura direta da view por sessao autenticada falha com `permission denied for table plans`; 3 RPCs secdef a usam (funcionam como `postgres`) |
| institution_directory_locations | institution_addresses, institutions | bases com policy SELECT |
| person_directory | people, person_auth_links, institution_memberships, guardian_links | filtra por `app_private.current_person_id()`; `has_active_login` e um `EXISTS` sobre `person_auth_links`, que tem RLS sem policy: em leitura direta por `authenticated` devolve sempre `false` |

### 3.2 Por comando

| Comando | Qtd | Objetos |
| --- | ---: | --- |
| INSERT | 23 | attendance_notice_attachments, attendance_notices, attendance_record_revisions, attendance_records, audience_segments, channel_policies, conversation_members, conversations, institution_memberships, institution_settings, message_child_contexts, messages, people, person_addresses, person_auth_links, person_contacts, person_education_details, person_professional_details, person_profile_details, platform_permissions, schema_columns, schema_tables, usage_limits |
| UPDATE | 26 | os 23 de INSERT + child_unit_transfer_items, child_unit_transfer_requests, guardian_invitation_children |
| DELETE | 18 | audience_segments, channel_policies, conversation_members, conversations, institution_memberships, institution_settings, messages, people, person_addresses, person_auth_links, person_contacts, person_education_details, person_professional_details, person_profile_details, platform_permissions, schema_columns, schema_tables, usage_limits |
| SELECT | 7 | person_auth_links (tabela, RLS on, 0 policies) + views attendance_pending_notices, attendance_summary, daily_routine_effective_applications, institution_directory, institution_directory_locations, person_directory |

Os 18 de DELETE e as 4 tabelas `attendance_*` somam as 22 tabelas do
`GRANT ALL` historico citadas no cabecalho do 240600; as demais 4
(child_unit_transfer_*, guardian_invitation_children, message_child_contexts)
vieram com grants parciais de migrations posteriores.

## 4. Tabela C: policy de escrita para `authenticated`/`{public}` sem grant do comando

Policy sem grant nunca e avaliada: o Postgres nega no privilegio antes de
chegar ao RLS. Duas familias:

### 4.1 Deny explicito (predicado `false`): consistente, sem acao

8 tabelas x 3 comandos (INSERT, UPDATE, DELETE), todas em `public`:
authorized_people, authorized_person_authorization_capabilities,
authorized_person_authorizations, child_safety_alerts, child_safety_evidence,
child_safety_restrictions (policies `*_deny_insert/_update/_delete to
authenticated`), institution_handle_history, institution_identity_media
(`*_deny_direct to public`, cmd ALL; tambem sem grant SELECT). E defesa em
profundidade intencional: grant ausente e policy falsa.

### 4.2 Policy permissiva sem grant (policy inutil hoje)

| Comando | Qtd | Tabelas (`public.`) e policy |
| --- | ---: | --- |
| INSERT | 7 | activity_assignment_permission_overrides (activity_assignment_overrides_authorized_insert), activity_group_assignments (*_authorized_insert), activity_group_links (*_authorized_insert), activity_group_participants (*_manage_insert), activity_unit_links (*_authorized_insert), guardian_context_permission_grants (*_manage_insert), institution_member_permission_overrides (*_insert) |
| UPDATE | 9 | os 7 acima com `*_update` + activity_definitions (activity_definitions_institution_update), context_notification_recipients (context_notification_recipients_own_update) |
| DELETE | 7 | activity_assignment_permission_overrides (*_authorized_delete), attendance_expected_participants (*_delete), attendance_sessions (*_delete), conversation_routing_team_members (*_context, ALL), conversation_routing_teams (*_context, ALL), institution_chat_settings (*_context, ALL), unit_chat_settings (*_context, ALL) |

Para referencia, SELECT com policy e sem grant: 28 tabelas, sendo 4 em
`analytics` (analytics_events, notice_events, usage_counters, usage_snapshots;
policies `*_dashboard_read`) e 1 em `audit` (support_session_actions), onde
`authenticated` nem tem USAGE no schema, e 23 em `public` (plans,
plan_entitlements, plan_institution_availability, platform_notices, notice_*,
support_*, unit_types, unit_subtypes, unit_subtype_links, unit_type_requests,
unit_handle_history, institution_role_grants, authorized_*, child_safety_*,
institution_handle_history, institution_identity_media). Sao leituras
servidas por RPC ou policies orfas; entram na mesma revisao, mas nao neste
recorte de escrita.

## 5. Observacoes de risco

1. **Neutralidade em comportamento.** Nas 26 tabelas da Tabela B o RLS esta
   ligado e nao ha policy para os comandos listados; um INSERT/UPDATE/DELETE
   direto por PostgREST com token `authenticated` ja e negado hoje (0 linhas
   visiveis para UPDATE/DELETE, `new row violates row-level security policy`
   para INSERT). Revogar o grant nao muda o resultado observavel de nenhuma
   requisicao que funcione hoje; muda apenas a camada em que a negacao ocorre
   (privilegio em vez de RLS) e remove a dependencia de nenhuma policy
   permissiva aparecer no futuro por engano.
2. **Nenhuma tela escreve direto nessas tabelas.** O grep nos apps Flutter
   encontra `.from('<tabela>')` apenas em `profile_about_pages`,
   `profile_about_sections` e `profile_about_structured_fields` (fora desta
   lista); as 153 chamadas restantes sao `.rpc(`. As RPCs sao `security
   definer` de dono `postgres` (BYPASSRLS = true), portanto nao dependem do
   grant de `authenticated` nem sao afetadas pelo FORCE das tabelas
   `attendance_*` (`confirm_attendance_record`, `revert_attendance_record`,
   `submit_attendance_notice`). Nenhum pgTAP em `supabase/tests` afirma grant
   positivo de INSERT/UPDATE/DELETE de `authenticated` nessas tabelas.
3. **Mesmo assim, confirmar tabela a tabela antes de um pacote.** A decisao do
   coordenador (11/09 00:30) e nao aplicar nesta rodada, por risco de derrubar
   tela na demonstracao. O ponto a confirmar por tabela e se alguma Edge
   Function, script ou teste E2E usa token `authenticated` (nao
   `service_role`) para escrita direta; o grep cobre so o Dart.
4. **Tabelas com RLS desligada e grant a `authenticated`: nenhuma.** As 6
   linhas com `rls = false` da consulta sao views (relkind `v`), sem RLS por
   natureza; nao ha tabela exposta sem RLS.
5. **`person_auth_links` e o unico objeto com SELECT concedido e RLS sem
   policy alguma.** Hoje e um deny total silencioso. Efeito colateral: a view
   `person_directory` (security_invoker) devolve `has_active_login = false`
   para qualquer leitura direta por sessao autenticada. Se o SELECT for
   revogado sem policy, essa leitura direta passa a falhar com `permission
   denied` em vez de devolver `false`; via RPC nada muda.
6. **`institution_directory` ja esta quebrada para leitura direta** por
   sessao autenticada (`plans` sem SELECT), o que mostra que o grant SELECT
   nessa view e letra morta e que a policy `plans_platform_read` (Tabela C,
   SELECT) nao tem grant correspondente. Nao afeta a demonstracao porque o
   cliente le por RPC.
7. **Policies permissivas sem grant (4.2)** ficam mortas ate alguem conceder o
   grant; se uma tela futura tentar escrita direta nessas tabelas, vai
   receber `permission denied` (privilegio) e nao uma negacao de RLS. Nao
   adicionar grants sem a tela precisar: a regra do projeto e escrita por RPC.
8. **Conteudo sensivel (LGPD) na lista:** people, person_* (CPF, contatos,
   enderecos, vinculo de login), institution_memberships, messages e
   conversations. Sao as tabelas onde o revoke tem mais valor como defesa em
   profundidade, e onde qualquer policy permissiva criada por engano no
   futuro seria mais grave.

## 6. Recomendacao (uma linha por grupo; tudo para o proximo pacote, apos a demonstracao)

| Grupo | Tabelas | Recomendacao |
| --- | --- | --- |
| Catalogo/plataforma somente leitura | audience_segments, channel_policies, institution_settings, platform_permissions, schema_columns, schema_tables, usage_limits | Revogar INSERT/UPDATE/DELETE de `authenticated`; manter SELECT com a policy `*_platform_read`/`*_authenticated_read` existente; escrita so por migration/superadmin RPC. |
| Pessoa e perfil (escrita por RPC) | people, person_addresses, person_contacts, person_education_details, person_professional_details, person_profile_details, institution_memberships | Revogar INSERT/UPDATE/DELETE; manter SELECT com `*_self_read`; a escrita ja passa por RPC secdef (people 5, institution_memberships 3). |
| Vinculo de login | person_auth_links | Revogar INSERT/UPDATE/DELETE; para SELECT, decidir em code review entre (a) criar policy `self_read` (`person_id = app_private.current_person_id()`), que tambem corrige `has_active_login` em `person_directory`, ou (b) revogar SELECT e tratar `person_directory` como RPC-only; recomendo (a). |
| Chat contextual (escrita por RPC) | conversations, messages, message_child_contexts, conversation_members | Revogar INSERT/UPDATE/DELETE; manter SELECT com `*_context_read`/`*_platform_read`; todas as escritas do chat v2 sao RPC secdef (messages 5, conversations 3). |
| Presenca com FORCE RLS (escrita por RPC) | attendance_records, attendance_record_revisions, attendance_notices, attendance_notice_attachments | Revogar INSERT/UPDATE; manter SELECT com `*_read` e o FORCE; `postgres` tem BYPASSRLS, entao as 3 RPCs continuam funcionando. |
| Fluxos com INSERT direto previsto e UPDATE sem policy | child_unit_transfer_requests, child_unit_transfer_items, guardian_invitation_children | Revogar apenas UPDATE; manter INSERT (grant + policy `*_context_insert` formam o caminho desenhado, ainda nao usado pelo cliente) e SELECT. |
| Views security_invoker | attendance_pending_notices, attendance_summary, daily_routine_effective_applications, institution_directory, institution_directory_locations, person_directory | Manter o SELECT (falso positivo da varredura: o RLS das bases decide); abrir item separado para `institution_directory` (conceder SELECT em `plans` com a policy ja existente ou remover o grant da view) e para `person_auth_links` acima. |
| Tabela C, deny explicito | authorized_*, child_safety_*, institution_handle_history, institution_identity_media | Nenhuma acao; e o padrao desejado (sem grant e policy `false`). |
| Tabela C, policy permissiva sem grant | activity_*, guardian_context_permission_grants, institution_member_permission_overrides, context_notification_recipients, attendance_sessions, attendance_expected_participants, conversation_routing_*, institution_chat_settings, unit_chat_settings | Code review decide por tabela: remover a policy morta (se a escrita migrou para RPC) ou conceder o grant (so se uma tela realmente escrever direto). Nao conceder por padrao. |

Formato sugerido para o pacote futuro: um `revoke <cmds> on table public.X
from authenticated` por tabela (presence-based, idempotente, sem grant novo),
com pgTAP afirmando `has_table_privilege('authenticated', ..., 'insert') =
false` por tabela e um teste positivo de que as RPCs secdef citadas continuam
escrevendo; em seguida rerodar a consulta da secao 1 e exigir 0 em
INSERT/UPDATE/DELETE e 1 em SELECT (ou 0, conforme a decisao sobre
`person_auth_links`).
