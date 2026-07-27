---
title: "Contextual Migration History Reconciliation"
source: "Supabase project evvbomzejfijozbtgvpt; packages/coelo_database/migrations; Supabase CLI 2.109.1"
status: "phase-2-go"
generated_at: "2026-07-27"
---

# Escopo

Reconciliar somente o ledger de migrations. Nenhuma estrutura ou dado de
produto pode mudar.

Este documento registra o estado remoto anterior a qualquer reparacao. A
coleta foi somente leitura: listagem de projeto e migrations, consultas
`SELECT` ao ledger e ao catalogo PostgreSQL, e advisors de seguranca e
performance.

# Projeto Confirmado

| Campo | Valor |
| --- | --- |
| Nome | coelo |
| Ref | evvbomzejfijozbtgvpt |
| Status | ACTIVE_HEALTHY |
| Regiao | sa-east-1 |
| PostgreSQL | 17.6.1.127 |

Todos os campos esperados coincidem, inclusive a versao patch do PostgreSQL.

# Mapeamento Semantico

| Local version | Remote version before repair | Name |
| --- | --- | --- |
| 20260720103023 | 20260720133448 | institution_contact_directory_refinement |
| 20260720180000 | 20260720183531 | people_context_foundation |
| 20260720190000 | 20260720183750 | people_context_advisor_hardening |
| 20260724120307 | 20260724121904 | contextual_activities_foundation |
| 20260724122545 | 20260724122630 | contextual_activities_fk_index_hardening |
| 20260724152628 | 20260724153426 | contextual_authorization_core |
| 20260724152707 | 20260724155243 | family_authorizations_and_transfers |
| 20260724152713 | 20260724155913 | activity_governance_and_participation |
| 20260724152722 | 20260724160402 | contextual_chat_foundation |
| 20260724152731 | 20260724161043 | attendance_assiduity_foundation |
| 20260724161334 | 20260724161414 | contextual_domains_compatibility_hardening |
| 20260724161706 | 20260724161917 | contextual_domains_advisor_hardening |
| 20260724162210 | 20260724162436 | contextual_chat_lifecycle_hardening |
| 20260724162604 | 20260724162735 | contextual_chat_trigger_hardening |
| 20260724162900 | 20260724163017 | contextual_chat_audit_schema_hardening |

As tres versions abaixo ja estao alinhadas:

| Version | Name |
| --- | --- |
| 20260623191021 | superadmin_foundation_v1 |
| 20260623203230 | schema_boundaries_catalog_v1 |
| 20260717151609 | institution_directory_foundation |

# Ledger Remoto Antes

Foram retornadas 18 entradas. Apenas contagem e hash dos
statements sao registrados; o conteudo SQL nao foi copiado.

| Version | Name | Statement count | Statements MD5 |
| --- | --- | ---: | --- |
| 20260623191021 | superadmin_foundation_v1 | 1 | 46d5508ed62319d2aa1b2cb8fe9f9ed2 |
| 20260623203230 | schema_boundaries_catalog_v1 | 1 | 5daa13622e64488e5cec9e4f4ce4d01e |
| 20260717151609 | institution_directory_foundation | 1 | 82f7c78a33090f0d75436d28b8c6d2ff |
| 20260720133448 | institution_contact_directory_refinement | 1 | b377e2bbb598818156edfe9220d0a0f7 |
| 20260720183531 | people_context_foundation | 1 | 36d78c51c0db3023561a9f3109edfc5e |
| 20260720183750 | people_context_advisor_hardening | 1 | 5ed678cc1547c0283544b28f77e2e119 |
| 20260724121904 | contextual_activities_foundation | 1 | 91b6c924ee6c1c6a7420869e47c7cc4e |
| 20260724122630 | contextual_activities_fk_index_hardening | 1 | 33355842fe3dcf73ddb85253f3d27e2e |
| 20260724153426 | contextual_authorization_core | 1 | 13025180836387df86bb0160f6954d97 |
| 20260724155243 | family_authorizations_and_transfers | 1 | 80c64c941d1bb50238c91b167ef2c72f |
| 20260724155913 | activity_governance_and_participation | 1 | 62d0e7b202f49a888e66b4e8dbda246a |
| 20260724160402 | contextual_chat_foundation | 1 | e7902022855fa94cbbdf704dd0cac6bf |
| 20260724161043 | attendance_assiduity_foundation | 1 | 67d9541883916179c6793cf87184cead |
| 20260724161414 | contextual_domains_compatibility_hardening | 1 | ea482d27d321840b9fd213a5d362df35 |
| 20260724161917 | contextual_domains_advisor_hardening | 1 | 82d980f659c7fdaa8f177ab2c1b41766 |
| 20260724162436 | contextual_chat_lifecycle_hardening | 1 | 218a53daef74330dafde7ee805441c2e |
| 20260724162735 | contextual_chat_trigger_hardening | 1 | 5d6fb65c4a2f01fa819fb6eb038f8f3e |
| 20260724163017 | contextual_chat_audit_schema_hardening | 1 | 2cb749ef0f6dfcaf4ff91883dd7c6a50 |

