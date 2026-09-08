---
source:
  - "Coordenador Etapa 2: autorização nominal de preparação documental F-AUTHOR01 em 2026-09-08"
  - "packages/coelo_database/replay/foundation-migrations.sha256 e seleção Auth45 existente"
  - "SQL canônico Forms e candidato 2aa27b2553ae7ee145690211b1006f983ba482df"
  - "Snapshots históricos alternativos pinados pelo Coordenador; proveniência detalhada neste documento"
  - "https://github.com/citusdata/pg_cron#extension-settings"
status: proposta_nominal_para_revisao_sem_autorizacao_de_execucao
generated_at: "2026-09-08"
scope: "F-AUTHOR01: closure local, fontes, materialização mínima e gates de runtime"
execution_performed: false
---

Esta proposta fecha **64 entradas: 59 fontes canônicas + 3 snapshots históricos alternativos + 2 preflights existentes**, com 64 nomes e versões únicos, ordem cronológica e alvo único **20260908030000**. As 59 fontes canônicas são Auth45 + 12 Forms + envelope235500 + candidato030000. “Canônica candidata” identifica a migration do pacote aprovado para preparação; não significa aplicação local, restauração ou publicação remota.

O recorte inclui dependências efetivas do authoring, proveniência por arquivo, derivação local155005 já delimitada, proteção contra jobs automáticos e limites dos testes. Não inclui reader F-READ20260908000049, F-AUTHOR02 cliente, cauda histórica genérica, bridges novos, restauração em migrations/mirror, cherry-pick, alteração do manifesto Foundation ou ativação de exports/participação anônima no MVP. Os únicos preflights são os dois já existentes, incluindo o bridge histórico de labels da base Auth.

Critério de parada desta análise: entregar uma composição revisável e seus gates, sem executar replay. Evidência esperada: hashes normalizados, contagens/ordem, âncoras SQL e limitações explícitas. O trabalho documental utiliza somente leituras locais e dos blobs indicados e escreve apenas este Markdown. **Zero SQL e zero Docker foram executados nesta análise; não houve mutação Git ou alteração de outros arquivos.**

A análise não comprova equivalência com produção. A aprovação deste documento não constitui autorização de execução, instalação de extensões, configuração do cluster, ativação de workers, importação de segredos ou mudança de produto.

A base é packages/coelo_database/replay/foundation-migrations.sha256, SHA-256 UTF-8 normalizado para CRLF **4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59**. A seleção Auth45 mantém versões até 20260812001975 e as quatro entradas 20260827214000,20260827233000,20260901124500,20260901200206. A fronteira Auth continua 20260901200206; o target deste pacote é 030000. Fonte do filtro: packages/coelo_database/scripts/Prepare-SafeMigrationReplay.ps1, ramo AuthOnly.

Os hashes da tabela são das **fontes**, antes da única derivação local155005. Fontes canônicas existentes ficam em packages/coelo_database/migrations; os dois preflights em packages/coelo_database/replay. Os três snapshots históricos têm destino proposto restrito a replay/testfixtures, sem restauração em migrations ou mirror. Este documento não os materializa.

