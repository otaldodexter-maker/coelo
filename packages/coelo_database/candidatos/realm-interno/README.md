---
title: "Candidatos realm-interno (Rodada 4, E2-R04-20260911)"
source: "comunicacao/realm-interno.json; ADR 0034 Decisoes 8 e 12; baseline 20260910000000"
status: "candidatos prontos; aplicacao em producao pelo coordenador"
generated_at: "2026-09-10"
---

# Candidatos do grupo realm-interno

Backend da familia `chat` do Superadmin (realm interno v2) sobre a baseline de
producao. Ordem de aplicacao obrigatoria; cada arquivo tem preflight de
presenca de objeto e falha com `55000` se a dependencia faltar.

| Ordem | Arquivo | Assunto | pgTAP |
| --- | --- | --- | --- |
| 1 | `20260910240000_chat_production_contract_v1.sql` | contrato de producao do chat contextual (forma final dos historicos 20260812000000, 120244, 121146 e 20260825193128); revoke de `anon` nas tabelas de chat | `supabase/tests/chat_production_contract_v1_test.sql` 20/20 |
| 2 | `20260910240100_superadmin_internal_chat_v2.sql` | chat interno v2: `chat.internal.read/send` com labels e sem MFA, autor interno em `messages`, recibos e idempotencia, 6 RPCs `superadmin_chat_*_v2` | `superadmin_internal_chat_v2_baseline_test.sql` 23/23 |
| 3 | `20260910240200_superadmin_internal_chat_receipts_edit_revoke_v2.sql` | `chat.internal.manage`, trilha de edicao, recibo por mensagem, editar (15 min) e revogar | `superadmin_internal_chat_receipts_edit_revoke_baseline_test.sql` 36/36 |
| 4 | `20260910240300_chat_conversation_preferences_v1.sql` | fixar e bandeira por identidade interna; inbox devolve `pinned_at`/`flag` | `superadmin_internal_chat_preferences_baseline_test.sql` 10/10 |
| 5 | `20260910240400_superadmin_internal_chat_groups_v1.sql` | Criar grupo (P8): `superadmin_chat_create_group_v2` e `superadmin_chat_group_members_v2` | `superadmin_internal_chat_groups_v1_test.sql` 22/22 |
| 7 | `20260910240600_revoke_authenticated_truncate_references_trigger_v1.sql` | segurança básica: `authenticated` sem TRUNCATE (que ignora RLS), REFERENCES e TRIGGER nas 22 tabelas de `public` que ainda os concediam; SELECT/INSERT/UPDATE/DELETE intactos | `revoke_authenticated_truncate_references_trigger_v1_test.sql` 6/6 |
| 6 | `20260910240500_revoke_anon_direct_access_v1.sql` | segurança básica: `anon` sem privilégio em tabelas, sequências e funções de `public`, `app_private`, `audit` e `analytics` (em produção: 30 tabelas e 15 funções de `app_private` via PUBLIC); authenticated e service_role preservados | `revoke_anon_direct_access_v1_test.sql` 9/9 |

Os pacotes 1 a 5 foram aplicados em produção pelo coordenador no lote 9
(10/09 22:25) e provados com a sessão `qa-r03` (18/18, ver
`docs/reviews/evidence/etapa-2/r04-realm-interno/prova-producao-2026-09-10.md`).
O pacote 6 é independente dos anteriores e foi aplicado em produção pelo
coordenador (ledger `20260910240500`, conferido às 23:20 de 10/09: `anon`
sem tabela nem função nos schemas da aplicação; `authenticated` com 339
funções em `public` e 86 em `app_private`; sessão `qa-r03` lendo inbox e
thread normalmente).

Os testes `*_baseline_test.sql` substituem `superadmin_internal_chat_v2_test.sql`,
`superadmin_internal_chat_receipts_edit_revoke_test.sql` e
`superadmin_internal_chat_preferences_test.sql`, escritos para a cadeia
historica (AAL2 obrigatorio, auditoria com 14 argumentos) e que nao valem
sobre a baseline. Arquivar os tres e decisao do coordenador.