# Fingerprint Do Schema

O fingerprint cobre columns, constraints, policies e functions dos schemas
`public`, `app_private`, `audit` e `analytics`.

| Momento | Catalog item count | Schema fingerprint |
| --- | ---: | --- |
| before | 1840 | 15dbd25272e225eafb2b9fd84507043a |
| after | 1840 | 15dbd25272e225eafb2b9fd84507043a |

# Advisors Antes

Os registros abaixo preservam somente codigo, severidade, objeto afetado,
URL de remediacao e totais por categoria. Nenhuma correcao foi tentada.

## Seguranca

Total: 2. Severidades: INFO=1, WARN=1.

### `rls_enabled_no_policy`

- Severidade: `INFO`
- Total: 1
- Remediacao: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- Objetos afetados:

  - `public.person_auth_links`

### `auth_leaked_password_protection`

- Severidade: `WARN`
- Total: 1
- Remediacao: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- Objetos afetados:

  - `Auth`

## Performance

Total: 198. Severidades: INFO=198.

### `unindexed_foreign_keys`

- Severidade: `INFO`
- Total: 64
- Remediacao: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- Objetos afetados:

  - `analytics.notice_events.notice_events_institution_id_fkey`
  - `analytics.notice_events.notice_events_notice_id_fkey`
  - `analytics.notice_events.notice_events_person_id_fkey`
  - `analytics.usage_snapshots.usage_snapshots_institution_id_fkey`
  - `audit.audit_logs.audit_logs_support_session_id_fkey`
  - `audit.support_session_actions.support_session_actions_support_session_id_fkey`
  - `public.activity_definitions.activity_definitions_promoted_by_person_id_fkey`
  - `public.audience_segments.audience_segments_created_by_fkey`
  - `public.channel_policies.channel_policies_institution_id_fkey`
  - `public.conversation_members.conversation_members_person_id_fkey`
  - `public.conversations.conversations_activity_id_fkey`
  - `public.conversations.conversations_created_by_fkey`
  - `public.conversations.conversations_group_id_fkey`
  - `public.conversations.conversations_routing_team_id_fkey`
  - `public.conversations.conversations_unit_id_fkey`
  - `public.groups.groups_unit_id_fkey`
  - `public.guardian_links.guardian_links_relationship_type_id_fkey`
  - `public.import_errors.import_errors_import_job_id_fkey`
  - `public.import_files.import_files_import_job_id_fkey`
  - `public.import_jobs.import_jobs_created_by_fkey`
  - `public.import_jobs.import_jobs_institution_id_fkey`
  - `public.import_mappings.import_mappings_import_job_id_fkey`
  - `public.import_rows.import_rows_import_job_id_fkey`
  - `public.institution_branding.institution_branding_updated_by_fkey`
  - `public.institution_memberships.institution_memberships_institution_id_fkey`
  - `public.institution_memberships.institution_memberships_invited_by_fkey`
  - `public.institution_memberships.institution_memberships_scope_group_id_fkey`
  - `public.institution_memberships.institution_memberships_scope_unit_id_fkey`
  - `public.institution_role_grants.institution_role_grants_granted_by_fkey`
  - `public.institution_role_grants.institution_role_grants_membership_id_fkey`
  - `public.institution_subscriptions.institution_subscriptions_changed_by_fkey`
  - `public.institution_subscriptions.institution_subscriptions_plan_id_fkey`
  - `public.institutions.institutions_created_by_fkey`
  - `public.institutions.institutions_primary_contact_person_id_fkey`
  - `public.message_edits.message_edits_edited_by_fkey`
  - `public.message_edits.message_edits_message_id_fkey`
  - `public.message_receipts.message_receipts_person_id_fkey`
  - `public.messages.messages_author_membership_id_fkey`
  - `public.messages.messages_author_person_id_fkey`
  - `public.notice_media.notice_media_notice_id_fkey`
  - `public.notice_receipts.notice_receipts_institution_id_fkey`
  - `public.notice_receipts.notice_receipts_person_id_fkey`
  - `public.notice_rules.notice_rules_segment_id_fkey`
  - `public.person_auth_links.person_auth_links_person_id_fkey`
  - `public.person_contacts.person_contacts_person_id_fkey`
  - `public.person_education_details.person_education_details_person_id_fkey`
  - `public.platform_member_permission_overrides.platform_member_permission_overrides_granted_by_fkey`
  - `public.platform_member_permission_overrides.platform_member_permission_overrides_permission_id_fkey`
  - `public.platform_memberships.platform_memberships_invited_by_fkey`
  - `public.platform_memberships.platform_memberships_role_id_fkey`
  - `public.platform_memberships.platform_memberships_scope_institution_id_fkey`
  - `public.platform_notices.platform_notices_approved_by_fkey`
  - `public.platform_notices.platform_notices_created_by_fkey`
  - `public.platform_role_permissions.platform_role_permissions_granted_by_fkey`
  - `public.platform_role_permissions.platform_role_permissions_permission_id_fkey`
  - `public.platform_roles.platform_roles_created_by_fkey`
  - `public.support_messages.support_messages_author_person_id_fkey`
  - `public.support_messages.support_messages_support_session_id_fkey`
  - `public.support_sessions.support_sessions_assigned_to_membership_id_fkey`
  - `public.support_sessions.support_sessions_opened_by_membership_id_fkey`
  - `public.support_sessions.support_sessions_opened_by_person_id_fkey`
  - `public.support_sessions.support_sessions_resolved_by_membership_id_fkey`
  - `public.support_sessions.support_sessions_unit_id_fkey`
  - `public.unit_branding.unit_branding_updated_by_fkey`

