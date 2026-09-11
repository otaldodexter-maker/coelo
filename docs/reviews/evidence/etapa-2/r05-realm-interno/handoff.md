---
title: "Handoff — grupo realm-interno, Rodada 5 (E2-R05-20260911)"
grupo: "realm-interno"
branch: "work/etapa2-r05-realm-interno"
source: "comunicacao/realm-interno.json (revisoes 16-21); candidatos/realm-interno/20260911210000..210500"
generated_at: "2026-09-11"
status: "entregue ao coordenador; aplicacao em producao pelo coordenador"
---

# Handoff — realm-interno (backend transversal da R05)

## Recorte

Etapa 2 → apps/superadmin → backend transversal: Instituições (institutions.edit),
segurança de grants, Chat (chat.attach), Formulários (forms.upload/resolve-file/
download/expire-file/delete-file), Estrutura (P36) e Cuidado (P32). Só SQL +
pgTAP; nenhum cliente, nenhuma Edge Function implantada, nenhum Cloudflare.

## Prova local

Projeto descartável `coelo_realm_r05` (portas 625xx): baseline + `seed.sql` +
as 141 migrations de `migrations/ordem-de-aplicacao-producao.txt` via `psql`
do container, depois os seis candidatos na ordem. pgTAP desta rodada:
**188 PASS / 0 FAIL** (38 + 12 + 28 + 25 + 13 + 20 + 4 + 14 + 6 + 6 + 4 + 18). Regressão de 25 suítes
existentes: tudo igual ao espelho `supabase_db_coelo_baseline` do coordenador
(as falhas listadas abaixo já existem lá sem os pacotes).

## Entregue (candidatos/realm-interno, faixa 2026091121xxxx)

| Ordem | Pacote | Assunto | pgTAP | Estado |
| --- | --- | --- | --- | --- |
| 1 | `20260911210000_institution_contacts_v1.sql` | documento (CNPJ), contato, representantes e administradores como pessoas do realm; `detail_v2` devolve `representatives`/`administrators` mascarados; segredo Vault `coelo_person_identity_hmac_v1` (HMAC do CPF) | `institution_contacts_v1_test.sql` 38/38 | aplicado em produção (lote 28) |
| 2 | `20260911210100_revoke_authenticated_crud_without_policy_v1.sql` | revoke presence-based de I/U/D/SELECT de `authenticated` sem policy em tabelas com RLS; I/U/D em views; policy `person_auth_links_self_read`; sem grant novo | `revoke_authenticated_crud_without_policy_v1_test.sql` 12/12 | aplicado em produção (lote 30) |
| 3 | `20260911210200_superadmin_internal_chat_attachments_v1.sql` | chat.attach: prepare/authorize_finalize/authorize_read (authenticated), finalize/expire (service_role), tickets privados, 4 códigos novos no envelope | `superadmin_internal_chat_attachments_v1_test.sql` 28/28 | aplicado em produção (lote 32) |
| 4 | `20260911210300_forms_question_media_r2_v1.sql` | forms_files (question-image) no R2 sobre o catálogo 230007: prepare/authorize/finalize/resolve/delete/expire/limpeza | `forms_question_media_r2_v1_test.sql` 25/25 | aplicado em produção (lote 33) |
| 5 | `20260911210400_structure_hierarchy_p36_v1.sql` | P36: atividade ativa exige turma ativa (gatilhos diferidos); unidade→instituição e turma→unidade já garantidos pela baseline e provados | `structure_hierarchy_p36_v1_test.sql` 13/13 | aplicado em produção (lote 35) |
| 6 | `20260911210500_unit_care_policies_notifications_v1.sql` | P32: `unit_care_policies` + `superadmin_unit_care_policy_get/set_v1` + fan-out no sino (unidade, hierarquia da criança, demais responsáveis) por gatilho em autorizações, restrições e planos de medicação; pessoas de serviço nunca recebem | `unit_care_policies_notifications_v1_test.sql` 20/20 (com a ordem real do espelho) | aplicado em produção (lote 36) |
| 7 | `20260911210600_institution_people_handles_v1.sql` | Decisão 16: `detail_v2` devolve `handle` (@ de `person_handles`) em representantes e administradores | `institution_people_handles_v1_test.sql` 4/4 | pronto |
| 8 | `20260911210700_chat_media_expire_dispatch_v1.sql` | cron `coelo-chat-media-expire` (*/5) → chat-media `expire`; Vault `chat_media_worker_url/secret` | padrão 230023 | pronto |
| 9 | `20260911210800_forms_answer_media_r2_v1.sql` | answer-image no R2: `form_prepare_asset_upload_r2_v1` (legado + espelho), `form_asset_r2_descriptor_v1`, `form_media_finalize_answer_r2_v1`, gatilho de discard → fila de limpeza | `forms_answer_media_r2_v1_test.sql` 14/14 | pronto |
| 10 | `20260911210900_forms_media_expire_dispatch_v1.sql` | cron `coelo-forms-media-expire` (*/10) → form-media `cleanup` com o Bearer do worker de Formulários já no Vault; URL nova `forms_media_worker_url` | `media_expire_dispatch_v1_test.sql` 6/6 | pronto |
| 11 | `20260911211000_plans_select_for_institution_directory_v1.sql` | SELECT em `plans` para `authenticated` (policy já existia) para a view `institution_directory` responder | `plans_select_for_institution_directory_v1_test.sql` 4/4 | opcional; aplicado (lote 28-42) |
| 12 | `20260911211100_structure_handles_create_payload_v1.sql` | Decisão 16 sobre o `180000` da G1: `handle` opcional na criação de turma/unidade/atividade, padrão hierárquico, disponibilidade global, handle nos `detail_v2` de Unidades e Turmas | `structure_handles_create_payload_v1_test.sql` 18/18 (+ suítes de detalhe atualizadas) | pronto; após o 180000 |

