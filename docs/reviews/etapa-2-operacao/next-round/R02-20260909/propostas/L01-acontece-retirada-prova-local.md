---
title: "Prova local em Postgres descartável da retirada de publicação do Acontece"
source: "packages/coelo_database/migrations/20260909133000_happens_post_withdrawal_v1.sql; packages/coelo_database/migrations/20260820182000_happens_publication_mvp.sql; packages/coelo_database/migrations/20260820182100_happens_media_security_closure.sql; packages/coelo_database/supabase/tests/happens_post_withdrawal_test.sql; packages/coelo_database/supabase/tests/happens_publication_test.sql; execução local em container descartável em 2026-09-09"
status: "prova-local-verificada"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Acontece — retirada de publicação: prova local em banco descartável

## Aviso de escopo

Esta é uma prova **LOCAL**, feita num container Docker descartável, criado e
destruído dentro desta verificação. **Não é certificação ponta a ponta** e
**não é prova de ambiente remoto**. Nenhum recurso Supabase ou Cloudflare
remoto foi tocado, consultado ou alterado. Nenhum arquivo da worktree foi
alterado além deste relatório. Nenhum comando `git` foi executado na worktree.

O que esta prova cobre: a migration aplica sobre a cadeia local, os dois testes
pgTAP correspondentes rodam com os números registrados abaixo, e o
comportamento observável da RPC `public.withdraw_happens_post` e da projeção
`public.list_visible_happens_posts` corresponde ao especificado quando
exercitado com dados sintéticos.

O que esta prova **não** cobre: comportamento do cliente Flutter, integração
com R2/Stream, RLS sob PostgREST real, GoTrue real, storage-api real,
concorrência sob carga, ou qualquer estado do projeto remoto.

## Ambiente

| Item | Valor |
| --- | --- |
| Imagem | `public.ecr.aws/supabase/postgres:17.6.1.165` (imagem local já presente) |
| Container | `coelo-l01-probe` (descartável, removido ao final) |
| Versão do servidor | `PostgreSQL 17.6 on x86_64-pc-linux-gnu, compiled by gcc (GCC) 15.2.0, 64-bit` |
| pgTAP | `1.3.3` (extensão disponível na imagem, criada em `extensions`) |
| Host | Windows 11, Docker Desktop |

### Shims necessários (prelúdio)

A imagem `supabase/postgres` traz o schema `auth` e o schema `storage`
**vazios de artefatos que os serviços criam em runtime** (GoTrue e
storage-api). A cadeia de migrations do Coelo depende de dois deles, então o
prelúdio abaixo foi aplicado como `supabase_admin` **antes** das migrations.
Estes objetos **não** pertencem ao Coelo e **não** substituem o replay
canônico via Supabase CLI (`packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1`),
que sobe a stack completa; foram usados só para permitir o replay direto por
`psql` neste container mínimo.

- `auth.jwt()` — função padrão do Supabase, ausente nesta imagem (só existiam
  `auth.uid()`, `auth.role()`, `auth.email()`).
- `storage.buckets`, `storage.objects`, `storage.foldername()`,
  `storage.filename()`, `storage.extension()` — tabelas/funções que o
  storage-api cria; sem elas, `20260820182000_happens_publication_mvp.sql`
  falha ao registrar o bucket `coelo-happens-mvp`.

## Migrations aplicadas

Aplicação forward-only, por ordem de nome de arquivo (`ls /mig/*.sql | sort`),
uma transação por arquivo (`psql -v ON_ERROR_STOP=1 --single-transaction`),
parando no alvo `20260909133000`.

- Total de arquivos considerados (`<= 20260909133000`): **168**
- Aplicados com sucesso: **122**
- Falharam: **46**

As três migrations exigidas pelo recorte aplicaram **todas com sucesso**, na
ordem correta:

| Ordem | Migration | Resultado |
| --- | --- | --- |
| 1 | `20260820182000_happens_publication_mvp.sql` | `OK` |
| 2 | `20260820182100_happens_media_security_closure.sql` | `OK` |
| 3 | `20260909133000_happens_post_withdrawal_v1.sql` | `OK` |

### Subconjunto efetivo e as 46 falhas

A cadeia inteira **não** aplicou limpa neste harness mínimo. As 46 falhas
concentram-se em domínios **fora** do recorte (Formulários, Child Safety,
Avisos/Notices, Import/Export, Chat v2, Assessments, Circulares internas v2) e
são majoritariamente em cascata: a primeira falha de um domínio derruba as
migrations seguintes que dependem das tabelas que ela criaria.