### `unused_index`

- Severidade: `INFO`
- Total: 134
- Remediacao: https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index
- Objetos afetados:

  - `analytics.analytics_events.analytics_events_institution_event_date_idx`
  - `audit.audit_logs.audit_logs_actor_date_idx`
  - `public.activity_assignment_permission_overrides.activity_assignment_overrides_capability_idx`
  - `public.activity_assignment_permission_overrides.activity_assignment_overrides_changed_by_idx`
  - `public.activity_capability_policies.activity_capability_policies_institution_idx`
  - `public.activity_capability_policies.ctx_fk_8b9ae346459e1767`
  - `public.activity_capability_policies.ctx_fk_a4e1d70b4be51a5a`
  - `public.activity_definitions.activity_definitions_created_by_idx`
  - `public.activity_group_assignments.activity_group_assignments_assigned_by_idx`
  - `public.activity_group_assignments.activity_group_assignments_membership_idx`
  - `public.activity_group_assignments.activity_group_assignments_membership_institution_person_idx`
  - `public.activity_group_capability_settings.ctx_fk_3b04264fe44b0bd3`
  - `public.activity_group_capability_settings.ctx_fk_cbe3a3909fa44d66`
  - `public.activity_group_links.activity_group_links_group_institution_unit_idx`
  - `public.activity_group_links.activity_group_links_linked_by_idx`
  - `public.activity_group_links.activity_group_links_profile_idx`
  - `public.activity_group_links.activity_group_links_profile_institution_idx`
  - `public.activity_group_links.activity_group_links_unit_status_idx`
  - `public.activity_group_participants.activity_group_participants_child_idx`
  - `public.activity_group_participants.ctx_fk_02390a30f5c420fc`
  - `public.activity_permission_profile_capabilities.activity_profile_capabilities_capability_idx`
  - `public.activity_permission_profile_capabilities.activity_profile_capabilities_changed_by_idx`
  - `public.activity_permission_profiles.activity_permission_profiles_created_by_idx`
  - `public.activity_permission_profiles.activity_permission_profiles_institution_status_idx`
  - `public.activity_permission_profiles.activity_permission_profiles_unit_idx`
  - `public.activity_permission_profiles.activity_permission_profiles_unit_institution_idx`
  - `public.activity_suggestions.activity_suggestions_created_by_idx`
  - `public.activity_suggestions.activity_suggestions_institution_status_idx`
  - `public.activity_suggestions.activity_suggestions_unit_idx`
  - `public.activity_suggestions.activity_suggestions_unit_institution_idx`
  - `public.activity_unit_links.activity_unit_links_linked_by_idx`
  - `public.activity_unit_links.activity_unit_links_unit_status_idx`
  - `public.attendance_expected_participants.ctx_fk_15497ae3a3a4bcb9`
  - `public.attendance_expected_participants.ctx_fk_8d213147ace91926`
  - `public.attendance_expected_participants.ctx_fk_9f913bbad2585523`
  - `public.attendance_notices.attendance_notices_child_idx`
  - `public.attendance_notices.attendance_notices_pending_context_idx`
  - `public.attendance_notices.ctx_fk_159775a1abadaa98`
  - `public.attendance_notices.ctx_fk_177e583004babf39`
  - `public.attendance_notices.ctx_fk_9a6a58614c734ea3`
  - `public.attendance_notices.ctx_fk_a7734bb1feb9c5b4`
  - `public.attendance_notices.ctx_fk_b30de9996ee0b28f`
  - `public.attendance_notices.ctx_fk_b63f2398956b5e31`
  - `public.attendance_notices.ctx_fk_d92dfd05753ae711`
  - `public.attendance_notices.ctx_fk_e8ac053aaf6d1e32`
  - `public.attendance_reason_catalog.ctx_fk_cdf52bff1a64185b`
  - `public.attendance_reason_catalog.ctx_fk_f9e25704831dbe55`
  - `public.attendance_record_revisions.attendance_record_revisions_record_idx`
  - `public.attendance_record_revisions.ctx_fk_2d15e9d3cb4966bd`
  - `public.attendance_records.attendance_records_child_idx`
  - `public.attendance_records.ctx_fk_061d92211927770a`
  - `public.attendance_records.ctx_fk_6434489ded4eb791`
  - `public.attendance_records.ctx_fk_99696042ec94af77`
  - `public.attendance_sessions.attendance_sessions_unit_date_idx`
  - `public.attendance_sessions.ctx_fk_18d00a42ad5ebc1f`
  - `public.attendance_sessions.ctx_fk_8219263812ca86e3`
  - `public.attendance_sessions.ctx_fk_d5e4eb2385e1b5f4`
  - `public.attendance_sessions.ctx_fk_d6413c05b8bce308`
  - `public.authorized_people.authorized_people_institution_status_idx`
  - `public.authorized_person_authorizations.authorized_person_authorizations_child_unit_idx`
  - `public.authorized_person_authorizations.ctx_fk_4a63018e83784a0d`
  - `public.authorized_person_authorizations.ctx_fk_753ad2b493779f9d`
  - `public.authorized_person_authorizations.ctx_fk_763c72ab038b78f7`
  - `public.authorized_person_authorizations.ctx_fk_77fe5c437ae91cb3`
  - `public.authorized_person_authorizations.ctx_fk_7b1666aaa02328f6`
  - `public.authorized_person_authorizations.ctx_fk_c60274daa462319c`
  - `public.child_contexts.child_contexts_institution_status_idx`
  - `public.child_group_links.child_group_links_group_status_idx`
  - `public.child_unit_access_request_children.child_unit_access_request_children_child_idx`
  - `public.child_unit_access_request_children.child_unit_access_request_children_guardian_idx`
  - `public.child_unit_access_requests.child_unit_access_requests_decided_by_idx`
  - `public.child_unit_access_requests.child_unit_access_requests_requester_status_idx`
  - `public.child_unit_access_requests.child_unit_access_requests_unit_status_idx`
  - `public.child_unit_links.child_unit_links_accepted_by_idx`
  - `public.child_unit_links.child_unit_links_unit_status_idx`
  - `public.child_unit_transfer_items.ctx_fk_197267b33df79f90`
  - `public.child_unit_transfer_items.ctx_fk_2738a8022bb6a535`
  - `public.child_unit_transfer_items.ctx_fk_ba79580626fcb840`
  - `public.child_unit_transfer_requests.child_unit_transfer_requests_destination_idx`
  - `public.child_unit_transfer_requests.ctx_fk_0ebb721ecf3e9e9c`
  - `public.child_unit_transfer_requests.ctx_fk_6fc40395826ee53f`
  - `public.child_unit_transfer_requests.ctx_fk_efc5926bf1ee7360`
  - `public.child_unit_transfer_requests.ctx_fk_fa9911a3b6105a45`
  - `public.context_notification_events.context_notification_events_context_idx`
  - `public.context_notification_events.context_notification_events_delivery_idx`
  - `public.context_notification_events.ctx_fk_034fadf052e95aa5`
  - `public.context_notification_events.ctx_fk_70c76714afe82e97`
  - `public.context_notification_events.ctx_fk_8e8f943c9aca20db`
  - `public.context_notification_events.ctx_fk_a09b465140be939e`
  - `public.context_notification_events.ctx_fk_ac31c3b3039041ee`
  - `public.context_notification_recipients.context_notification_recipients_person_idx`
  - `public.conversation_participants.ctx_fk_f2cae5d7b62743af`
  - `public.conversation_routing_team_members.ctx_fk_861886c42d4d396d`
  - `public.conversation_routing_team_members.ctx_fk_aa30cdde41ed8359`
  - `public.conversation_routing_teams.ctx_fk_832a6c558181a185`
  - `public.conversation_routing_teams.ctx_fk_a261516b2f509832`
  - `public.groups.groups_institution_unit_idx`
  - `public.guardian_context_permission_grants.ctx_fk_7605eebbd847b646`
  - `public.guardian_context_permission_grants.guardian_context_permission_grants_capability_idx`
  - `public.guardian_context_permissions.guardian_context_permissions_context_status_idx`
  - `public.guardian_invitation_children.ctx_fk_bce4f5deb806afe5`
  - `public.guardian_invitation_children.ctx_fk_d1d72c8029c1f1fa`
  - `public.institution_addresses.institution_addresses_state_city_idx`
  - `public.institution_chat_settings.ctx_fk_9c5d8d04a501f101`
  - `public.institution_member_permission_overrides.ctx_fk_61fb883c369f9836`
  - `public.institution_member_permission_overrides.ctx_fk_9d1dd91c3b32914c`
  - `public.institution_member_permission_overrides.institution_member_permission_overrides_membership_idx`
  - `public.institution_member_permission_overrides.institution_member_permission_overrides_scope_idx`
  - `public.institution_role_assignments.institution_role_assignments_granted_by_idx`
  - `public.institution_role_assignments.institution_role_assignments_membership_status_idx`
  - `public.institution_role_assignments.institution_role_assignments_role_status_idx`
  - `public.institution_role_assignments.institution_role_assignments_scope_group_idx`
  - `public.institution_role_assignments.institution_role_assignments_unit_group_idx`
  - `public.institution_role_permissions.institution_role_permissions_granted_by_idx`
  - `public.institution_roles.institution_roles_institution_status_idx`
  - `public.institutions.institutions_institution_type_id_idx`
  - `public.institutions.institutions_status_created_idx`
  - `public.invitations.invitations_accepted_by_idx`
  - `public.invitations.invitations_group_state_idx`
  - `public.invitations.invitations_institution_idx`
  - `public.invitations.invitations_invited_by_idx`
  - `public.invitations.invitations_target_contact_state_idx`
  - `public.invitations.invitations_target_person_state_idx`
  - `public.invitations.invitations_unit_state_idx`
  - `public.message_child_contexts.ctx_fk_57fabbe8a383d5ef`
  - `public.notice_rules.notice_rules_notice_position_idx`
  - `public.person_contacts.person_contacts_hash_idx`
  - `public.professional_child_assignments.ctx_fk_5778b80feca2758c`
  - `public.professional_child_assignments.professional_child_assignments_child_idx`
  - `public.support_sessions.support_sessions_institution_status_idx`
  - `public.unit_addresses.unit_addresses_state_city_idx`
  - `public.unit_chat_settings.ctx_fk_11e561bb5d2f8c75`
  - `public.unit_chat_settings.ctx_fk_a0d0653320b66e04`
  - `public.units.units_institution_idx`

