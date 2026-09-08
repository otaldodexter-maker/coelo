---
title: LOC — preparação nominal e bloqueadores antes de 31000
source:
  - Reserva central LOC94701e7b e autorização do root para esta evidência
  - "Git 94701e7bf10388698312410d8573e7874bb70cb4"
  - "Git fbef1b92cf5cc9ba735f78c0057d6d853cd736ea"
  - Manifesto foundation-migrations.sha256 e seleção Auth45 da worktree e1-replay-harness
  - Documentação oficial PostgreSQL 17 — GRANT
status: diagnóstico inicial preservado; probe Auth47 observado e perfil LOC50 em preparação autorizada
generated: 2026-09-08
generated_at_utc: 2026-09-08T03:34:02Z
updated_at_utc: 2026-09-08T04:20:00Z
scope: diagnóstico nominal local, sem alteração de SQL, Git ou Docker
---

# LOC — preparação nominal e bloqueadores

A análise confirma a closure estática **Auth45 + migration 235500 + dois preflights = base de 48 arquivos**. Acrescentar um bootstrap local nominal separado, antes do candidato, e a migration `20260908031000` resulta na proposta de **50 entradas**, com target `20260908031000`. A preparação permanece bloqueada pela incompatibilidade de ACL prevista em PostgreSQL 17 e pelo encaixe ainda não definido do bootstrap.

Esta evidência registra leitura de arquivos e objetos Git e consulta à documentação oficial. **Não registra execução SQL, Docker, pgTAP ou falha runtime LOC.** Os objetos do candidato foram lidos diretamente do Git, sem materialização por este agente. A análise inicial autorizou somente este Markdown; a exceção posterior para preparar a fixture ACL local está registrada ao final. O root faz a revisão e eventual commit.

## 1. Bloqueador estático: MAINTAIN na ACL reconstruída em PostgreSQL 17

A configuração canônica [supabase/config.toml](../../../../../packages/coelo_database/supabase/config.toml), linha 42 na leitura, define `major_version = 17`.

