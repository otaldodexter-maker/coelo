---
title: "Prova em produção — realm-interno, Rodada 5 (somente leitura)"
grupo: "realm-interno"
source: "supabase db query --linked (postgres do CLI), 11/09/2026 ~13:45 America/Sao_Paulo"
generated_at: "2026-09-11"
environment: "Supabase coelo / evvbomzejfijozbtgvpt (produção, sem clientes reais)"
status: "medição após os lotes 28, 30, 32, 33, 35 e 36 aplicados pelo coordenador"
---

# Prova em produção (somente leitura)

Consulta agregada única, sem DDL/DML, sem `--dry-run`, sem valores de segredo.

| Medida | Valor | O que confirma |
| --- | ---: | --- |
| funções `superadmin_institution_contacts_*`, `superadmin_chat_attachment_*`, `superadmin_form_media_*`, `form_media_*`, `superadmin_unit_care_policy_*`, `child_care_*`, `*_care_notify_v1`, `person_identity_hmac_v1`, `enforce_activity_active_group_v1` | 34 | pacotes 210000, 210200, 210300, 210400, 210500 presentes |
| `vault.secrets` com nome `coelo_person_identity_hmac_v1` | 1 | chave HMAC do CPF criada pela migration (valor não lido) |
| policy `person_auth_links_self_read` | 1 | pacote 210100 |
| grants SELECT/INSERT/UPDATE/DELETE de `authenticated` sem policy em tabelas com RLS (public/app_private/audit/analytics) | 0 | varredura da R04 fechada (era INSERT 23 / UPDATE 26 / DELETE 18 / SELECT 1) |
| gatilhos `activity_definition_requires_group` e `activity_group_links_retain_one` | 2 | P36 no servidor |
| tabelas `unit_care_policies`, `superadmin_internal_chat_attachment_tickets`, `form_media_upload_tickets`, `form_media_r2_cleanup`, `unit_care_policy_receipts` | 5 | pacotes 210200, 210300, 210500 |
| grants de `anon` nos schemas da aplicação | 0 | 240500 continua efetivo |

Não medido aqui (gate do cliente/Edge Function): CRUD pela rota real do
Superadmin, `chat-media`/`form-media` implantadas, crons 210700/210900.