# Reparacao Executada

Executada em `2026-07-27T09:29:37-03:00`, exclusivamente no projeto
`evvbomzejfijozbtgvpt`, depois de reconfirmar:

- projeto `coelo` em `ACTIVE_HEALTHY`;
- PostgreSQL `17.6.1.127` em `sa-east-1`;
- as mesmas 18 entradas do ledger anterior;
- os 15 pares semanticos deste relatorio;
- 1840 itens de catalogo e fingerprint
  `15dbd25272e225eafb2b9fd84507043a`;
- mirror local com as 18 migrations canonicas;
- Supabase CLI `2.109.1`.

O workspace foi vinculado somente ao ref confirmado:

```powershell
npx.cmd supabase@2.109.1 link --project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database --agent no --output-format text
```

As 15 versions remotas antigas foram removidas somente do ledger:

```powershell
npx.cmd supabase@2.109.1 migration repair 20260720133448 20260720183531 20260720183750 20260724121904 20260724122630 20260724153426 20260724155243 20260724155913 20260724160402 20260724161043 20260724161414 20260724161917 20260724162436 20260724162735 20260724163017 --status reverted --linked --workdir packages/coelo_database --agent no --output-format text
```

As 15 versions canonicas foram registradas como aplicadas:

```powershell
npx.cmd supabase@2.109.1 migration repair 20260720103023 20260720180000 20260720190000 20260724120307 20260724122545 20260724152628 20260724152707 20260724152713 20260724152722 20260724152731 20260724161334 20260724161706 20260724162210 20260724162604 20260724162900 --status applied --linked --workdir packages/coelo_database --agent no --output-format text
```