| Ordem | Classificação | Nome exato | SHA-256 fonte, UTF-8/CRLF |
|---:|---|---|---|
| 1 | Canônica Auth | 20260623191021_superadmin_foundation_v1.sql | 1ec51807d2a1f0bbd5cdf7ad11c7ec6d3089cd613319a5954f4d912f45c4edf3 |
| 2 | Canônica Auth | 20260623203230_schema_boundaries_catalog_v1.sql | a8985d8a1fd005c9de23ea08c8da916703c908dc891141599445bf3d0f86d1be |
| 3 | Canônica Auth | 20260717151609_institution_directory_foundation.sql | c64e43c80f5994f99e66455f5a0572d18d99ecf7731eedfaebb423619ff849f5 |
| 4 | Canônica Auth | 20260720103023_institution_contact_directory_refinement.sql | 971f61cdcdbba5fcb077d323d823b76ba7d3c7b56fc3f1da97fc9eebef993716 |
| 5 | Canônica Auth | 20260720180000_people_context_foundation.sql | b2d6ee36c1b75961c057230ff8879bb7979ce417aab0d9662f028c22471b300d |
| 6 | Canônica Auth | 20260720190000_people_context_advisor_hardening.sql | 916696126dddd0b64aa4d8fcf484c8fe26b7191c48f990e7c51a5cdbbcdf893a |
| 7 | Canônica Auth | 20260724120307_contextual_activities_foundation.sql | 6625f904248ab5a36e7d665616bd5b2cab74dd31279442e0493968ea08eb5fd9 |
| 8 | Canônica Auth | 20260724122545_contextual_activities_fk_index_hardening.sql | fecec02870b5462b49001afbe5aea737ae439bef76d493ee339bf78cf3747771 |
| 9 | Canônica Auth | 20260724152628_contextual_authorization_core.sql | bcdc37b5ceda56ecbe3d71f9c30a59f3d48c1a878519da45ca37c2245d467795 |
| 10 | Canônica Auth | 20260724152707_family_authorizations_and_transfers.sql | 36168d2c22d9d2d08c433d26fc9e10164f6cc3da8b38bdc916ec443655040f8f |
| 11 | Canônica Auth | 20260724152713_activity_governance_and_participation.sql | 29d3682bfe4875557ad3c2b1a69d1dc92d076a46a709f8f161bcede2d8fead6c |
| 12 | Canônica Auth | 20260724152722_contextual_chat_foundation.sql | d85b1b1efa3a2690800cb0ee2e1f77509b45b76a67152e1d20dfa3c36908a117 |
| 13 | Canônica Auth | 20260724152731_attendance_assiduity_foundation.sql | d8f99e587330eb4ec8f30525097a25667cc593b0cb03722dc89b1cdf47269ae6 |
| 14 | Canônica Auth | 20260724161334_contextual_domains_compatibility_hardening.sql | 9d73e2abf73c76fd1c20573d8423b297e885ce670570604f65ec6905cae0b4e7 |
| 15 | Canônica Auth | 20260724161706_contextual_domains_advisor_hardening.sql | 5621569f754a28c855386bf8a346a02e2d51fbc49feb4f75558944444102421d |
| 16 | Canônica Auth | 20260724162210_contextual_chat_lifecycle_hardening.sql | a8f8ac522d74c0b31eba89f1121a279243c27a457eb97a394832a89548cad39b |
| 17 | Canônica Auth | 20260724162604_contextual_chat_trigger_hardening.sql | ef7e97f92e628a5c91157bb8cdc9dae17576c39ff61df944996e42dee960733b |
| 18 | Canônica Auth | 20260724162900_contextual_chat_audit_schema_hardening.sql | 80ae137c545d21cf63c3a5fa3fd11a870a59a021dc59337b2dba283553419549 |
| 19 | Canônica Auth | 20260727130433_remediate_schema_column_catalog_completeness.sql | ffa67d796d7586b2fce8ff7682ac6349b35976f0509cdce88001dce0eb925606 |
| 20 | Canônica Auth | 20260728172333_institution_profile_and_legal_representatives.sql | 6be5f3ebb001d9f1c24aac650a9762a10cafda099300127062df629323f69f68 |
| 21 | Canônica Auth | 20260728203000_cover_institution_legal_representative_membership_fk.sql | f14e603ccbdcba05fbb7f1d9df53b536361b7b0e58693e0baba6e7e13427f8f9 |
| 22 | Canônica Auth | 20260729140915_unit_type_plan_foundation.sql | 71673526884c563a3e44fc1f72ff99b33534f680ec1ac8681f82d58572c4519e |
| 23 | Canônica Auth | 20260729141839_superadmin_people_directory.sql | 20cce28127774f1403280de351620b255590e60f4e842d2da22fd897f6fb85bf |
| 24 | Canônica Auth | 20260729144440_profiles_permissions_governance.sql | d0e87f73c841c338c7df7553f2c91e91f7287da481b70501e0f9334fadce385e |
| 25 | Canônica Auth | 20260729153000_superadmin_people_directory_policy_hardening.sql | b938d5ac0399a7137dc764a48baaff32776c466c3c8259d0b170778b528c40cd |
| 26 | Canônica Auth | 20260729153100_child_context_lifecycle_trigger_hardening.sql | 0b16d82755171a1ae26059455b8718162c390a54bac7c1d81107ddcefc3e6065 |
| 27 | Canônica Auth | 20260804205732_access_profile_permission_matrix_metadata.sql | 60992879e5f04eebc3d368742b97be7423b80f26ad73c6c3fcc1819a4a59f07f |
| 28 | Canônica Auth | 20260811125345_institution_management_commands.sql | 10d8bbbbcc8222f62c2e07e07b0886e1a85b54a6b4dd815965f1218d93417321 |
| 29 | Preflight existente | 20260811151253_assert_function_execute_preflight.sql | 718c2de052e9df29abc42642806d9a5e4d98c8964665453de6f14f0f8b61ab75 |
| 30 | Canônica Auth | 20260811151254_group_management_security.sql | 8666c997a8a04e13a404c20f46bfbcaae0cb12b8b5dbb64623fbfff4cfcd993f |
| 31 | Canônica Auth | 20260811192514_activity_management_security.sql | dcb4b5f0781af2f3b0bb1b6a9b63d79a00549e371b7ca0feb0ac5be5bd3820f4 |
| 32 | Canônica Auth | 20260811193838_activity_management_commands.sql | 77fdae731eb56df04bd45f3b8f854495a422bb3230802b5bc4855840f436813b |
| 33 | Canônica Auth | 20260811194624_activity_aggregate_commands.sql | d28c0c7dae5947806c4d2c300a14259cdc997dfb0c85e40c2e0d192bc70b15ba |
| 34 | Canônica Auth | 20260811194840_activity_files_identity_commands.sql | 3ab6f64f3f2d00fb6ff99fa6f1f3c929753bcf29f5b6506f62c95b50107474e9 |
| 35 | Canônica Auth | 20260811195042_activity_file_workers.sql | b33bdaf0db753fc7dc35f3e6da2a5305a789dea571c1b1f5ec9c12929ddfadd8 |
| 36 | Canônica Auth | 20260811195429_activity_management_hardening.sql | b0ee2c41376bd482cead99931a3fdd1f4ac70327c2615b4a1b879640f32819ba |
| 37 | Canônica Auth | 20260811200614_activity_read_model_contract_hardening.sql | 9e99d589ec89975110d3fcaef8c363701bd255b00072b99a4797a923458cea26 |
| 38 | Canônica Auth | 20260811201830_activity_file_job_authorization.sql | acfec92c0f1c2907591e76a7bc94b411e7b677013d14abd3dfa5c5c8587b8a74 |
| 39 | Canônica Auth | 20260811201945_activity_template_commands_hardening.sql | 2c844d87a79a3808df1e67a256481a8794fac737f4d3b609aea4a85b3528987f |
| 40 | Canônica Auth | 20260811202030_activity_options_minimization.sql | 540e02eb1217d1b177efbd9a52b610ff698268892c2ca540d476cd719dd8079a |
| 41 | Canônica Auth | 20260811215451_access_profile_management_v2.sql | 04c1bedd194b812ea753243dd95e400d39e0257f985506a8b703e68329d90208 |
| 42 | Preflight existente | 20260811215452_access_profile_labels_replay_bridge.sql | d97e02796fcd5897707b5657b7a1c1df690f831e09ed98df6ed21886f75f9ef3 |
| 43 | Canônica Auth | 20260812000847_audit_production.sql | 5f5047292c7ed7bbd0f87c5f164628ee50ac211f481e018968469f0b3ad13d0e |
| 44 | Canônica Forms | 20260813155005_forms_definition_and_capabilities.sql | 3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36 |
| 45 | Canônica Forms | 20260813155116_forms_distribution_and_occurrences.sql | ab79c2616fa74944f5213e9544e0033d438308cf4a44b33bce34d7617421b2a0 |
| 46 | Canônica Forms | 20260813155118_forms_responses_and_private_media.sql | 10d338d20948338f16170e3e95fdd3596562be4e3f2056174087edd6bc2a6ee2 |
| 47 | Canônica Forms | 20260813155121_forms_commands_and_projections.sql | cc4aba66cd457862ad8f112876c9e030797bbbbee85acb2faacfa1b0cab7d24a |
| 48 | Canônica Forms | 20260813155124_forms_jobs_notifications_and_exports.sql | 431bc871f2625f040ef51e49603905e0bb1696410fd90de7ef9000a508ec71f0 |
| 49 | Canônica Forms | 20260813155126_forms_security_performance_closure.sql | 2b2a40bcc4c8c85b41765fbecde28dcfdc033f6791bd35313b2d3b8212b2e5e1 |
| 50 | Canônica Forms | 20260813170001_forms_monitor_hierarchy.sql | 7758f30cc1f6bcbf7d5f726a7f84b9951c6ca92c2013bddb461cba169b6da618 |
| 51 | Canônica Forms | 20260820152528_forms_editor_application_capability_guard.sql | ca40b79327b8d61ac45d1914d6d8424ea2580f487205e91f5f3883f19acba81c |
| 52 | Canônica Forms | 20260820154638_forms_distribution_cardinality_limits.sql | 659d7ee37882398ba3d537c15f383ee65e45cfc4a570417b105535e0e6e7bf16 |
| 53 | Snapshot histórico alternativo | 20260820164500_forms_export_download_authorization.sql | 1e06033a6fef9a991ac1140c41fdf430a25ca8c10d298474e82ff7a40b4b1121 |
| 54 | Snapshot histórico alternativo | 20260820164600_forms_export_download_capability_hardening.sql | 85365c67cb8ad9120230e8de570ad9452073d63101f22a4248f1e660670883b8 |
| 55 | Snapshot histórico alternativo | 20260820171200_forms_download_token_actor_fk_index.sql | 8a795b24605d3f8b2289a1b7f158352fb46c44f2dd7b718e90b288d894787673 |
| 56 | Canônica Forms | 20260825193120_final_review_forms_runtime_hardening.sql | 916fe399cb326d7db36f1b232aa1c1e2ebe0556c93c5546a3422f28060e38ee7 |
| 57 | Canônica Auth | 20260827214000_harden_default_function_execute_privileges.sql | fe77ad1daa41477ceb15a91d8080a866b8a23ed470e585c5685f575123bfd5ff |
| 58 | Canônica Auth | 20260827233000_superadmin_internal_auth_context.sql | 87d03cd1e75d9859438c82abbf3c59424680bdd64b57741f10740a5ac7007a33 |
| 59 | Canônica envelope | 20260827235500_superadmin_internal_institution_list_filter.sql | c4496229e2d004907b1c878e9719cadfa60169307eeb92be67cd76c3ad5551aa |
| 60 | Canônica Auth | 20260901124500_harden_superadmin_auth_context_denial_audit.sql | f7a9f92cf0a3a9980f1cd861807a138c012d25977bf08b0e1165bb7db60ee1df |
| 61 | Canônica Forms | 20260901194209_forms_distribution_target_authorization.sql | 28392d2d8fc0a66c38e99137afe9b1be3a6a9376ab5fdf7512897492d628e0db |
| 62 | Canônica Forms | 20260901194256_forms_distribution_rpc_grants_hardening.sql | c3f69ac165e99bb7a3a8a7e34b13d21647c77840e2d1514fd90595ac70e32e5e |
| 63 | Canônica Auth | 20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql | 7e5fa210ff9a0e998c416d7b01a60a14103a5c3d2c539881f49889c0fd618c45 |
| 64 | Canônica candidata | 20260908030000_superadmin_internal_form_drafts_v2.sql | db787041686d9240878077486a981ef63ada007e8cbd23652acb15f96dd7dfab |

