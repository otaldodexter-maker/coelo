---
title: "Base reproduzível: replay quebrado, conjunto local vazio e objetos chamados sem CREATE"
source: "Medições próprias na rodada noturna de 2026-09-09/10, em Postgres local efêmero (postgres:15 e public.ecr.aws/supabase/postgres:17.6.1.165) e busca sobre packages/coelo_database"
status: "measured-not-diagnosed"
generated_at: "2026-09-10"
---

# Recorte e limites

Medição de **se a base do Coelo pode ser reconstruída**, não de por que cada
lacuna existe. Nenhuma migration foi alterada, nada foi aplicado remotamente e
os containers usados foram removidos. Não afirmo causa raiz nem responsabilidade.

A pergunta que decide trabalho do Owner: E2E está em 0/198 porque as frentes não
priorizaram, ou porque não existe base onde rodar?

## Fato 1 — o replay de `migrations/` não atravessa

186 arquivos de `packages/coelo_database/migrations`, replayados em ordem de nome
numa base zerada com um shim de Supabase (schemas `auth`, `extensions`,
`storage`, `app_private`, `audit`, `supabase_migrations`; papéis `anon`,
`authenticated`, `service_role`; `pgcrypto` no schema `extensions`; stubs de
`auth.users`, `storage.buckets` e `storage.objects`):

- arquivos 1 a 47 aplicam **limpos**;
- o arquivo 48, `20260812002000_child_safety_schema.sql`, falha na linha 192 com
  `null value in column "module_label" of relation "platform_permissions"
  violates not-null constraint`;
- a partir dali a cascata contamina o resto e o número deixa de significar.

Causa rastreada: `20260811215451_access_profile_management_v2.sql`, que roda
antes, adiciona `module_label` **sem default** e depois faz
`alter column module_label set not null`. O arquivo 48 insere códigos de
permissão novos sem essa coluna, e o `on conflict do update` também não a define.
Os códigos `child_safety.*` só aparecem a partir do próprio 48, então num replay
do zero é o caminho de INSERT que roda.

Relaxando esse NOT NULL, o **mesmo arquivo** falha em seguida com
`column "updated_at" of relation "platform_role_permissions" does not exist`.
São pelo menos dois problemas independentes de replay no arquivo 48.

A barreira persiste no Postgres 17, então não é diferença de versão.

## Fato 2 — o conjunto que `supabase start` aplicaria não cria schema

`packages/coelo_database/supabase/config.toml` aponta para
`packages/coelo_database/supabase/migrations`, que tem **17 arquivos** e
**zero `create table`**. São 14 `create or replace function` de "final review
lint hardening" mais revokes. `list_my_principal_contexts` e
`list_visible_profile_circulars` não estão lá.

Um `supabase start` sobe um banco praticamente vazio do ponto de vista do Coelo.

## Fato 3 — 40 objetos `app_private` são chamados e nunca criados

Conjunto de objetos `app_private` chamados no SQL versionado contra o conjunto
criado: **605 chamados distintos**, **527 funções criadas**, **63 tabelas
criadas**, sobrando **40 chamados sem CREATE**.

Cinco conferidos à mão com busca por `function app_private.<nome>`, que pegaria
tanto CREATE quanto DROP: `profile_about_can`, `routine_receipt`,
`student_tracking_can_read` e `normalize_person_handle` têm **zero** ocorrências.

Domínios atingidos: `routine` (9), `superadmin_unit` import/export (8),
`student_tracking` (4), `profile_about` (3), `meal_plan` (2), mais
`assert_access_profile_assignment_delegable`, `assert_unit_file_access`,
`create_unit_for_superadmin`, `enforce_unit_branding_identity_ownership`,
`normalize_person_handle` e quatro de `legal_representative`.

Lista completa, agrupada por domínio. **`[conferido]`** marca os que foram
verificados individualmente com busca por `function app_private.<nome>`; os
demais vêm do método de conjuntos e não foram inspecionados um a um. Essa
distinção precisa sobreviver ao arquivo: 40 não são 40 fatos verificados.