Os dois comandos terminaram com `Finished supabase migration repair.`. Antes
de atualizar as entradas, o CLI oficial executou DDL idempotente restrito ao
seu ledger interno para garantir:

- `CREATE SCHEMA IF NOT EXISTS supabase_migrations`;
- `CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations`;
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS statements`;
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS name`.

Esses comandos internos nao constituem DDL de produto. Nenhum DDL foi
executado nos schemas de produto, e nenhuma DML foi executada em tabelas de
produto. Tambem nao foram executados `apply_migration`, `db reset` ou
`db push` real.

# Ledger Remoto Depois

O ledger remoto passou a ter exatamente as mesmas 18 versions e nomes dos
arquivos canonicos locais:

| Version | Name |
| --- | --- |
| 20260623191021 | superadmin_foundation_v1 |
| 20260623203230 | schema_boundaries_catalog_v1 |
| 20260717151609 | institution_directory_foundation |
| 20260720103023 | institution_contact_directory_refinement |
| 20260720180000 | people_context_foundation |
| 20260720190000 | people_context_advisor_hardening |
| 20260724120307 | contextual_activities_foundation |
| 20260724122545 | contextual_activities_fk_index_hardening |
| 20260724152628 | contextual_authorization_core |
| 20260724152707 | family_authorizations_and_transfers |
| 20260724152713 | activity_governance_and_participation |
| 20260724152722 | contextual_chat_foundation |
| 20260724152731 | attendance_assiduity_foundation |
| 20260724161334 | contextual_domains_compatibility_hardening |
| 20260724161706 | contextual_domains_advisor_hardening |
| 20260724162210 | contextual_chat_lifecycle_hardening |
| 20260724162604 | contextual_chat_trigger_hardening |
| 20260724162900 | contextual_chat_audit_schema_hardening |