A posição 29 precede imediatamente20260811151254_group_management_security.sql. A posição 42 sucede20260811215451_access_profile_management_v2.sql e precede20260812000847_audit_production.sql. Os snapshots ocupam53/54/55; o runtime hardening193120 fica56; Auth27214000/27233000 ficam57/58; envelope235500 fica59; Auth124500 fica60; Forms194209/194256 ficam61/62; AuthMFA200206 fica63; candidato030000 encerra 64.

A fonte do candidato é o commit **2aa27b2553ae7ee145690211b1006f983ba482df**, caminho packages/coelo_database/migrations/20260908030000_superadmin_internal_form_drafts_v2.sql, blob **3c6fcfe072a38a35f79dad22c482c3ccc22794ad**. Os documentos do pacote nesse commit são:

- docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-07-authoring-nominal-package.md;
- docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-07-authoring-lock-reauthorization.md;
- docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-07-authoring-nominal-crosswalk.md;
- docs/reviews/evidence/etapa-2/formularios-cuidado/2026-09-07-authoring-coexistence-matrix.md.

Os snapshots abaixo têm **proveniência alternativa explícita**, indicada pelo Coordenador como não ancestral de 9420191f. A leitura dos três blobs e seus hashes foi conferida; isso não os promove a fontes canônicas do checkout.