**routine — 9** (domínio de alunos-rotina)
```
require_routine_actor
require_routine_scope
routine_definition_json
routine_receipt                                   [conferido]
routine_scope_allowed
validate_routine_launch_answers
superadmin_routine_correct_launch
superadmin_routine_revert_application
superadmin_routine_save_application
```

**superadmin_unit — import/export e arquivos — 8**
```
superadmin_complete_unit_file_job
superadmin_create_unit_import_job
superadmin_get_unit_file_job
superadmin_materialize_unit_export_from_edge
superadmin_preview_unit_import
superadmin_preview_unit_import_from_edge
superadmin_request_unit_export
unit_file_job_payload
```

**student_tracking — 4** (domínio de alunos-rotina)
```
student_tracking_activity_allowed
student_tracking_can_read                         [conferido]
student_tracking_children
student_tracking_snapshot
```

**unit — identidade e exportação paginada — 4**
```
superadmin_confirm_unit_identity_delete
superadmin_finalize_unit_identity_upload
superadmin_unit_export_page
superadmin_unit_export_page_v2
```

**legal_representative — 4**
```
close_incompatible_legal_representatives_for_person
close_legal_representatives_for_membership
touch_institution_legal_representative_updated_at
validate_institution_legal_representative
```

**profile_about — 3** (domínio deste recorte)
```
profile_about_allowed_field
profile_about_can                                 [conferido]
profile_about_page_for
```

**meal_plan — 2**
```
meal_plan_finalize_image_upload_unreceipted
meal_plan_request_image_delete_unreceipted
```

**avulsos — 6**
```
assert_access_profile_assignment_delegable
assert_unit_file_access
create_unit_for_superadmin
enforce_unit_branding_identity_ownership
normalize_person_handle                           [conferido]
superadmin_unit_import_template
```

O quinto conferido à mão foi `meal_plan_finalize_image_upload_unreceipted`, que
é o único dos cinco com **uma** ocorrência de `function app_private.<nome>` em
vez de zero. Não inspecionei se essa ocorrência é um CREATE ou um DROP, então
ele fica marcado como caso a olhar antes de qualquer conclusão sobre meal_plan.

O domínio `profile_about` não tem **nenhum** `create table profile_about_*` em
conjunto algum: o único artefato versionado é o `create or replace` de
`public.save_profile_about`.

## Fato 4 — não é universal, e isso é a boa notícia

`child_safety` e `chat` estão versionados por inteiro: tabelas e funções
`app_private` do domínio são criadas em migration. Existe padrão correto na
própria casa para seguir; a diferença é por domínio, não da ferramenta.

## Consequência

Reconstruir a base hoje depende de dump. Isso não é só recuperação de desastre:
é a condição para existir homologação e, portanto, para existir E2E. Enquanto
não houver caminho de recriação, E2E permanece zero por construção, e nenhum
esforço de frente muda isso — a única base disponível é produção, e produção é
onde ninguém pode rodar E2E sem autorização nominal.

## Ressalvas

Os 40 são objetos, não defeitos: um helper pode servir a vários domínios. A
medição não distingue helper que nunca existiu de helper que existe no remoto e
nunca foi versionado — para reconstruir a base dá no mesmo, para atribuir
responsabilidade não dá. Cinco foram conferidos individualmente; os outros 35
vêm do método.

## Nota de versão

A primeira medição usou `postgres:15` e o Coelo roda **Postgres 17**. Isso
produziu dois falsos positivos de "syntax error" em migrations já aplicadas em
produção: `count(authorization.id)` usa `authorization`, palavra reservada que o
15 recusa como qualificador e o 17 aceita. Provado por controle: a mesma função
extraída falha no 15 e, no 17, devolve apenas `schema "app_private" does not
exist`. Ausência de erro no 15 bastaria para o 17, mas o inverso não vale.
Medir na versão de produção é condição para a afirmação valer nos dois sentidos.