`supabase migration list --linked` retornou 18 linhas com `LOCAL` e `REMOTE`
iguais. A verificacao:

```powershell
npx.cmd supabase@2.109.1 db push --dry-run --linked --workdir packages/coelo_database --agent no --output-format text
```

retornou `Remote database is up to date.` e declarou explicitamente
`DRY RUN: migrations will not be pushed to the database.`.

# Testes E Advisors Depois

Em `2026-07-27`, os 11 scripts existentes foram lidos integralmente e
executados no projeto `evvbomzejfijozbtgvpt`, na ordem definida pelo plano,
usando Supabase `execute_sql`. Os nove scripts que criam fixtures executaram
`BEGIN` e `ROLLBACK`; uma verificacao posterior encontrou zero usuarios de
autenticacao e zero instituicoes correspondentes as fixtures.

| Ordem | Validacao | Resultado |
| ---: | --- | --- |
| 1 | `2026-06-23-superadmin-foundation-validation.sql` | PASS |
| 2 | `2026-06-23-schema-boundaries-catalog-validation.sql` | PASS, com delta de catalogo registrado abaixo |
| 3 | `2026-07-17-institution-directory-validation.sql` | PASS; rollback confirmado |
| 4 | `2026-07-20-institution-contact-directory-validation.sql` | PASS; rollback confirmado |
| 5 | `2026-07-20-people-context-foundation-validation.sql` | PASS; rollback confirmado |
| 6 | `2026-07-24-contextual-activities-foundation-validation.sql` | PASS; rollback confirmado |
| 7 | `2026-07-24-contextual-authorization-core-validation.sql` | PASS; rollback confirmado |
| 8 | `2026-07-24-family-authorizations-transfers-validation.sql` | PASS; rollback confirmado |
| 9 | `2026-07-24-activity-governance-participation-validation.sql` | PASS; rollback confirmado |
| 10 | `2026-07-24-contextual-chat-validation.sql` | PASS; rollback confirmado |
| 11 | `2026-07-24-attendance-assiduity-validation.sql` | PASS; rollback confirmado |