| Snapshot | Commit aprovado | Blob aprovado |
|---|---|---|
| 20260820164500_forms_export_download_authorization.sql | 9f21b99f242e83e160a5098a7a9678e0dd84bc67 | 3cc60a7a0fcf1cb8b5a7f717e74d64be12877c26 |
| 20260820164600_forms_export_download_capability_hardening.sql | 0239fb098fd290d34bc523c505d426e7a0e791de | 8fe7c323e404306d67f10db6941ca89770903411 |
| 20260820171200_forms_download_token_actor_fk_index.sql | fb69c6290669ce6cdd661ee8b8790519841ba9ff | 18b15e114db334964874afbdeaa2e61362bc6364 |

A fonte 164500 de9f21b99f substitui a candidata anterior 0bdc0365 neste pacote. Nenhum fallback por nome/data ou outra versão histórica é permitido. A autorização recebida limita uma futura materialização desses snapshots a replay/testfixtures, preservando os blobs e a classificação; nesta entrega nenhum snapshot é escrito.

As dependências que justificam os três snapshots são concretas:

- 164500 cria app_private.form_file_download_tokens, com FKs para public.form_file_jobs/public.people, token_hash único, validade temporal, ENABLE/FORCE RLS e revokes de PUBLIC/anon/authenticated/service_role. Define as funções de listagem/autorização/resgate e wrappers históricos.
- 164600 cria app_private.form_actor_has_export_permission(uuid,text), dependente das tabelas de permissões, memberships, roles e overrides da Auth45; acrescenta unicidade do token ativo e substitui funções de autorização/resgate.
- 171200 cria o índice do ator e também substitui funções para qualificar extensions.digest; seu conteúdo não se resume a um índice.
- packages/coelo_database/migrations/20260825193120_final_review_forms_runtime_hardening.sql:4–5 cria índice sobre form_file_download_tokens; sem a tabela histórica, a aplicação para em 42P01. As referências ao helper de exportação aparecem também nas linhas 736/791 desse arquivo.
- O envelope235500 fornece o contrato de erros necessário ao candidato, incluindo INVALID_ARGUMENT400 e CONCURRENT_CHANGE409. A Auth45 fornece identidade, sessão, contexto interno, MFA200206, permissões e auditoria. O candidato exige owner postgres e dependências do contexto/auditoria/projeção Forms no preflight das linhas 5–32.