A migration selecionada [20260811192514_activity_management_security.sql](../../../../../packages/coelo_database/migrations/20260811192514_activity_management_security.sql), linhas 398–406, inclui `activity_locations` no laço que executa `GRANT ALL ON TABLE ... TO service_role`. Em PostgreSQL 17, `MAINTAIN` integra os privilégios de tabela concedidos por `ALL`. A [documentação oficial PostgreSQL 17 — GRANT](https://www.postgresql.org/docs/17/sql-grant.html) enumera esse privilégio e define ALL como todos os privilégios disponíveis para o tipo de objeto.

O candidato `94701e7b:packages/coelo_database/migrations/20260908031000_superadmin_location_catalog_v2.sql`, linhas 68–75, compara a ACL não proprietária com um vetor exato. Esse vetor inclui SELECT de authenticated e sete privilégios de service_role, mas **omite `service_role:MAINTAIN:false`**. A consulta não filtra MAINTAIN. Na seleção Auth45 + 235500 não foi encontrada revogação posterior desse privilégio ou reconstrução da ACL de activity_locations que o retire.

**Inferência estática:** se os gates anteriores de catálogo passarem, o replay da base selecionada em PostgreSQL 17 deverá parar no preflight do candidato com `location table ACL drift`, antes da verificação dos fingerprints das funções, do gate de capabilities e do pgTAP. Não foi observado esse erro em banco durante esta análise; o primeiro bloqueio runtime pode ser anterior.

**Decisão necessária:** devolver a incompatibilidade à frente LOC e ao coordenador para revisão nominal do contrato ou aceitação explícita de um RED esperado. Este relatório **não autoriza revogar MAINTAIN no bootstrap, afrouxar a comparação de ACL, alterar a base histórica, trocar o pin do candidato ou inserir reparo oculto**. Qualquer novo candidato deve receber identidade e hash próprios.

## 2. Bloqueador estático: o bootstrap existente não é uma entrada válida do replay atual

A fixture commitada `tests/fixtures/location_catalog_v2_capability_bootstrap.sql` tem 30 linhas e é idêntica nos commits fbef e 947:

- Linhas 5–17: transação, exigência de current_user postgres e opt-in `coelo.local_replay = 'location-catalog-v2'` na mesma conexão; ausência das duas capabilities e presença de Owner ativo.
- Linhas 18–25: INSERT de `locations.read` e `locations.create` com todos os labels explícitos.
- Linhas 26–29: INSERT dos vínculos allow ativos para Owner.
- Linha 30: COMMIT próprio.

A fixture **exige, mas não executa**, o SET de opt-in. Seu nome não tem versão de 14 dígitos. Não cria People, instituição, unidade, catálogo de locais ou grants SQL; ela provisiona exclusivamente a matriz nominal das duas capabilities para o replay local.

No runner atual:

- [Prepare-SafeMigrationReplay.ps1](../../../../../packages/coelo_database/scripts/Prepare-SafeMigrationReplay.ps1), linhas 214–245 na leitura, aceita exatamente as duas preflights herdadas e exige nomes versionados e versões únicas; linhas 317–319 verificam a contagem gerada.
- [Invoke-SafeLocalMigrationReplay.ps1](../../../../../packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1), linhas 278–282, prepara os arquivos antes do start; linhas 313–321 copiam as migrations validadas e executam um único `db reset --local --no-seed --version $TargetVersion`; linhas 322–324 executam os TestPaths somente depois.

Consequentemente, somente acrescentar um seletor, copiar a fixture ou usar TestPath não faz o bootstrap preceder 31000. A fixture posterior ao reset não atende ao contrato de pré-requisito e foi explicitamente excluída da reserva central.

### Proposta mínima, ainda sem nome, path ou hash aprovado

Reservar e revisar **um novo bootstrap local versionado e commitado separadamente**, específico do perfil LOC, para a posição imediatamente anterior a 31000. **Nome do perfil, nome do SQL, timestamp e paths de autoria devem ser definidos somente após decisão nominal do coordenador/root. Nenhum desses valores é inventado ou reservado por este documento.**

O novo artefato deve ter proveniência explícita na fixture fbef, opt-in local explícito dentro da própria transação, verificação de catálogo vazio e matriz nominal limpa, e somente o provisionamento aprovado das duas capabilities e vínculos Owner. Deve preservar os labels explícitos, os guards de identidade e o escopo local. Não deve alterar grants, ACL, constraints, defaults, ownership ou funções da base para fazer o candidato passar.

O novo bootstrap não é uma migration de produção e não deve ser acrescentado ao manifesto Foundation nem às duas preflights históricas. Sua inclusão deve ser uma entrada própria do perfil fechado LOC, fixada por nome e hash, validada antes de staging/start e copiada sem transformação. O descriptor deve exigir essa entrada imediatamente antes da canônica 31000, contar 50 entradas e rejeitar seleção sem bootstrap, bootstrap duplicado, ordem indevida, path/reparse/hash divergente ou mistura com AuthOnly/FoundationOnly/AdditionalMigration.

A integração pode preservar o reset único e o fluxo de mutex/cleanup existentes. Exigirá suporte restrito à terceira categoria de entrada local do perfil LOC; **não** um terceiro preflight genérico, append de SQL em runtime, extração de helper ou execução de fixture após reset. A fixture fbef e o candidato 947 permanecem preservados. O novo bootstrap somente ganhará hash após autoria e revisão nominais.

## Closure, ordem e limites

O manifesto [foundation-migrations.sha256](../../../../../packages/coelo_database/replay/foundation-migrations.sha256) contém 67 entradas, mas a base usada nesta proposta é a **seleção Auth45**, definida por versões até `20260812001975` e as quatro versões nominais `20260827214000`, `20260827233000`, `20260901124500` e `20260901200206`. O hash normalizado do manifesto é:

`4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59`

Foi acrescentada somente a canônica [20260827235500_superadmin_internal_institution_list_filter.sql](../../../../../packages/coelo_database/migrations/20260827235500_superadmin_internal_institution_list_filter.sql). Seus próprios pré-requisitos — Auth interno e institution_directory — estão presentes na base selecionada. A função definida nas linhas 20–55 preserva `SAI_INVALID_ARGUMENT` e `SAI_CONCURRENT_CHANGE`, que o helper Auth original não preserva; nenhum helper foi extraído ou reaplicado.

| Ordem combinada | Conteúdo | Papel |
|---|---|---|
| 1–45 | Entradas Auth selecionadas, incluindo preflights nas posições 29 e 42 | Base herdada |
| 46 | 20260827235500_superadmin_internal_institution_list_filter.sql | Única adição canônica histórica |
| 47 | 20260901124500_harden_superadmin_auth_context_denial_audit.sql | Auth herdado |
| 48 | 20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql | Última entrada da base 48 |
| 49 proposta | Novo bootstrap local nominal separado; identidade ainda a definir | Antes do candidato, dentro do replay |
| 50 proposta | 20260908031000_superadmin_location_catalog_v2.sql | Última canônica e target 20260908031000 |

Contagens: base **46 canônicas + 2 preflights = 48**; proposta completa **47 canônicas + 2 preflights + 1 bootstrap local = 50**. Os três TestPaths e o script de checagem estática não entram nessa contagem.

A leitura encontrou em Auth45 as definições requeridas de activity_locations e dos sete helpers/wrappers legados. A tabela nasce em 192514; o diretório privado e o wrapper público de options em 193838; o criador legado privado/público em 194840; o payload, options privado e wrapper público do diretório recebem suas últimas definições selecionadas em 200614. O preflight 151253 revoga EXECUTE default antes dessas definições, compatível com os guards de ACL privada. Nenhuma adição Activities v2 ou Foundation67 foi necessária para essa closure estática.

O candidato conserva seu preflight estrito: catálogo vazio sob ACCESS EXCLUSIVE, dez colunas, oito constraints, quatro índices, owner postgres, RLS ENABLE/FORCE, policy e ACL exatas, sete fingerprints/ACL de funções, matriz Owner das duas capabilities, envelope correto e ausência dos novos objetos. **Essa leitura não prova os MD5 produzidos por pg_get_functiondef, a equivalência efetiva do catálogo reconstruído nem o sucesso dos testes.** São gates runtime pendentes. As correções de CASE parentetizado, READ COMMITTED, reautorização pós-advisory-wait e expiração por clock_timestamp pertencem à revisão nominal informada pela central; esta análise não reabre nem amplia essa auditoria.

## Proveniência e hashes

Os hashes LF/CRLF abaixo são SHA256 de texto UTF-8 sem BOM; CRLF normaliza todas as quebras de linha para CRLF. Blobs são os IDs dos objetos Git originais. A base selecionada foi conferida contra os pins normalizados do manifesto; **46/46 canônicas e 2/2 preflights coincidiram**.

- Candidato completo: `94701e7bf10388698312410d8573e7874bb70cb4` — fix(locations): reauthorize after waits and enforce session expiry.
- Fixture ancestral completa: `fbef1b92cf5cc9ba735f78c0057d6d853cd736ea` — test(locations): keep TAP assertions outside application role.
- Relação: fbef é ancestral de 947, confirmada por leitura Git.
- A fixture normal e o bootstrap são idênticos nos dois commits. A authorization final mudou em 947; a isolation não existe em fbef. Para o futuro replay nominal, selecionar **as três suítes do snapshot 947**, usando fbef como proveniência histórica.

Todos os caminhos desta tabela são relativos a `packages/coelo_database/` no commit indicado.

| Artefato | Snapshot / blob | SHA256 LF | SHA256 CRLF | Bytes LF / linhas |
|---|---|---|---|---|
| migrations/20260908031000_superadmin_location_catalog_v2.sql | 947 / 5f857f4a172a5ed3f537cdffded304e583ca25cf | 6871fba98001d37154cc7ba76b896ebc67fd93ccca6eb18baaa2c17cba1ac652 | 62d76eead08a107946b62602314ecff8f3baba2609ba88deeda93bffb487f2d0 | 36204 / 556 |
| tests/fixtures/location_catalog_v2_capability_bootstrap.sql | 947 e fbef / b811809655d8081175965b3120ade41f8af7f0b3 | 3dd0bf5c11e52a68102e3e707e48835eb676513c235daab5defcdb1e7ad24bfb | 4b0c56f6fdb15c28d19bb1392bf89060a3c67a5ba9e17724350de5976e61ecb2 | 1644 / 30 |
| supabase/tests/superadmin_location_catalog_v2_test.sql | 947 e fbef / f2c553069267fb8d7ba3429f42a4b5dccc3ad42d | 8544baf69438ea3bcacf932abbe1ab3c63b2bf5df9ecfc8802f89e6f7adace80 | 550ddb956e1ac83a4a2f6dc91626dde613e8441dcfc96bf17e1c454659853fb6 | 6186 / 96 |
| supabase/tests/superadmin_location_catalog_v2_authorization_test.sql | 947 / 3545f95b144fe776ebc8af5955ad8cf375c5fcf0 | d128f55ee7aca227e52fdbddf20adfb3948106c43472cc5423d49cdc2e063e52 | f6e3b911c41b5bc416bf82c03c9961ef5b869a76efc01baa425ab4afcac25f37 | 15614 / 233 |
| supabase/tests/superadmin_location_catalog_v2_isolation_test.sql | 947 / da197d2a1fad24737f46e740cb17f3ab4e6ea127 | b27d173a531559350f90e62a174492240606bfc96e70dc30a3fcb5563f8dc4ab | 85f9aaa937ad71b738d08a947efd04e000678a3ebbfaffea993116535c690ede | 3650 / 51 |
| scripts/tests/Test-LocationCatalogCandidate.Tests.ps1 | 947 / aad0e3b48d8c42413a8b64c194db3a98d7d064be | 365d55e54e729e3b0c783e3c5938e09a7779a96a122721545da33a3bf6350d8b | fb2736e72280ee9befbef52707b7807ab60432286ac539d32963da66a904bf81 | 4693 / 70 |
| supabase/tests/superadmin_location_catalog_v2_authorization_test.sql — histórico | fbef / ef8507b820374a2ff5fa70b5662705d0d95f940b | 9bf206d35f8b7ebb78bc302ba3acb19aa548f55ff814ad73ae3bc6849936abc3 | e8f26f8c1365b42bfa88b6fc299ad5d01be92649ecead589e51c693378efd48a | 13436 / 200 |
| scripts/tests/Test-LocationCatalogCandidate.Tests.ps1 — histórico | fbef / 547c877ca7fc1f30ef14b01372977d69fd7e435f | 4ef3f2c034f24f8ef009708dcca201eaa729fd0efc0a7f1671df5b945b9217d1 | 7c40a3cf06c3e11206f8b08d4b0cb2ba31a82c151b60d0813febf54d86a2fe34 | 3812 / 58 |

A dependência 235500 tem blob `5de7d5f42da56999f92b5af8ae1d2cf13b6873eb` na árvore 947 e SHA256 CRLF `c4496229e2d004907b1c878e9719cadfa60169307eeb92be67cd76c3ad5551aa`.

## Fontes canônicas do contrato

Os links abaixo apontam aos paths canônicos do repositório. Para esta análise, a autoridade é a versão fixada no commit **94701e7bf10388698312410d8573e7874bb70cb4**, lida pelo objeto Git; um arquivo de outra revisão da worktree não substitui esse pin.

| Fonte | Blob em 947 | SHA256 LF | SHA256 CRLF |
|---|---|---|---|
| [Contrato local LOC](../../../../../docs/superpowers/specs/2026-09-07-location-catalog-v2-local-contract.md), especialmente linhas 121–147 | 1237dc57a3b1b992137cde5bee58711d405fa0d6 | efbe994ff9265a288de9900042feec4a11fc17fd051d2d3ba96a94abda4d5547 | 119443561ff8a3b6d70f898889e2a7f34db7fe0d0f9300b46e28e0c20811b9cc |
| [Evidência candidata LOC](../../../../../docs/reviews/evidence/etapa-2/estruturas/2026-09-07-location-catalog-candidate.md) | f2704f24fd957ecdc7ac274d1b20763c59fdb2e4 | 0c923f1ed97817036ca84514399a7d11b47741d2e7ded966bf5e6903f43bbf99 | 6238bf04f311c8c8a566dcdf706875c9456d2b06fda9b8caa6674c5af704350e |
| [Plano nominal de revalidação após espera](../../../../../docs/superpowers/plans/2026-09-07-location-lock-revalidation-replay.md) | 72bcbfd891c6aee95ee200837c5170149df6ab75 | 89082228346d1eced239e40d27e99fef6df0b999f2dec6fd3976ced13e3862c1 | 18e22de103d347ef42ea213f8a7f90490cdb55ff64f656d2afa8927d1c72c469 |

A especificação exige bootstrap antes do candidato, postgres e opt-in na mesma conexão; rejeita provisionamento de produção implícito. O plano de concorrência é fonte histórica relacionada; esta evidência não autoriza sua execução nem afirma prova de duas conexões.

## Manifesto efetivo da base 48

A tabela reproduz a seleção e os hashes verificados, sem alterar o manifesto Foundation. As posições são da ordem combinada por nome. Os dois preflights mantêm identidade, conteúdo e posição herdados.

| Posição | Arquivo | Categoria | SHA256 CRLF |
|---|---|---|---|
| 1 | [20260623191021_superadmin_foundation_v1.sql](../../../../../packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql) | canônica | 1ec51807d2a1f0bbd5cdf7ad11c7ec6d3089cd613319a5954f4d912f45c4edf3 |
| 2 | [20260623203230_schema_boundaries_catalog_v1.sql](../../../../../packages/coelo_database/migrations/20260623203230_schema_boundaries_catalog_v1.sql) | canônica | a8985d8a1fd005c9de23ea08c8da916703c908dc891141599445bf3d0f86d1be |
| 3 | [20260717151609_institution_directory_foundation.sql](../../../../../packages/coelo_database/migrations/20260717151609_institution_directory_foundation.sql) | canônica | c64e43c80f5994f99e66455f5a0572d18d99ecf7731eedfaebb423619ff849f5 |
| 4 | [20260720103023_institution_contact_directory_refinement.sql](../../../../../packages/coelo_database/migrations/20260720103023_institution_contact_directory_refinement.sql) | canônica | 971f61cdcdbba5fcb077d323d823b76ba7d3c7b56fc3f1da97fc9eebef993716 |
| 5 | [20260720180000_people_context_foundation.sql](../../../../../packages/coelo_database/migrations/20260720180000_people_context_foundation.sql) | canônica | b2d6ee36c1b75961c057230ff8879bb7979ce417aab0d9662f028c22471b300d |
| 6 | [20260720190000_people_context_advisor_hardening.sql](../../../../../packages/coelo_database/migrations/20260720190000_people_context_advisor_hardening.sql) | canônica | 916696126dddd0b64aa4d8fcf484c8fe26b7191c48f990e7c51a5cdbbcdf893a |
| 7 | [20260724120307_contextual_activities_foundation.sql](../../../../../packages/coelo_database/migrations/20260724120307_contextual_activities_foundation.sql) | canônica | 6625f904248ab5a36e7d665616bd5b2cab74dd31279442e0493968ea08eb5fd9 |
| 8 | [20260724122545_contextual_activities_fk_index_hardening.sql](../../../../../packages/coelo_database/migrations/20260724122545_contextual_activities_fk_index_hardening.sql) | canônica | fecec02870b5462b49001afbe5aea737ae439bef76d493ee339bf78cf3747771 |
| 9 | [20260724152628_contextual_authorization_core.sql](../../../../../packages/coelo_database/migrations/20260724152628_contextual_authorization_core.sql) | canônica | bcdc37b5ceda56ecbe3d71f9c30a59f3d48c1a878519da45ca37c2245d467795 |
| 10 | [20260724152707_family_authorizations_and_transfers.sql](../../../../../packages/coelo_database/migrations/20260724152707_family_authorizations_and_transfers.sql) | canônica | 36168d2c22d9d2d08c433d26fc9e10164f6cc3da8b38bdc916ec443655040f8f |
| 11 | [20260724152713_activity_governance_and_participation.sql](../../../../../packages/coelo_database/migrations/20260724152713_activity_governance_and_participation.sql) | canônica | 29d3682bfe4875557ad3c2b1a69d1dc92d076a46a709f8f161bcede2d8fead6c |
| 12 | [20260724152722_contextual_chat_foundation.sql](../../../../../packages/coelo_database/migrations/20260724152722_contextual_chat_foundation.sql) | canônica | d85b1b1efa3a2690800cb0ee2e1f77509b45b76a67152e1d20dfa3c36908a117 |
| 13 | [20260724152731_attendance_assiduity_foundation.sql](../../../../../packages/coelo_database/migrations/20260724152731_attendance_assiduity_foundation.sql) | canônica | d8f99e587330eb4ec8f30525097a25667cc593b0cb03722dc89b1cdf47269ae6 |
| 14 | [20260724161334_contextual_domains_compatibility_hardening.sql](../../../../../packages/coelo_database/migrations/20260724161334_contextual_domains_compatibility_hardening.sql) | canônica | 9d73e2abf73c76fd1c20573d8423b297e885ce670570604f65ec6905cae0b4e7 |
| 15 | [20260724161706_contextual_domains_advisor_hardening.sql](../../../../../packages/coelo_database/migrations/20260724161706_contextual_domains_advisor_hardening.sql) | canônica | 5621569f754a28c855386bf8a346a02e2d51fbc49feb4f75558944444102421d |
| 16 | [20260724162210_contextual_chat_lifecycle_hardening.sql](../../../../../packages/coelo_database/migrations/20260724162210_contextual_chat_lifecycle_hardening.sql) | canônica | a8f8ac522d74c0b31eba89f1121a279243c27a457eb97a394832a89548cad39b |
| 17 | [20260724162604_contextual_chat_trigger_hardening.sql](../../../../../packages/coelo_database/migrations/20260724162604_contextual_chat_trigger_hardening.sql) | canônica | ef7e97f92e628a5c91157bb8cdc9dae17576c39ff61df944996e42dee960733b |
| 18 | [20260724162900_contextual_chat_audit_schema_hardening.sql](../../../../../packages/coelo_database/migrations/20260724162900_contextual_chat_audit_schema_hardening.sql) | canônica | 80ae137c545d21cf63c3a5fa3fd11a870a59a021dc59337b2dba283553419549 |
| 19 | [20260727130433_remediate_schema_column_catalog_completeness.sql](../../../../../packages/coelo_database/migrations/20260727130433_remediate_schema_column_catalog_completeness.sql) | canônica | ffa67d796d7586b2fce8ff7682ac6349b35976f0509cdce88001dce0eb925606 |
| 20 | [20260728172333_institution_profile_and_legal_representatives.sql](../../../../../packages/coelo_database/migrations/20260728172333_institution_profile_and_legal_representatives.sql) | canônica | 6be5f3ebb001d9f1c24aac650a9762a10cafda099300127062df629323f69f68 |
| 21 | [20260728203000_cover_institution_legal_representative_membership_fk.sql](../../../../../packages/coelo_database/migrations/20260728203000_cover_institution_legal_representative_membership_fk.sql) | canônica | f14e603ccbdcba05fbb7f1d9df53b536361b7b0e58693e0baba6e7e13427f8f9 |
| 22 | [20260729140915_unit_type_plan_foundation.sql](../../../../../packages/coelo_database/migrations/20260729140915_unit_type_plan_foundation.sql) | canônica | 71673526884c563a3e44fc1f72ff99b33534f680ec1ac8681f82d58572c4519e |
| 23 | [20260729141839_superadmin_people_directory.sql](../../../../../packages/coelo_database/migrations/20260729141839_superadmin_people_directory.sql) | canônica | 20cce28127774f1403280de351620b255590e60f4e842d2da22fd897f6fb85bf |
| 24 | [20260729144440_profiles_permissions_governance.sql](../../../../../packages/coelo_database/migrations/20260729144440_profiles_permissions_governance.sql) | canônica | d0e87f73c841c338c7df7553f2c91e91f7287da481b70501e0f9334fadce385e |
| 25 | [20260729153000_superadmin_people_directory_policy_hardening.sql](../../../../../packages/coelo_database/migrations/20260729153000_superadmin_people_directory_policy_hardening.sql) | canônica | b938d5ac0399a7137dc764a48baaff32776c466c3c8259d0b170778b528c40cd |
| 26 | [20260729153100_child_context_lifecycle_trigger_hardening.sql](../../../../../packages/coelo_database/migrations/20260729153100_child_context_lifecycle_trigger_hardening.sql) | canônica | 0b16d82755171a1ae26059455b8718162c390a54bac7c1d81107ddcefc3e6065 |
| 27 | [20260804205732_access_profile_permission_matrix_metadata.sql](../../../../../packages/coelo_database/migrations/20260804205732_access_profile_permission_matrix_metadata.sql) | canônica | 60992879e5f04eebc3d368742b97be7423b80f26ad73c6c3fcc1819a4a59f07f |
| 28 | [20260811125345_institution_management_commands.sql](../../../../../packages/coelo_database/migrations/20260811125345_institution_management_commands.sql) | canônica | 10d8bbbbcc8222f62c2e07e07b0886e1a85b54a6b4dd815965f1218d93417321 |
| 29 | [20260811151253_assert_function_execute_preflight.sql](../../../../../packages/coelo_database/replay/20260811151253_assert_function_execute_preflight.sql) | preflight | 718c2de052e9df29abc42642806d9a5e4d98c8964665453de6f14f0f8b61ab75 |
| 30 | [20260811151254_group_management_security.sql](../../../../../packages/coelo_database/migrations/20260811151254_group_management_security.sql) | canônica | 8666c997a8a04e13a404c20f46bfbcaae0cb12b8b5dbb64623fbfff4cfcd993f |
| 31 | [20260811192514_activity_management_security.sql](../../../../../packages/coelo_database/migrations/20260811192514_activity_management_security.sql) | canônica | dcb4b5f0781af2f3b0bb1b6a9b63d79a00549e371b7ca0feb0ac5be5bd3820f4 |
| 32 | [20260811193838_activity_management_commands.sql](../../../../../packages/coelo_database/migrations/20260811193838_activity_management_commands.sql) | canônica | 77fdae731eb56df04bd45f3b8f854495a422bb3230802b5bc4855840f436813b |
| 33 | [20260811194624_activity_aggregate_commands.sql](../../../../../packages/coelo_database/migrations/20260811194624_activity_aggregate_commands.sql) | canônica | d28c0c7dae5947806c4d2c300a14259cdc997dfb0c85e40c2e0d192bc70b15ba |
| 34 | [20260811194840_activity_files_identity_commands.sql](../../../../../packages/coelo_database/migrations/20260811194840_activity_files_identity_commands.sql) | canônica | 3ab6f64f3f2d00fb6ff99fa6f1f3c929753bcf29f5b6506f62c95b50107474e9 |
| 35 | [20260811195042_activity_file_workers.sql](../../../../../packages/coelo_database/migrations/20260811195042_activity_file_workers.sql) | canônica | b33bdaf0db753fc7dc35f3e6da2a5305a789dea571c1b1f5ec9c12929ddfadd8 |
| 36 | [20260811195429_activity_management_hardening.sql](../../../../../packages/coelo_database/migrations/20260811195429_activity_management_hardening.sql) | canônica | b0ee2c41376bd482cead99931a3fdd1f4ac70327c2615b4a1b879640f32819ba |
| 37 | [20260811200614_activity_read_model_contract_hardening.sql](../../../../../packages/coelo_database/migrations/20260811200614_activity_read_model_contract_hardening.sql) | canônica | 9e99d589ec89975110d3fcaef8c363701bd255b00072b99a4797a923458cea26 |
| 38 | [20260811201830_activity_file_job_authorization.sql](../../../../../packages/coelo_database/migrations/20260811201830_activity_file_job_authorization.sql) | canônica | acfec92c0f1c2907591e76a7bc94b411e7b677013d14abd3dfa5c5c8587b8a74 |
| 39 | [20260811201945_activity_template_commands_hardening.sql](../../../../../packages/coelo_database/migrations/20260811201945_activity_template_commands_hardening.sql) | canônica | 2c844d87a79a3808df1e67a256481a8794fac737f4d3b609aea4a85b3528987f |
| 40 | [20260811202030_activity_options_minimization.sql](../../../../../packages/coelo_database/migrations/20260811202030_activity_options_minimization.sql) | canônica | 540e02eb1217d1b177efbd9a52b610ff698268892c2ca540d476cd719dd8079a |
| 41 | [20260811215451_access_profile_management_v2.sql](../../../../../packages/coelo_database/migrations/20260811215451_access_profile_management_v2.sql) | canônica | 04c1bedd194b812ea753243dd95e400d39e0257f985506a8b703e68329d90208 |
| 42 | [20260811215452_access_profile_labels_replay_bridge.sql](../../../../../packages/coelo_database/replay/20260811215452_access_profile_labels_replay_bridge.sql) | preflight | d97e02796fcd5897707b5657b7a1c1df690f831e09ed98df6ed21886f75f9ef3 |
| 43 | [20260812000847_audit_production.sql](../../../../../packages/coelo_database/migrations/20260812000847_audit_production.sql) | canônica | 5f5047292c7ed7bbd0f87c5f164628ee50ac211f481e018968469f0b3ad13d0e |
| 44 | [20260827214000_harden_default_function_execute_privileges.sql](../../../../../packages/coelo_database/migrations/20260827214000_harden_default_function_execute_privileges.sql) | canônica | fe77ad1daa41477ceb15a91d8080a866b8a23ed470e585c5685f575123bfd5ff |
| 45 | [20260827233000_superadmin_internal_auth_context.sql](../../../../../packages/coelo_database/migrations/20260827233000_superadmin_internal_auth_context.sql) | canônica | 87d03cd1e75d9859438c82abbf3c59424680bdd64b57741f10740a5ac7007a33 |
| 46 | [20260827235500_superadmin_internal_institution_list_filter.sql](../../../../../packages/coelo_database/migrations/20260827235500_superadmin_internal_institution_list_filter.sql) | canônica | c4496229e2d004907b1c878e9719cadfa60169307eeb92be67cd76c3ad5551aa |
| 47 | [20260901124500_harden_superadmin_auth_context_denial_audit.sql](../../../../../packages/coelo_database/migrations/20260901124500_harden_superadmin_auth_context_denial_audit.sql) | canônica | f7a9f92cf0a3a9980f1cd861807a138c012d25977bf08b0e1165bb7db60ee1df |
| 48 | [20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql](../../../../../packages/coelo_database/migrations/20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql) | canônica | 7e5fa210ff9a0e998c416d7b01a60a14103a5c3d2c539881f49889c0fd618c45 |

## Probe ACL local autorizado e preparado — ainda não observado

Em 2026-09-08, o coordenador autorizou um probe nominal local separado, a ser revisado e executado **somente pelo root, após os gates da fila FRead**. A base é **AuthOnly47: 45 canônicas Auth + dois preflights**, target `20260901200206`. Esse probe não seleciona 235500, 31000 ou bootstrap e não altera a proposta LOC50 nem libera sua execução. A ampliação central posterior autoriza exatamente duas fixtures no mesmo replay/reset Auth47: este probe LOC de três assertions primeiro e a fixture Perfis plan8 nominal depois. A materialização e os pins da fixture Perfis pertencem ao root; este agente não a altera.

A fixture própria [location_catalog_legacy_acl_probe_test.sql](../../../../../packages/coelo_database/supabase/tests/location_catalog_legacy_acl_probe_test.sql) está preparada, com `BEGIN`, `RESET ROLE`, criação condicional da extensão pgTAP, `plan(3)`, `finish()` e `ROLLBACK`. As três assertions verificam somente postgres, PostgreSQL 17 e existência de activity_locations. O primeiro diagnóstico JSON informa current_user, server_version_num e a ACL não proprietária, ordenada por grantee, privilege_type e is_grantable, obtida de pg_class/aclexplode/acldefault com LEFT JOIN em pg_roles. A consulta usa to_regclass para não abortar o diagnóstico se a tabela estiver ausente.

Um segundo diagnóstico JSON, sem novas assertions, lista somente pg_proc para public.superadmin_access_profiles_list e app_private.superadmin_access_profiles_cursor: schema, nome, identity_arguments, owner, prosecdef, proconfig, has_function_privilege de authenticated para EXECUTE e ACL de PUBLIC. As linhas são ordenadas por schema, nome e assinatura, com os privilégios PUBLIC também ordenados. A consulta não executa nenhuma das funções de aplicação nem prova seu resultado; seu catálogo deve ser observado antes da fixture Perfis plan8. O plano permanece três, sem assertion de MAINTAIN ou de ACL esperada.

**Não há assertion exigindo MAINTAIN nem comparação com a ACL do candidato.** O probe não contém helpers, grants, INSERTs ou reparo de privilégios. Sua finalidade é observar objetivamente a ACL da base reconstruída e confirmar ou refutar a inferência estática do bloqueador 1.

- SHA256 LF: `6080226e79568ae3e7152fc4dfa8bda18e1e9f0996763c4b155bc3365650cd35`.
- SHA256 CRLF normalizado: `6a6d5ed1fff66a5b417170c361e8ef977ad773e9fab220a8b37e9d0596d39a54`.
- Estado desta entrega: arquivo preparado e conferido estaticamente; **SQL/Docker não executados; nenhum TAP ou diagnóstico ACL observado**.
- Autorização de escrita excepcional: somente essa fixture e a atualização desta evidência quanto à preparação/autorização do probe. O root revisa o snapshot antes da execução serializada.

## Gate de memória e devolução

Não houve mudança aprovada de regra de produto, domínio ou permissão de produção. O conhecimento registrado é a proveniência técnica e o estado bloqueado desta preparação; não se criou projeção adicional em docs/knowledge. Além deste Markdown, foi criada somente a fixture diagnóstica expressamente autorizada acima. Nenhum tracker, migration, bootstrap, script, descriptor, Git ou recurso Docker foi alterado por esta entrega.

O root recebe este arquivo para revisão. Autoria e integração do perfil/bootstrap exigem reserva nominal posterior. A execução do pacote LOC50 continua bloqueada; a autorização posterior limita-se ao probe AuthOnly47 pelo root após seus gates.

## Atualização pelo operador — probe real e preparação revisada

Em 2026-09-08, o root executou o pacote nominal Auth47 com LOC3 e Perfis8. O relatório [auth47-loc-profiles-probe-2026-09-08.md](auth47-loc-profiles-probe-2026-09-08.md) e o catálogo JSON correspondente foram commitados em **46a6077a4c8d9dc9a06c6643b03c80c7a21f3a97**. O PostgreSQL real foi **17.6, server_version_num170006**, current_user postgres. LOC3 passou nas três pré-condições; o diagnóstico apresentou nove ACLs não proprietárias. A comparação independente com947 encontrou exclusivamente **service_role:MAINTAIN:false** adicional e nenhuma entrada faltante. Essas três assertions não certificam a ACL candidata ou o contrato LOC.

A execução começou em03:48:17.3708297Z, com identidade **coelo_safe_c3e8951894af4fb198f46b7bba357**; marker lido, limpeza confirmada em03:50:56.8629214Z, sem recursos próprios remanescentes e com o staging histórico preservado. Perfis emitiu oito assertions: três pré-condições PASS e cinco FAIL decorrentes do primeiro gate ACL42501; a evidência detalhada permanece no relatório nominal. Nenhuma migration235500,31000 ou bootstrap LOC foi aplicada nessa prova.

Com essa observação, a frente publicou **98d166d25d18d1d0b615e244ba8af7e93f11420e**, cujo único delta SQL em relação a947 adiciona MAINTAIN ao vetor exato. O root confirmou esse diff por Git. SHA-256 bruto LF do novo candidato: **7c7ca4da2aa4eece06f386aee9ada7c52db69eecd996bca18ed434a922f90538**. A coordenação aprovou a revisão para preparação nominal; o catálogo ainda será testado em runtime pelo futuro pacote50.

O bootstrap derivado foi publicado separadamente em **115df2ca35b04e4b8f48aecb1d2a46929bd19949**, path **packages/coelo_database/tests/fixtures/20260908030959_location_catalog_v2_capability_bootstrap_local.sql**, blob **43adedc3a6149c5c2d42bfcec2fe7f74c8286ed5**, SHA LF **d46583bc936dfb284b5d05bdba8dea8f965d31a0f899164bfdd8a8c6bd6d2471**, CRLF **7d7ae81d7adc7d4d998e7b7f6ffaa7f1d16f463b106bb68b804e01caa0bf5bdc**. A revisão independente confirmou a fonte literal b811809655d8081175965b3120ade41f8af7f0b3 acrescida de uma única linha de54bytes LF: set local coelo.local_replay = 'location-catalog-v2';, depois de BEGIN e antes de DO. COMMIT encerra esse GUC local; os guards e INSERTs restantes são preservados.

A preparação em curso usa o seletor específico **LocationCatalogV2**, com **47 canônicas + 2 preflights + 1 bootstrap local = 50**. A entrada bootstrap é uma categoria separada, posição49, imediatamente antes do candidato31000 na posição50. Não se altera a fronteira AdditionalMigration nem a regra de exatamente dois preflights. Pins de origem/derivado, delta literal e ancestrais sem reparse serão validados antes da cópia. **LOC50 ainda não foi executado** e depende de testes do harness, revisão e gate central próprios. O relato estático anterior permanece como histórico; as duas decisões necessárias foram respondidas por esses pacotes, sem converter a preparação em prova SQL.