## Edge Functions escritas (deploy do coordenador)

| Função | O que mudou | Testes |
| --- | --- | --- |
| `chat-media` (nova) | prepare (PUT assinado), finalize (ticket do usuário + bytes relidos + sha256 + RPC service_role), read (GET assinado), expire (x-worker-secret); `COELO_R2_*`, `CHAT_MEDIA_ALLOWED_ORIGINS`, `CHAT_MEDIA_WORKER_SECRET`; `config.toml` `verify_jwt=false` | Deno 5/5 |
| `_shared/image_dimensions.ts` (novo) | largura/altura do cabeçalho JPEG/PNG/WebP para preencher `pixel_width/height` a partir dos bytes | Deno 2/2 |
| `form-media` | reconciliada com a versão da G3 (question-image e worker dela mantidos); acrescentados só os ramos R2 de RESPOSTAS (prepare/finalize/download) atrás de `COELO_FORMS_MEDIA_PROVIDER=r2` | Deno 51/51 (47 da G3 + 4) |

Contratos completos (assinaturas, envelopes, códigos, limites) em
`comunicacao/realm-interno.json`: `contratoInstitutionContacts`,
`contratoChatAttach`, `contratoFormsFiles`, `contratoP32`.

## Aberto e primeiro gate

| Item | Primeiro gate |
| --- | --- |
| institutions.edit E2E | frente estrutura chamar `superadmin_institution_contacts_edit_v1` após o `edit_core_v2` e ler `representatives`/`administrators` do `detail_v2`; provar na rota real |
| chat.attach | deploy de `chat-media` + segredos + cron 210700; cliente do principal-chat liga o picker |
| forms.upload/resolve-file/download/expire-file/delete-file | deploy de `form-media` com `COELO_FORMS_MEDIA_PROVIDER=r2`, `FORMS_MEDIA_WORKER_SECRET` e cron 210900; cliente da frente formularios usa `question_*` (autoria) e `upload_url/required_headers` (respostas) |
| P36 no cliente | assistente de Atividades liga a turma antes de publicar e mapeia 23514 `activity must retain at least one active group link` |
| P32 no cliente | tela de políticas macro da unidade (get/set); os modos são registrados e devolvidos; o fluxo que os aplica (quem libera) é produto pós-Superadmin |
| @ das pessoas (Decisão 16) | pacote 210600 devolve o @ de `person_handles`; edição pelo cliente via `superadmin_person_handle_get/set/availability` (170100) |
| `institution_directory` (view) | `plans` sem SELECT para authenticated: leitura direta falha; cliente lê por RPC; decisão de code review |

## Code review R04 (item 7): achados, sem alteração

Medido no descartável (corpo atual × baseline) para o 180060:

1. `app_private.has_activity_capability`: além de reformatação, passou a exigir
   `assignment.assignment_role='instructor'` e ganhou a CTE `explicit_action`
   (`activity_assignment_capability_actions`) e a composição por
   `activity_v2_effective_permission`. Mudança de comportamento para as
   policies contextuais do realm de pessoas: atribuições que não são
   `instructor` deixam de ter capacidade. Confirmar com produto antes de manter.
2. `app_private.audit_activity_change`: quando o marcador interno é válido,
   suprime a linha legada de auditoria (`suppress_legacy`) e confia na
   auditoria do gateway interno (14 args); marcador inválido cai no caminho
   legado com `actor_person_id` nulo (o `exception when others` engole o erro).
   Defensável; registrar que a auditoria legada de Atividades passa a ter
   `actor_person_id` nulo para atores internos sem marcador.
3. `app_private.audit_mask_payload`: só acrescenta a allowlist `counts`
   (inteiros não negativos em units/groups/participants/professionals/
   settings/actions). Seguro.
4. Sobrecarga de 14 argumentos de `audit_append_superadmin_internal`
   (`p_after_json jsonb`): coexiste com a de 13; 11 funções chamam a de 14; a
   resolução é por contagem de argumentos (sem ambiguidade); nenhum papel de
   cliente executa nenhuma das duas. Manter as duas e documentar na skill.

## Falhas pré-existentes conferidas no espelho (não são regressão)

`superadmin_internal_institution_edit_core_test` (7: MFA fora do MVP e fluxo
antigo), `superadmin_internal_chat_groups_v1_test` (provenance da fixture de
atividades), `activity_management_end_to_end_test` (16: Storage legado),
`health_care_and_medication_plans_v1_test` (1: metadado de MFA),
`child_safety_production_test` (`schemaname` inexistente).

## Segredos criados

`coelo_person_identity_hmac_v1` (Vault, criado pela migration 210000 no
banco; valor nunca impresso). Roteiro de geração/rotação na skill
`coelo-backend` (delta abaixo).