A única materialização derivada proposta é:

| Campo | Valor fixo |
|---|---|
| Origem | 20260813155005_forms_definition_and_capabilities.sql |
| SHA origem UTF-8/CRLF | 3a3d2bd348948cdef78a3a0c712c9eae8a6a6fb8be59b8fd942a445f6cbb6e36 |
| Conversor existente | packages/coelo_database/replay/profiles/FReadDirectoryContractRedDerived/Convert-FReadFormsDefinitionForLocalReplay.ps1 |
| SHA conversor UTF-8/CRLF | c3cc8e86a075c20f608d3d34ab31f1611e56f80aabfe29958832f5ab05982dc5 |
| SHA derivado UTF-8/CRLF | 06b71570bbb25c84efe5efed6a6d1f2416a33a5a6fdf71bc20b4776d01833dfe |
| Delta exclusivo | Dois pares de parênteses envolvendo os CASE nas linhas 105–107 e 145–146; quatro caracteres adicionados |

A origem permanece intacta. A execução futura precisará reutilizar o conversor exato, conferir origem/conversor/ancestrais sem reparse, destino local confinado, receipt/path/hash/delta4 e arquivo efetivamente criado. Os outros 63 inputs devem permanecer iguais às fontes pinadas. Não se propõem regex aberta, skip, check_function_bodies desativado, grant adicional ou reescrita de outro SQL. A prova de parser original 42601/derivado compilável foi reportada anteriormente pelo operador; não foi reexecutada nesta análise e não prova a aplicação da closure64.

O bootstrap não pode ser inferido apenas do sucesso anterior de Auth45. Há dependências adicionais:

| Dependência | Âncora | Gate proposto |
|---|---|---|
| Auth/Supabase e pgcrypto | auth.users/auth.sessions/auth.jwt e extensions.digest/crypt/gen_salt usados pela base e funções | Preservar o bootstrap real já pinado; não criar stubs de aplicação. |
| Storage PostgreSQL | 20260813155118_forms_responses_and_private_media.sql:27–35 insere em storage.buckets | Confirmar schema/tabela/colunas reais do bootstrap Supabase; não inventar uma storage.buckets vazia. A existência do schema não requer ativar o worker Storage neste recorte. |
| pg_cron | 20260813155126_forms_security_performance_closure.sql:449 e 482–496 | Biblioteca/extensão da imagem pinada disponível, preload apropriado e launcher global desabilitado antes de qualquer schedule. |
| pg_net | mesmo arquivo:450 e 469–477 | Extensão disponível e zero requisições; não carregar URL/token ou iniciar dispatcher para testar o authoring. |
| Vault | mesmo arquivo:462–468 lê vault.decrypted_secrets | Registrar se schema/view reais existem, sem ler valores de segredos. Ausência não equivale a retorno NULL seguro do dispatcher. |

A migration155126 registra três jobs persistentes. Ela não fixa cron.timezone; a evidência futura deve registrar a configuração efetiva. Os minutos abaixo se repetem em todas as horas/dias:

| Job exato | Agenda exata | Minutos | Comando SQL persistido |
|---|---|---|---|
| coelo-forms-occurrences | */5 * * * * | 00,05,10,15,20,25,30,35,40,45,50,55 | select app_private.form_run_periodic_maintenance(); |
| coelo-forms-reminders | 2-59/5 * * * * | 02,07,12,17,22,27,32,37,42,47,52,57 | select app_private.form_enqueue_due_reminders(interval '24 hours'); |
| coelo-forms-worker-dispatch | * * * * * | Todos os minutos | select app_private.form_dispatch_operations_worker(); |

A implementação final de form_run_periodic_maintenance, em 155126:762–791, chama form_generate_due_occurrences(90), reconcilia audiências e pode criar jobs cleanup_uploads/cleanup_artifacts mesmo sem dados de negócio, caso não existam jobs pending/processing desses tipos. Portanto banco de negócio vazio não elimina efeitos assíncronos.

form_enqueue_due_reminders, em 155124:819–905, insere context_notification_events, insere destinatários e cancela destinatários sem elegibilidade. Seu intervalo considera now()-5min até now()+24h para a chamada agendada. Os dois jobs internos não dependem da disponibilidade de segredos do Vault.

form_dispatch_operations_worker, em 155126:452–480, lê as chaves forms_worker_url e forms_worker_bearer_token de vault.decrypted_secrets. Não há URL literal no corpo: o endereço é o valor do Vault. Se a view existe e algum valor é ausente/vazio, retorna NULL. Se schema/view está ausente, a consulta pode gerar 42P01 antes desse controle. Quando ambos existem, chama net.http_post com Authorization Bearer, Content-Type application/json, body '{}'::jsonb e timeout_milliseconds = 5000. Nenhum valor de segredo ou endpoint remoto foi consultado para este documento.