Causas-raiz observadas (as demais são consequência):

- `null value in column "module_label" of relation "platform_permissions" violates not-null constraint`
  (`20260812002000_child_safety_schema.sql`, `20260812002200_child_safety_security_closure.sql`,
  `20260812003000_notices_production.sql`);
- `syntax error` em `20260812002100_child_safety_read_models.sql` e
  `20260813155005_forms_definition_and_capabilities.sql`;
- `missing FROM-clause entry for table "p_notice"` em
  `20260820204824_app_communications_contract.sql`.

Essas falhas **não** foram investigadas: estão fora do recorte L01 e não
bloqueiam o domínio Acontece. Elas podem ser artefato do replay direto por
`psql` (o caminho canônico do repositório é o Supabase CLI com a stack
completa) e **não** devem ser lidas como defeito confirmado dessas migrations.

Lista completa das 46 falhas:

```
20260812002000_child_safety_schema.sql
20260812002010_import_export_unit_source_retention.sql
20260812002020_import_export_hub_private_revokes.sql
20260812002100_child_safety_read_models.sql
20260812002200_child_safety_security_closure.sql
20260812003000_notices_production.sql
20260813155005_forms_definition_and_capabilities.sql
20260813155116_forms_distribution_and_occurrences.sql
20260813155118_forms_responses_and_private_media.sql
20260813155121_forms_commands_and_projections.sql
20260813155124_forms_jobs_notifications_and_exports.sql
20260813155126_forms_security_performance_closure.sql
20260813170001_forms_monitor_hierarchy.sql
20260820152528_forms_editor_application_capability_guard.sql
20260820154638_forms_distribution_cardinality_limits.sql
20260820164500_forms_export_download_authorization.sql
20260820164600_forms_export_download_capability_hardening.sql
20260820204824_app_communications_contract.sql
20260820212340_notice_publication_worker_runtime.sql
20260820220500_notice_publication_receipts_versioning.sql
20260825173938_close_legacy_unit_import_export_gateways.sql
20260825174300_expose_scoped_unit_failure_gateway.sql
20260825180000_revoke_student_tracking_normalizer_client_execute.sql
20260825180500_repair_unit_import_export_runtime_contract.sql
20260825193105_final_review_unit_identity_lint_hardening.sql
20260825193112_final_review_daily_routine_lint_hardening.sql
20260825193120_final_review_forms_runtime_hardening.sql
20260825193131_final_review_profile_about_lint_hardening.sql
20260901101500_superadmin_internal_chat_v2.sql
20260901182838_superadmin_assessments_internal_v2.sql
20260901183919_close_private_import_export_execute.sql
20260901185008_superadmin_internal_notices_v2.sql
20260901190719_import_edge_service_role_bridges.sql
20260901190927_deploy_superadmin_internal_auth.sql
20260901191921_superadmin_internal_circulars_v2.sql
20260901194209_forms_distribution_target_authorization.sql
20260901194256_forms_distribution_rpc_grants_hardening.sql
20260908000049_superadmin_forms_directory_internal_read.sql
20260908030000_superadmin_internal_form_drafts_v2.sql
20260908032100_superadmin_forms_authoring_institution_context_v2.sql
20260908054000_forms_internal_provenance_guards.sql
20260908160000_private_media_catalog_r2_v1.sql
20260908170000_forms_xlsx_private_r2_v1.sql
20260908191327_forms_response_edit_validation_v1.sql
20260908195512_forms_superadmin_operations_read_v2.sql
20260908215522_forms_superadmin_media_read_r2_v1.sql
```

Todas as dependências diretas do domínio Acontece — `institutions`, `units`,
`groups`, `people`, `person_auth_links`, `institution_memberships`,
`institution_permissions`, `institution_member_permission_overrides`,
`app_private.has_institution_permission` / `has_context_permission` — foram
criadas pelas 122 migrations aplicadas, e por isso a prova comportamental
abaixo pôde ser executada por completo.

## Comandos exatos executados

```powershell
# 1) Container descartável
docker images                       # confirma public.ecr.aws/supabase/postgres:17.6.1.165
docker run -d --name coelo-l01-probe -e POSTGRES_PASSWORD=postgres `
  public.ecr.aws/supabase/postgres:17.6.1.165