## Diferencas em relacao ao historico

- `platform_permissions` recebe `module_label`, `screen_label` e
  `action_label` (NOT NULL desde 20260811215451) e `requires_mfa=false`
  (ADR 0034, Decisao 12).
- `app_private.audit_append_superadmin_internal` e chamada com 13 argumentos,
  a assinatura de producao; o `jsonb` final do historico nao existe la.
- As policies de `conversations`, `messages` e `conversation_participants`
  de producao (`can_access_conversation`, com bypass `platform.read`) sao
  preservadas; `can_access_chat_conversation` (sem bypass) guarda apenas as
  RPCs contextuais. `message_receipts` e `message_edits` trocam
  `platform_read` pela leitura contextual, como o historico exigia.
- `anon` perde o `GRANT ALL` que a baseline mostra em `conversations`,
  `messages`, `message_edits` e `message_receipts`.
- Toda funcao nova tem `revoke all ... from public, anon, authenticated,
  service_role` antes do `grant execute ... to authenticated`.

## Como provar (fluxo usado em 10/09/2026)

`supabase db reset` com todas as `migrations/` falha em
`20260910170100_superadmin_internal_person_detail.sql`, que exige
`people.read` no catalogo antes de o seed rodar. O fluxo que reproduz
producao e:

1. projeto descartavel proprio (copiar `supabase/config.toml` com
   `project_id` e portas livres) com **somente a baseline** em
   `supabase/migrations/` e o `seed.sql`;
2. `supabase start -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor`
   (aplica baseline + seed);
3. as demais `migrations/` **na ordem real de produção**, lida de
   `migrations/ordem-de-aplicacao-producao.txt` (mantido pelo coordenador a
   cada lote; a ordem por carimbo não reproduz produção, porque o lote 3
   entrou antes do lote 4), via
   `docker exec -i supabase_db_<project_id> psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f -`
   (44/44 aplicaram limpas em 10/09; hoje o arquivo lista os lotes 1 a 10):

   ```bash
   C=supabase_db_<project_id>
   grep -v '^#' packages/coelo_database/migrations/ordem-de-aplicacao-producao.txt \
     | sed '/^$/d' | while read -r f; do
       docker exec -i "$C" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -f - \
         < "packages/coelo_database/migrations/$f" || { echo "ERRO em $f"; break; }
     done
   ```
4. os cinco candidatos na ordem, pelo mesmo `psql`;
5. cada pgTAP pelo mesmo `psql -qtA`, contando `ok`/`not ok`.

Nao ha `psql` na maquina; o do container serve.

## Contrato para o cliente

Assinaturas, envelopes e capacidades estao em
`docs/reviews/etapa-2-operacao/comunicacao/realm-interno.json` (campo
`contrato`). As 10 RPCs que `SupabaseChatRepository` ja chama nao mudam de
assinatura; Criar grupo e uma RPC nova.

## Rodada 5 (E2-R05-20260911) — faixa 2026091121xxxx

Backend transversal. Prova: descartável `coelo_realm_r05` (baseline + seed +
`ordem-de-aplicacao-producao.txt` + migrations que outros grupos publicaram
em `dev` durante a rodada + candidatos). pgTAP em `supabase/tests/`.