Proposta de proteção: configurar **cron.launch_active_jobs=off no cluster isolado antes da primeira schedule** e provar a configuração efetiva na versão local pinada. Isso preserva as três definições/metadados SQL sem lançá-las. SET LOCAL na sessão de migrations não é proteção suficiente para o launcher. O upstream define default on, contexto SIGHUP e aplicação via configuração/reload; cron.timezone tem default GMT. [Documentação primária pg_cron](https://github.com/citusdata/pg_cron#extension-settings) e [definição primária do GUC](https://github.com/citusdata/pg_cron/blob/main/src/pg_cron.c). As fontes upstream consultadas não substituem a conferência da versão instalada no runtime local.

O estado active=true em cron.job pode coexistir com o launcher global desabilitado. Esse metadado sozinho não prova lançamento nem proteção. Também não se presume que desabilitar lançamentos depois do fato cancele trabalhos já iniciados; a condição exigida é um cluster isolado sem jobs prévios, com a proteção efetiva antes dos agendamentos. Não se propõem unschedule, alteração de corpos, extensão simulada ou importação de segredos de produção.

**Limite operacional confirmado no CLI 2.116.0 usado pelo runner:** db.settings é uma estrutura fechada. A representação suportada é uma tabela TOML [db.settings] com as chaves enumeradas em packages/config/src/db.ts:36–65, como max_worker_processes e statement_timeout; cron.launch_active_jobs não pertence à lista. Logo, adicionar "cron.launch_active_jobs" = "off" nessa tabela não é um mecanismo suportado para este gate. Não se propõem chave ignorada, injeção em valor de outra configuração ou substituição por max_worker_processes=0 como prova de cron.launch_active_jobs=off. [Schema da configuração da versão pinada](https://github.com/supabase/cli/blob/v2.116.0/packages/config/src/db.ts#L36-L65).

No PostgreSQL 17, db reset --local remove o container e seu volume e cria outro antes de aplicar migrations. O código TypeScript efetivo usa os mesmos inputs de startup, sem opção fromBackup ou hook externo entre essa recriação e a aplicação. Portanto ALTER SYSTEM/reload ou edição do arquivo interno somente no banco criado por start não prova a proteção no banco que receberá a closure64. [Reset da versão pinada, remoção e recriação](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/recreate-local-database.ts#L361-L395), [inputs de startup usados pelo reset](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/reset-local-database.ts#L147-L190).

O runner atual prepara os inputs fora de supabase/migrations, inicia o bootstrap com essa pasta vazia e só então copia os SQLs e chama db reset: packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1:235–236,279–283,300–321. O ponto nominal para um futuro gate é depois do start confirmado e antes da primeira cópia, com falha impedindo cópia e reset. A configuração global persistente teria de ser entregue por um mecanismo suportado no projeto TEMP antes de start e de reset, e conferida nesse gate; esse mecanismo **ainda não está fechado nem pinado**. O caminho normal de startup só acrescenta as configurações db.settings aceitas, enquanto a linha literal cron.launch_active_jobs = off pertence ao caminho de restauração, que db reset não usa. [Entrypoints PostgreSQL da versão pinada](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/postgres.service.ts#L267-L378).

O menor preflight testável proposto é um guard nominal local, com SQL de inspeção e helper pinados após revisão, sem campo genérico de SQL/configuração e sem alterar os 64 inputs. Ele exige identidade do container/TEMP e imagem, ausência de jobs prévios, bootstrap real e prova de configuração global off persistente em toda recriação; metadados ausentes, valor on, override apenas de sessão, hash/alvo divergente ou proteção não persistente devem bloquear antes de qualquer cópia/reset. Testes em TestDrive com respostas simuladas podem provar essa ordenação e os bloqueios, mas não certificam o launcher real. Com os shared scripts atuais fechados, não há ponto de integração autorizado nem representação db.settings capaz de fornecer essa proteção: permanece bloqueada a execução64 até proposta nominal adicional do bootstrap e lease explícito do runner. Não se entrega hash fictício de preflight inexistente, não se muda a ordem para contornar reset e não se executam jobs sentinela.

O próximo gate concreto, ainda sujeito a autorização operacional separada, é um **preflight isolado de runtime antes de aplicar qualquer migration canônica da closure64**:

1. O operador único identifica a imagem/digest e versão PostgreSQL pinados, isolamento/rede, identidade e limites de cleanup. Inicializa somente o bootstrap real necessário, sem serviços de produto/dispatch e sem segredos de produção.
2. Confere disponibilidade e versão de pg_cron/pg_net, preload, banco do cron, timezone, contexto/source/pending_restart do GUC e valor efetivo cron.launch_active_jobs=off. A proteção deve existir desde a inicialização/configuração anterior aos jobs; leitura da sessão sozinha não basta se a configuração do worker não foi aplicada.
3. Confere Storage/Auth reais e a presença ou ausência de Vault sem selecionar decrypted_secret. Confere ausência de jobs/execuções/requisições preexistentes pertinentes e disponibilidade da evidência de execução do cron; nenhum job sentinela é agendado para este gate.
4. Registra PASS/FAIL e faz cleanup independente. Se a versão não suporta o GUC, a configuração não está efetiva ou o bootstrap requerido está ausente, interrompe e retorna uma proposta nominal; não usa fallback que deixe jobs ativos.
5. Somente após essa prova e nova liberação do Coordenador, o futuro replay64 poderá materializar os inputs exatos, conferir **63 inputs não derivados e um derivado**, aplicar a sequência pinada e verificar os três metadados cron, proteção ainda off, zero lançamentos e zero requisições externas. A prova de runtime preflight não é a execução nem a aprovação do pacote64.

O risco histórico G não deve ser mascarado. packages/coelo_database/migrations/20260901194209_forms_distribution_target_authorization.sql:19 usa form_record.deleted_at em public.forms. A definição155005:4–33 contém archived_at na linha 21 e não deleted_at; as alterações da closure não acrescentam a coluna. O caminho legado de distribuição pode gerar 42703 quando alcançado, ainda que o CREATE da função tenha sido aceito. Não se propõem coluna artificial, captura que converta essa falha em PASS ou reescrita canônica.

No candidato, o guard novo é anterior a caminhos legados. A fixture principal espera 22023 em um desses controles e exclui application/schedule/remove_schedule dos positivos de receipt legado em suas linhas 279–280. Assim, GREEN da fixture authoring não provaria correção de G nem conclusão do domínio de distribuição.

As fixtures do commit 2aa27b2553ae7ee145690211b1006f983ba482df permanecem pinadas:

| Arquivo sob packages/coelo_database/supabase/tests | Blob | SHA-256 UTF-8/CRLF |
|---|---|---|
| superadmin_internal_form_drafts_v2_test.sql | 479b16e2f93b2b87ab22ff6d077fd7d27648bd00 | 84b12a447383f2ce80399a4bcbb35333023bd9e61a9d00ba4227bf6529e97d4d |
| superadmin_internal_form_drafts_v2_repeatable_read_test.sql | fa4f6b16996e170507722696e06365e2502cadf7 | 6695671d7149751d04df9d07f84d4aa044b0499ce0ecf6e2075134d5af70cf28 |
| superadmin_internal_form_drafts_v2_serializable_test.sql | 48e1404bbbeb396f6c44692776c8e1cbdc274f29 | 4fccb671da7cdf508e1d1390ffb0fe626778e5bbd397b21187632ded6401cf2f |

Preservar os 19 guards legados do candidato, os dois testes de isolamento (REPEATABLE READ e SERIALIZABLE rejeitados) e o TAP fora de authenticated. Os três arquivos usam no_plan; não se afirma quantidade de asserções executadas a partir da inspeção estática.

A prova concorrente continua separada e exige duas conexões reais: A retém o lock aplicável (request/advisory seed 6404, form/advisory seed 0, linha forms ou institutions); B chama RPC autenticada em READ COMMITTED; pg_blocking_pids deve demonstrar B bloqueada por A. Após isso, A muda/revoga os vínculos, escopo/contexto ou permite expiração controlada de sessão, e libera. B deve revalidar as cinco âncoras de contexto e escopo original, session_id/user_id e clock real após espera, rejeitando sem snapshot/efeito/receipt/auditoria de sucesso; manter controles sem revogação/expiração e not_after=NULL. A fixture principal transacional com rollback não substitui a fixture sintética visível entre conexões nem esse protocolo de waits.

A revisão deste documento é limitada à closure estática e às fontes pinadas. Não comprova replay64, contratos de authoring em runtime, ausência real de jobs, equivalência remota, resolução de G, produção ou conclusão ponta a ponta. A memória capturada aqui é a proposta nominal e suas evidências; nenhuma regra de produto foi alterada. Exports e participação anônima do MVP continuam fora de autorização deste pacote.

## Alternativa operacional submetida — mesma instância, aplicação sem reset

A revisão do CLI pinado identificou uma alternativa menor para avaliação central: inicializar uma stack DB-only nova, com migrations e ledger de aplicação vazios; configurar globalmente cron.launch_active_jobs=off por comando autônomo; reiniciar de forma controlada o MESMO container/volume; conferir o guard real; somente então copiar os64 inputs e aplicar por **npx.cmd --yes supabase@2.116.0 --agent no db push --local --include-all --skip-vault --yes --workdir <TEMP nominal>**. Esta é uma proposta, sem implementação ou autorização de execução. Preserva a ordem dos64 SQLs e seus corpos; substitui apenas o reset recriador neste perfil nominal.

O comando push preserva a instância e permite skip-vault. include-seed e include-roles permanecem false, sem flags de inclusão; nenhuma .env, roles.sql, arquivo de seed ou configuração de segredo do projeto deve ser copiada. A configuração de startup deve rejeitar esses inputs antes de start, que também possui etapas próprias de bootstrap. A alternativa migration up não foi escolhida porque chama upsertVaultSecrets sem a mesma opção. [Flags do comando pinado](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/commands/db/push/push.command.ts#L7-L43), [aplicação e ledger no push](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/legacy-db-push-core.ts#L184-L312), [bootstrap inicial](https://github.com/supabase/cli/blob/v2.116.0/apps/cli/src/legacy/shared/db-bootstrap/db-setup.ts#L1027-L1089).

O guard precisa demonstrar identidade/digest/volume/TEMP, novo postmaster após restart sem recriação, Auth/Storage reais, pg_cron preload e pg_net disponíveis, cron.launch_active_jobs setting/reset_val off, source configuration file, pending_restart=false e configuração aplicada sem erro. Nenhum job anterior ou sentinela. Vault é inspecionado somente quanto à estrutura, sem valores. Qualquer resultado faltante impede cópia/push. Experimental/pgdelta permanecem desativados. O restart da mesma instância é proposto para não depender apenas do retorno assíncrono de reload; sua efetividade ainda depende de prova runtime própria.

Push não oferece --version. Portanto o alvo030000 dependerá da allowlist/descriptor e do máximo único dos64 inputs, ledger de aplicação inicialmente vazio e comparação final de **exatamente64 versões/nomes**, incluindo preflights. include-all nunca dispensa o guard que rejeita ledger prévio. Falha parcial encerra e limpa; não permite repair nem repetir em volume sujo. Após aplicação, exigir proteção cron ainda off, três definições exatas, zero lançamentos e requisições, antes das fixtures. Testes do harness devem provar a ordem guard→cópia→push, bloqueio de ambos quando o guard falha, ausência de reset apenas nesta ramificação e preservação do reset nos demais perfis. A revisão estática não afirma que o bootstrap ou esta alternativa já passaram no ambiente local.