# 2) Cópia somente-leitura da worktree para dentro do container
docker cp packages/coelo_database/migrations      coelo-l01-probe:/mig
docker cp packages/coelo_database/supabase/tests  coelo-l01-probe:/tests
docker cp prelude.sql                             coelo-l01-probe:/prelude.sql

# 3) Shims de auth/storage (fora do escopo Coelo)
docker exec coelo-l01-probe sh -c 'psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -f /prelude.sql'
```

Replay (`/apply.sh` dentro do container):

```sh
for f in $(ls /mig/*.sql | sort); do
  base=$(basename "$f"); ver=${base%%_*}
  if [ "$ver" \> "20260909133000" ]; then continue; fi
  psql -U postgres -v ON_ERROR_STOP=1 --single-transaction -q -f "$f"
done
```

Testes pgTAP:

```sh
psql -U postgres -q -c "create extension if not exists pgtap with schema extensions;"
psql -U postgres -X -q -f /tests/happens_post_withdrawal_test.sql
psql -U postgres -X -q -f /tests/happens_publication_test.sql
```

Sonda comportamental (transação única com `rollback` no fim, executada como
`supabase_admin` para as fixtures e com `set local role authenticated` +
`request.jwt.claim.sub` para cada chamada de RPC):

```sh
psql -U supabase_admin -d postgres -X -q -v ON_ERROR_STOP=1 -f /probe.sql
```

Encerramento:

```powershell
docker rm -f coelo-l01-probe
```

## Saída real dos testes pgTAP

### `supabase/tests/happens_post_withdrawal_test.sql` — plano `1..18`

**17 `ok`, 1 `not ok`.**

```
ok 1 - withdrawal timestamp exists
ok 2 - withdrawal actor exists
ok 3 - withdrawal reason exists
ok 4 - removal capability is catalogued and active
ok 5 - withdrawal command exists
ok 6 - withdrawal command is security definer
not ok 7 - withdrawal command pins an empty search path
# Failed test 7: "withdrawal command pins an empty search path"
ok 8 - authenticated withdraws through the RPC
ok 9 - anonymous callers cannot withdraw
ok 10 - withdrawal checks the removal capability
ok 11 - only the author withdraws their own post
ok 12 - withdrawal uses the optimistic version
ok 13 - a draft cannot be withdrawn
ok 14 - withdrawal writes a publication audit event
ok 15 - withdrawal never deletes the post or its media
ok 16 - the feed hides withdrawn posts
ok 17 - the feed only offers withdrawal to the author
ok 18 - the rebuilt feed stays tenant scoped
# Looks like you failed 1 test of 18
```

#### Análise do `not ok 7` — defeito no teste, não na migration

A migration está correta. `withdraw_happens_post` declara
`set search_path=''`, e o catálogo confirma:

```
withdraw_happens_post       | {"search_path=\"\""}
list_visible_happens_posts  | {"search_path=\"\""}
save_happens_draft          | {"search_path=\"\""}
publish_happens_post        | {"search_path=\"\""}
```

Ou seja, o elemento de `proconfig` é `search_path=""` (com as aspas), não
`search_path=`. A asserção do teste é:

```sql
(select proconfig from pg_proc where oid='public.withdraw_happens_post(uuid,uuid,bigint,text)'::regprocedure)
  @> array['search_path=']
```

Este literal **nunca** pode ser verdadeiro. A convenção já estabelecida no
repositório usa o literal correto:

- `supabase/tests/now_publication_expiry_transition_test.sql:27,33` → `array['search_path=""']::text[]`
- `supabase/tests/circulars_media_private_r2_v1_test.sql:154` → `array['search_path=""']::text[]`
- `supabase/tests/forms_definition_test.sql:153` → `array['search_path=""']`
- `supabase/tests/audit_production_test.sql:68` → `array['search_path=""']`

O mesmo erro aparece em outro arquivo desta rodada:
`supabase/tests/moments_feed_and_withdrawal_test.sql:36,42` também usa
`array['search_path=']`.

Correção proposta (não aplicada — esta verificação é somente leitura): trocar
`array['search_path=']` por `array['search_path=""']` em
`happens_post_withdrawal_test.sql` (e, no mesmo turno, em
`moments_feed_and_withdrawal_test.sql`).

### `supabase/tests/happens_publication_test.sql` — plano `1..53`

**53 `ok`, 0 `not ok`.** Nenhuma falha; `finish()` não emitiu linhas, o que
indica plano cumprido. Destaques relevantes ao recorte:

```
ok 41 - feed exposes only the minimum presentation projection plus the withdrawal handle
ok 34 - feed query remains tenant scoped
ok 39 - feed visibility derives scheduled state from time
ok 44 - feed issues opaque media read tickets instead of storage paths
```

O `ok 41` confirma que a assinatura de retorno reconstruída bate exatamente
com `TABLE(post_id uuid, author_name text, author_initials text, context_label
text, caption text, published_at timestamp with time zone, management_version
bigint, can_withdraw boolean, media jsonb)` — ou seja, o `drop`+`create` da
migration não quebrou o contrato esperado pelo teste ajustado.

## Sonda comportamental com dados sintéticos

Fixtures criadas na transação: 2 usuários `auth.users`, 2 `people`, 2
`person_auth_links`, 1 `institution` (`active`), 2 `institution_memberships`
(`role_code = 'teacher'`), permissões `happens.posts.read` e
`happens.posts.remove` concedidas via
`institution_member_permission_overrides` (`effect='allow'`,
`scope_kind='institution'`), 3 `posts` (P1 e P2 `published`, P3 `draft`), 2
`post_audiences` (`school_staff`, que casa com `teacher` em
`app_private.happens_audience_matches_role`), 1 `media_assets` (`ready`) e 1
`media_links` ligados a P1. Ator A = autor de todos os posts; ator B = outro
membro da mesma instituição.

Saída literal:

```
step | detail
01-feed-autor-antes | post_id=ae000000-0000-4000-8000-000000000001 can_withdraw=t management_version=1 media_items=1
02-feed-outro-antes | post_id=ae000000-0000-4000-8000-000000000001 can_withdraw=f management_version=1
03-retirada-1a-chamada | {"id": "ae000000-0000-4000-8000-000000000001", "status": "published", "withdrawn_at": "2026-09-09T16:26:17.853758+00:00", "management_version": 2}
04-feed-autor-depois | AUSENTE DO FEED
05-retirada-2a-chamada | {"id": "ae000000-0000-4000-8000-000000000001", "status": "published", "withdrawn_at": "2026-09-09T16:26:17.853758+00:00", "management_version": 2}
06-conflito-versao | sqlstate=40001 message=expected_version_conflict
07-rascunho | sqlstate=23514 message=post_not_published
08-linha-posts | linha_existe=t status=published withdrawn_at_nao_nulo=t withdrawn_by=ab000000-0000-4000-8000-000000000001 autor=ab000000-0000-4000-8000-000000000001 withdrawn_by_eh_autor=t management_version=2 withdrawal_reason='motivo de teste'
09-midia-preservada | media_links=1 media_assets=1 asset_status=ready
10-auditoria | post_withdrawn_P1=1 total_eventos_P1=1 detalhes=post_withdrawn actor=ab000000-0000-4000-8000-000000000001 {"reason": "motivo de teste", "request_id": "ba000000-0000-4000-8000-000000000001"}
11-p2-intacto | withdrawn_at_nao_nulo=f management_version=1
```

### Resultado item a item

| # | Item exigido | Resultado | Evidência |
| --- | --- | --- | --- |
| 1 | Publicação `published` do autor, retirada pela RPC, passa a ter `withdrawn_at` preenchido | **PROVADO** | `08`: `withdrawn_at_nao_nulo=t`; `03` devolve `withdrawn_at` não nulo |
| 2 | `withdrawn_by_person_id` igual ao autor | **PROVADO** | `08`: `withdrawn_by=ab...001`, `autor=ab...001`, `withdrawn_by_eh_autor=t` |
| 3 | `management_version` incrementado | **PROVADO** | `01` → versão `1`; `03`/`08` → versão `2` |
| 4 | Some de `list_visible_happens_posts` | **PROVADO** | `04`: `AUSENTE DO FEED` (mesmo ator, mesma chamada de `01`) |
| 5 | 2ª chamada não erra | **PROVADO** | `05` retornou JSON, sem exceção |
| 6 | 2ª chamada não grava segunda linha de auditoria | **PROVADO** | `10`: `post_withdrawn_P1=1`, `total_eventos_P1=1` |
| 7 | 2ª chamada não incrementa a versão de novo | **PROVADO** | `05` e `08` continuam em `management_version=2` |
| 8 | `p_expected_version` desatualizado levanta `serialization_failure` / `expected_version_conflict` | **PROVADO** | `06`: `sqlstate=40001` (`serialization_failure`), `message=expected_version_conflict` |
| 9 | Publicação em `draft` levanta `check_violation` / `post_not_published` | **PROVADO** | `07`: `sqlstate=23514` (`check_violation`), `message=post_not_published` |
| 10 | Linha da publicação continua existindo (retirada é soft) | **PROVADO** | `08`: `linha_existe=t`, `status=published` preservado |
| 11 | `media_links` e `media_assets` continuam existindo | **PROVADO** | `09`: `media_links=1 media_assets=1 asset_status=ready` |
| 12 | Exatamente uma linha `post_withdrawn` em `app_private.happens_publication_audit` | **PROVADO** | `10`: `post_withdrawn_P1=1` e `total_eventos_P1=1` |
| 13 | `list_visible_happens_posts` devolve `can_withdraw=true` para o autor | **PROVADO** | `01`: `can_withdraw=t` |
| 14 | `list_visible_happens_posts` devolve `can_withdraw=false` para outro ator | **PROVADO** | `02`: `can_withdraw=f`, com B também tendo `happens.posts.remove` concedido — ou seja, o `false` vem da autoria, não da falta de permissão |
| 15 | `list_visible_happens_posts` devolve `post_id` e `management_version` | **PROVADO** | `01` e `02` projetam os dois campos |

### Observações adicionais confirmadas na sonda

- **Normalização do motivo**: a chamada passou `'  motivo de teste  '` e a
  linha gravou `'motivo de teste'`. O `nullif(btrim(...))` funciona, e a mesma
  string normalizada aparece em `detail->>'reason'` na auditoria.
- **`request_id` rastreado**: a auditoria registra
  `{"request_id": "ba000000-...-0001"}`, o `p_request_id` da primeira chamada.
  A segunda chamada (idempotente) **não** registra seu próprio `request_id`,
  porque retorna antes de escrever. É o comportamento esperado para
  idempotência, mas vale notar que o `request_id` da retentativa não fica
  rastreável.
- **Efeito colateral zero em vizinhos**: `11` mostra P2 intacto
  (`withdrawn_at` nulo, versão `1`) depois de a retirada de P1 e a tentativa
  falha de conflito de versão em P2 terem rodado.
- **Item 14 é forte**: B recebeu `happens.posts.remove` de propósito, então
  `can_withdraw=f` prova a regra de autoria e não uma ausência de capacidade.

## O que NÃO foi possível provar

1. **`not ok 7` do pgTAP não é falha da migration.** Está provado que a
   asserção do teste usa o literal errado (`'search_path='` em vez de
   `'search_path=""'`) e que a função de fato fixa `search_path=''`. Não
   corrigi o arquivo porque este subagente é de verificação, não de
   implementação.
2. **Cadeia de migrations não aplicou 100% neste harness.** 46 de 168 falharam
   em domínios fora do recorte. Não foi provado que a cadeia completa aplica
   limpa; foi provado que o subconjunto de 122 migrations que aplicou é
   suficiente para o domínio Acontece e que as três migrations do recorte
   aplicaram com sucesso.
3. **`auth.jwt()` e o schema `storage` foram simulados.** O comportamento real
   sob GoTrue e storage-api não foi exercitado. Nenhum teste do recorte
   depende do conteúdo real desses serviços, mas a afirmação "aplica no
   remoto" **não** decorre desta prova.
4. **RLS sob PostgREST real não foi exercitada.** As fixtures foram inseridas
   como `supabase_admin` (superusuário, que ignora RLS) e as chamadas de RPC
   foram feitas com `set local role authenticated` + `request.jwt.claim.sub`.
   Isso valida a autorização feita **dentro** das funções `security definer`,
   não o caminho completo de policies via API.
5. **Nenhuma verificação de concorrência real.** O conflito de versão foi
   provado com uma versão esperada desatualizada em chamada serial, não com
   duas transações concorrentes disputando o mesmo `for update`.
6. **Nada foi verificado no cliente Flutter.** A tela do Acontece, o botão de
   retirada, o estado de UI e o consumo de `can_withdraw` ficam fora desta
   prova.
7. **Nada foi verificado no ambiente remoto.** Supabase e Cloudflare de
   produção não foram tocados, e esta prova não autoriza aplicação remota.

## Encerramento

O container `coelo-l01-probe` foi removido (`docker rm -f coelo-l01-probe`).
Nenhum volume nomeado, rede ou imagem adicional foi criado. Nenhum arquivo da
worktree foi modificado além deste relatório.