O segundo script e somente leitura e concluiu sem erro, mas sua consulta de
delta retornou 26 colunas presentes no schema e ainda ausentes de
`public.schema_columns`. Esse resultado e preservado como lacuna logica do
catalogo; esta tarefa nao executou DML para corrigi-lo e nao afirma que essa
lacuna foi resolvida.

## Contagens Estruturais

| Verificacao | Resultado |
| --- | ---: |
| Tabelas `public` | 101 |
| Tabelas `audit` | 2 |
| Tabelas `analytics` | 4 |
| Tabelas com RLS nos tres schemas | 107 |
| Tabelas contextuais selecionadas presentes em `schema_tables` | 7 |

## Advisors Reexecutados

Os totais e codigos permaneceram identicos ao baseline da Task 3:

- seguranca: 2 achados, sendo
  `rls_enabled_no_policy` = 1 e
  `auth_leaked_password_protection` = 1;
- performance: 198 achados, sendo
  `unindexed_foreign_keys` = 64 e `unused_index` = 134.

Nenhum advisor foi corrigido nesta tarefa.

## Gates Finais

- projeto `coelo`, ref `evvbomzejfijozbtgvpt`, permaneceu
  `ACTIVE_HEALTHY`;
- o ledger permaneceu com as mesmas 18 versions e nomes canonicos;
- o fingerprint permaneceu em 1840 itens e
  `15dbd25272e225eafb2b9fd84507043a`;
- os 11 scripts concluiram sem erro;
- as fixtures transacionais nao permaneceram no banco;
- os totais e codigos dos advisors permaneceram inalterados;
- nenhum DDL de produto, DML persistente, migration, migration repair,
  `apply_migration`, `db reset` ou `db push` real foi executado.

# Resultado

**GO para iniciar a Fase 2.**

O historico remoto continua reconciliado com as 18 versions e nomes canonicos
locais, o schema permanece estruturalmente identico e os 11 scripts de
validacao concluiram sem erro. A Fase 2 deve tratar as lacunas logicas
documentadas, inclusive as 26 colunas ainda ausentes de `schema_columns`, sem
interpretar este GO como conclusao dessas correcoes de produto.
