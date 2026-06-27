---
title: "Superadmin Foundation v1 Migration Plan"
source: "specs/011-superadmin-database-rls.md"
status: "approved-for-initial-migration"
generated_at: "2026-06-23"
---

# Superadmin Foundation v1 Migration Plan

## Objetivo

Criar a primeira base fisica do banco Coelo no Supabase/Postgres para identidade, instituicoes, permissoes do Superadmin, importacao, suporte, chat institucional, auditoria e metricas futuras.

## Ordem Da Migration

1. Schemas internos: `app_private` e `audit`.
2. Enums e tipos compartilhados.
3. Identidade: `people`, detalhes pessoais, profissionais, escolaridade, endereco, contatos, auth links e convites.
4. Catalogo de schema: `schema_tables` e `schema_columns`.
5. Instituicoes: `institutions`, `units`, `groups`, settings e branding.
6. Planos: `plans`, entitlements, subscriptions e usage limits.
7. Permissoes Superadmin: roles, permissions, role permissions, memberships e overrides.
8. Permissoes Admin: memberships e grants institucionais.
9. Avisos/popups e audiencia.
10. Importacao: jobs, files, mappings, rows, errors e results.
11. Suporte Coelo: sessions, messages e actions.
12. Chat institucional: conversations, members, messages, receipts, edits e policies.
13. Auditoria e analytics: audit logs, events, counters e snapshots.
14. Helpers de autorizacao em `app_private`.
15. RLS habilitada em todas as tabelas `public`.
16. Policies basicas: self-read em pessoa, leitura governada por permissoes internas e deny-by-default para escrita direta.
17. Seeds minimos de perfis/permissoes do Superadmin e catalogo inicial.

## FKs Principais

- `person_auth_links.person_id -> people.id`.
- `person_auth_links.auth_user_id -> auth.users.id`.
- `institutions.primary_contact_person_id -> people.id`.
- `units.institution_id -> institutions.id`.
- `groups.institution_id -> institutions.id`.
- `groups.unit_id -> units.id`.
- `platform_memberships.person_id -> people.id`.
- `platform_memberships.role_id -> platform_roles.id`.
- `platform_role_permissions.role_id -> platform_roles.id`.
- `platform_role_permissions.permission_id -> platform_permissions.id`.
- `institution_memberships.person_id -> people.id`.
- `institution_memberships.institution_id -> institutions.id`.
- `support_sessions.institution_id -> institutions.id`.
- `support_sessions.unit_id -> units.id`.
- `conversations.institution_id -> institutions.id`.

## RLS Inicial

- Todas as tabelas em `public` nascem com RLS habilitada.
- Tabelas pessoais permitem leitura da propria pessoa via `app_private.current_person_id()`.
- Tabelas operacionais exigem permissao interna via `app_private.has_platform_permission(...)`.
- Escritas sensiveis devem passar por RPC/Edge Function futura; a migration inicial nao abre escrita direta para clientes.

## Validacoes Basicas

- Confirmar que a migration foi registrada no Supabase.
- Confirmar que todas as tabelas `public` criadas estao com RLS habilitada.
- Confirmar que roles/permissoes base foram semeadas.
- Confirmar que helper `app_private.has_mfa_aal2()` existe.
- Confirmar que `schema_columns` existe desde o MVP.

## Fora Desta Migration

- RPCs finais de ativacao de instituicao.
- Policies completas de Admin/App.
- Storage/R2 de midia.
- Triggers de contadores e snapshots.
- Testes pgTAP completos.