| Ordem | Arquivo | Assunto | pgTAP | Estado |
| --- | --- | --- | --- | --- |
| 1 | `20260911210000_institution_contacts_v1.sql` | documento, contato, representantes e administradores da instituição | `institution_contacts_v1_test.sql` 38 | produção (lote 28), movido para `migrations/` |
| 2 | `20260911210100_revoke_authenticated_crud_without_policy_v1.sql` | revoke presence-based de grants sem policy; `person_auth_links_self_read` | `revoke_authenticated_crud_without_policy_v1_test.sql` 12 | produção (lote 30) |
| 3 | `20260911210200_superadmin_internal_chat_attachments_v1.sql` | chat.attach (prepare/finalize/read/expire) | `superadmin_internal_chat_attachments_v1_test.sql` 28 | produção (lote 32) |
| 4 | `20260911210300_forms_question_media_r2_v1.sql` | imagem de pergunta no R2 | `forms_question_media_r2_v1_test.sql` 25 | produção (lote 33) |
| 5 | `20260911210400_structure_hierarchy_p36_v1.sql` | P36: atividade ativa exige turma | `structure_hierarchy_p36_v1_test.sql` 13 | produção (lote 35) |
| 6 | `20260911210500_unit_care_policies_notifications_v1.sql` | P32: políticas macro da unidade + sino | `unit_care_policies_notifications_v1_test.sql` 20 | produção (lote 36) |
| 7 | `20260911210600_institution_people_handles_v1.sql` | @ das pessoas no detalhe da instituição | `institution_people_handles_v1_test.sql` 4 | pronto |
| 8 | `20260911210700_chat_media_expire_dispatch_v1.sql` | cron do chat-media (Vault) | `media_expire_dispatch_v1_test.sql` 6 | pronto |
| 9 | `20260911210800_forms_answer_media_r2_v1.sql` | answer-image no R2 (espelho do `form_assets`) | `forms_answer_media_r2_v1_test.sql` 14 | pronto |
| 10 | `20260911210900_forms_media_expire_dispatch_v1.sql` | cron do form-media (Vault) | idem 8 | pronto |
| 11 | `20260911211000_plans_select_for_institution_directory_v1.sql` | SELECT em `plans` para a view `institution_directory` | `plans_select_for_institution_directory_v1_test.sql` 4 | opcional (decisão de code review) |

Endurecimento transversal: `r05_realm_interno_hardening_test.sql` (6).
Edge Functions escritas sem deploy: `functions/chat-media` (nova),
`functions/form-media` (ramos R2 atrás de `COELO_FORMS_MEDIA_PROVIDER=r2`,
`question_*`, `expire`), `functions/_shared/image_dimensions.ts`.
Handoff e evidências: `docs/reviews/evidence/etapa-2/r05-realm-interno/`.

## Rodada 8 (E2-R08-20260912) — lote 56 pendente de C0

| Ordem | Arquivo | Assunto | pgTAP | Estado |
| --- | --- | --- | --- | --- |
| 1 | `20260912140545_now_publication_expiry_dispatch_v1.sql` | agenda a transição material de publicações Agora vencidas pelo sweep interno existente; não remove mídia | `now_publication_expiry_dispatch_v1_test.sql` 6 | produção (lote 56; aplicação exclusiva C0) |
| 2 | `20260912140546_forms_question_media_draft_bridge_v1.sql` | primeira ponte de `question-image`; preservada sem mutação porque já foi consumida pelo espelho | `forms_question_media_r2_v1_test.sql` 32 no primeiro ciclo | aplicado somente no baseline G0; GREEN falhou; proibido em produção isoladamente |
| 3 | `20260912140547_forms_question_media_draft_bridge_fix_v1.sql` | corrige consumidores para autorização institucional, troca FK por `NO ACTION DEFERRABLE` e devolve `media_context: null` sem working version | `forms_question_media_r2_v1_test.sql` 33 | candidato corretivo; pendente GREEN/regressões no mesmo baseline |

O defeito foi medido apenas no repositório: a migration `20260910190500`
declara que o scheduler ficou externo e não existe outro job versionado para o
sweep. C0 deve consultar `cron.job` no espelho e em produção, executar o pgTAP
no espelho após os lotes 49–55 e cumprir backup/preflight antes de decidir o
lote 56. O item 1 foi aplicado pelo C0 após essas provas. O item 2 falhou no
primeiro GREEN do espelho e permanece imutável; o item 3 é sua correção
forward-only e deve ser aplicado sobre ele somente no baseline antes do novo
GREEN e das regressões. Em produção, 140546 e 140547 formam uma única unidade
serializada, somente após prova verde. A ordem acima é explícita; G5 não aplica
SQL.
