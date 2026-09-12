---
title: "Candidatos principal-chat-sistema (Rodada 6, E2-R06-20260911)"
source: "comunicacao/principal-chat-sistema.json rev 31; coordenacao.json respostasDoOwnerR05 P48 = A; pacote 20260911130000 em producao"
status: "candidato verde no descartavel coelo_pcs6_db (clone do espelho coelo_baseline); aplicacao em producao pelo coordenador"
generated_at: "2026-09-11"
---

# Candidatos do grupo principal-chat-sistema (R06)

| Ordem | Arquivo | Assunto | pgTAP |
| --- | --- | --- | --- |
| 1 | `20260911130400_internal_actor_institution_access_by_role_v1.sql` | P48 = A: papel de sistema `institution_reader` (Leitura, so `*.read`) e sincronizador `superadmin_internal_actor_institution_access_sync()` por papel interno: owner -> membership `owner` + `institution_admin`; operations -> membership `professional` + `institution_reader`; demais papeis internos sem vinculo automatico (o que o 130000 tinha concedido e revogado: `inactive` + `revoked_at`). Backfill na aplicacao; gatilhos do 130000 preservados. | `supabase/tests/internal_actor_institution_access_by_role_v1_test.sql` 16/16; regressao `principal_internal_actor_bridge_v1_test` 22/22, `principal_runtime_contexts_test` 13/13, `internal_actor_service_person_v1_test` 17/17, `happens_feed_owner_visibility_v1_test` 6/6 |
| 2 | `20260911130500_meal_plan_scope_rules_object_v1.sql` | Cardapios: `meal_plan_create_or_update_draft_unreceipted` recriada (corpo da baseline) aceitando `scopeRules` como objeto (formato do assistente) ou lista; helpers `app_private.meal_plan_scope_rules_object/array`; grava objeto (check `meal_plans_scope_rules_array_check`) e deriva `meal_plan_scopes`. Destrava `meal-plans.create/edit/publish` (gate medido nas capturas 11 e 23). | `supabase/tests/meal_plan_scope_rules_object_v1_test.sql` 9/9; regressao `meal_plans_owner_permission_grants_v1` 6/6, `meal_plan_image_delete_requires_revision` 6/6; `meal_plan_media_lifecycle_receipts` 28/30 e `meal_plans_security_lifecycle` 21/22 falham so em asserções de grant de `service_role`/`anon` em funções que o pacote não toca (artefato do clone) |

Depois de aplicar em producao: `select app_private.superadmin_internal_actor_institution_access_sync();`
deve devolver 0 na segunda chamada; conferir que os `qa-r06-*` (owner) continuam
com 3 contextos em `list_my_principal_contexts()` e que um usuario interno
`operations` passa a ler sem publicar (`happens_permission_denied` em
`save_happens_draft`).
