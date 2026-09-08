---
source:
  - "Coordenador Etapa 2 / Engenheiro 1: autorização nominal de preparação documental AG-READ01 em 2026-09-08"
  - "docs/reviews/evidence/etapa-2/engenheiro-2/plano-e-revisoes-2026-09-07.md:510–564, lido no checkout principal"
  - "packages/coelo_database/replay/foundation-migrations.sha256 e seis fontes canônicas conferidas em disco"
  - "Fixture a3b76f5b26fc2f787311e87f1b38132516c31c5d, blob e8ea4a9322dfa94c6a75e0e65756639fc79f9569"
status: proposta_nominal_para_gate_central_sem_execucao
generated_at: "2026-09-08"
scope: "AG-READ01: base Auth45 + seis arquivos completos + dois preflights; fixture RED aprovada estaticamente"
execution_performed: false
---

Esta proposta confirma **Auth45 + seis migrations canônicas = 51 canônicas + dois preflights existentes = 53 entradas**, todas com nome/versão únicos, ordem cronológica e alvo final **20260901200206**. Os seis hashes e os 45 hashes Auth foram recalculados e conferidos contra os pins; o manifesto e os dois preflights também foram conferidos. O conjunto foi calculado em memória, sem invocar Prepare, Invoke ou qualquer resolver.

O recorte inclui proveniência da fixture aprovada como RED, dependências DDL/tipadas, triggers físicos, autoria do setup, Auth039, audit14, riscos de aborto/ausência e gates para um futuro harness fechado. A ordem do trabalho é fonte Eng2 → validação independente de pins/dependências → fixture → proposta documental. O critério de parada é entregar este pacote revisável; não declarar SQL aplicado ou contrato de leitura aprovado em runtime. O tempo desta entrega é de análise documental, sem estimativa de replay.

Não inclui as sete migrations Activities automaticamente, grants231645, hardening234307, squash Auth20260901190927, helper audit14 extraído/novo, corretiva dos readers, novo preflight/bridge, alteração de fonte, cliente ou execução de comandos Agenda/Activities. A inclusão de arquivos completos preserva efeitos adicionais explicitados abaixo. Não implica certificação do domínio Activities ou aprovação desses comandos para o MVP.

**Zero SQL, Docker e mutações Git foram executados nesta análise. O único arquivo escrito é este Markdown.** A fixture foi lida diretamente do blob; nenhum SQL foi materializado ou modificado. A aprovação estática da fixture como RED não autoriza automaticamente migrations ou replay. A sequência proposta permanece: **proposta53 → gate central → implementação/revisão do harness fechado pelo root → autorização nominal de execução isolada**.

A base é packages/coelo_database/replay/foundation-migrations.sha256, SHA-256 UTF-8 normalizado para CRLF **4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59**. A seleção Auth é o filtro existente: versões até 20260812001975, mais 20260827214000,20260827233000,20260901124500 e 20260901200206. Fontes canônicas ficam em packages/coelo_database/migrations; preflights em packages/coelo_database/replay. Não há snapshot histórico alternativo ou derivação neste pacote.

A tabela apresenta a ordem **total53, incluindo preflights**. As posições canônicas44/45/46/48/49/50 informadas pelo Eng2 equivalem às posições totais46/47/48/50/51/52 abaixo; não são instrução para anexar adições depois de Auth.

| Ordem total | Classificação | Nome exato | SHA-256 UTF-8/CRLF |
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
| 44 | Canônica Auth | 20260827214000_harden_default_function_execute_privileges.sql | fe77ad1daa41477ceb15a91d8080a866b8a23ed470e585c5685f575123bfd5ff |
| 45 | Canônica Auth | 20260827233000_superadmin_internal_auth_context.sql | 87d03cd1e75d9859438c82abbf3c59424680bdd64b57741f10740a5ac7007a33 |
| 46 | Canônica Activities selecionada | 20260831195944_activities_v2_actor_provenance_semantics.sql | 19c3168014d7710b248da92100bb1b61528e9299150a54da74080315e8b99745 |
| 47 | Canônica Activities selecionada | 20260831203645_activities_v2_permissions_receipts.sql | 84bfc497aae6e4d8ad950fc03035896d6b9246c42531823e32ce34817b0d02b5 |
| 48 | Canônica Activities selecionada | 20260831211945_activities_v2_internal_gateways.sql | 443be75040ca103a7a6723aa90037359c11c1681afdc6a6361c2d81f667a6dfa |
| 49 | Canônica Auth | 20260901124500_harden_superadmin_auth_context_denial_audit.sql | f7a9f92cf0a3a9980f1cd861807a138c012d25977bf08b0e1165bb7db60ee1df |
| 50 | Canônica Agenda | 20260901183836_superadmin_agenda_production.sql | 96d909e33598300619a03b8975fa0c6fca243894f1af8fd33acb9458a5926f3d |
| 51 | Canônica Agenda | 20260901184240_agenda_fk_index_hardening.sql | 05c581aa6c8452e98c30592b9dab137f7900b8fb7e22dfe6954222cc359a0df0 |
| 52 | Canônica Agenda | 20260901193717_superadmin_agenda_contexts.sql | d177e4253a6552d88dfe3626afe0834ac3a230bef58db5a0baeaa61951025b27 |
| 53 | Canônica Auth | 20260901200206_defer_superadmin_internal_mfa_until_mvp_go_live.sql | 7e5fa210ff9a0e998c416d7b01a60a14103a5c3d2c539881f49889c0fd618c45 |

O preflight29 permanece imediatamente antes de Groups20260811151254; preflight42 fica entre AccessProfile20260811215451 e AuditProduction20260812000847. Auth27214000/27233000 ocupam44/45; Activities195944/203645/211945 ocupam46/47/48; denialAuth124500 ocupa49; Agenda183836/184240/193717 ocupa50/51/52; H/MFA200206 encerra53. Os53 arquivos devem manter bytes de origem e seus hashes normalizados; não se propõe materialização derivada ou skip.

A seleção por arquivo completo tem estas dependências e efeitos:

| Fonte | Dependência imediata / efeito físico | Limite do diagnóstico |
|---|---|---|
| Activities195944:3–78/80–111 | Cria ou substitui require_activity_v2_internal_marker e guard_activity_v2_actor_provenance; recria nove triggers sobre tabelas presentes na base Auth. O guard exige current_person_id igual ao autor People não nulo em INSERT, mesmo emitido por postgres. | Não exige colunas actor_kind geradas por192831 para criar o guard. Não desativar triggers, fabricar marker ou trazer192831 automaticamente. |
| Activities203645:3–17/19–91 | DO exige owner postgres, guard, set_activity_updated_at e internal_identities. Cria activity_admin_capability_actions e superadmin_internal_activity_command_receipts com FKs/índices, ENABLE/FORCE e revokes. | A tabela de receipts é dependência tipada de gateway211945:211; não é um helper opcional extraído. |
| Activities211945:49–60/211/732–751 | Cria audit_append_superadmin_internal de 14 argumentos e funções/wrappers Activities; usa receipts%rowtype e tipos/relações já cobertos pela base. Define owner postgres e revoga EXECUTE de PUBLIC/anon/authenticated/service_role nos objetos enumerados. | Não incluir231645 para habilitar wrappers. Não alegar contratos Activities completos com três arquivos. |
| Activities211945:27–47/108–170/258 | Substitui globalmente audit_mask_payload, marker, audit_activity_change e has_activity_capability. A máscara já admitia row_count na base; counts aninhado não é necessário ao reader, mas o delta global é efeito do arquivo inteiro. | Audits do setup Activities são reais; não apagar cadeia ou ignorar esses efeitos na revisão. |
| Agenda183836:3–20 | Insere/atualiza catálogo de oito permissões; depende das labels AccessProfile e dispara platform_permissions_catalog_version da base. | agenda.read é catálogo ativo, não seed de grant em papel produtivo. |
| Agenda183836:22–135 | Cria agenda_events, agenda_publication_requests, agenda_guardian_requests, agenda_responses, agenda_history_receipts; FKs para People/institutions e tabelas Agenda, CHECKs, índices e ENABLE/FORCE. Revoga acesso direto de PUBLIC/anon/authenticated. | Nenhuma FK composta valida automaticamente context_id ou a combinação evento/instituição do histórico. A fixture adversarial preserva constraints existentes. |
| Agenda183836:175–310 | Cria list/get e comandos legados. O DO298–310 concede EXECUTE a authenticated para list/get/save/command/requests/decide_publication após revogar PUBLIC/anon. | É efeito nominal de DDL a registrar, não autorização para invocar comandos, conectar cliente ou presumir matriz de grants do produto. |
| Agenda184240:1–17 | Preserva sete índices de FKs. | Não é apresentado como requisito matemático para CREATE dos novos readers; integra o conjunto nominal aprovado para preparação. |
| Agenda193717:3–150 | Preserva contexts legado; consulta instituições/unidades/grupos/activity_definitions e helpers/memberships People quando chamado. | A migration não executa a consulta; não cria as tabelas físicas nem equivale ao futuro reader interno039. |

A base Auth45 já contém public.institutions/units/groups/people e institution_memberships, activities foundation/evoluções, permissões/roles/grants e audit.audit_logs. A relação relevante de Activities é **public.activity_definitions**, não public.activities. Sua origem depende de public.activity_origin_scope e da chave units(id,institution_id), criada por20260724120307:27–28; o DDL activity_definitions:70–98 possui autoria People NOT NULL e FK composta para unidade da mesma instituição. set_activity_updated_at está em20260724120307:620. Os nove alvos dos triggers195944 estão na cadeia herdada; o novo activity_admin_capability_actions recebe seu próprio guard no203645.

As declarações tipadas do gateway lidas neste recorte incluem superadmin_internal_context, superadmin_internal_activity_command_receipts%rowtype, activity_definitions%rowtype e institution_memberships%rowtype. A closure resolve essas dependências de criação. Ausência de necessidade física dos outros quatro arquivos Activities não prova comportamento de comandos que consultem colunas ou regras de outra evolução.

O gate **audit14** deve conferir a assinatura exata:

~~~text
app_private.audit_append_superadmin_internal(
  uuid,uuid,uuid,uuid,text,text,text,public.audit_outcome,
  text,uuid,uuid,text,uuid,jsonb
) returns uuid
~~~

A definição211945:49–60 é VOLATILE, SECURITY DEFINER, search_path vazio; valida consistência identity/link/membership, grava hash_version2, actor_kind superadmin_internal, SHA256 da sessão, capability/AAL, ação/outcome/correlação/instituição e after_json. O DO732–751 fixa owner postgres e revoga EXECUTE de PUBLIC/anon/authenticated/service_role. O appender13 da Auth039 não grava after_json e não substitui esse contrato.

Em runtime, conferir OID, número/tipos/retorno, owner, prosecdef/provolatile/proconfig e ACL efetiva, incluindo ausência de EXECUTE PUBLIC e das três roles API; NULL ou função ausente não pode ser PASS. Conferir também denial helper (text,text,text,uuid,uuid), H vigente200206, audit.audit_logs e seu trigger append-only/minimização. Não modificar helpers ou grants para fazer esse gate passar. A máscara genérica aceita outros campos; restringir after_json somente a row_count é obrigação do futuro reader e da fixture.

A fixture aprovada estaticamente como RED tem proveniência exata:

| Campo | Valor |
|---|---|
| Commit completo | a3b76f5b26fc2f787311e87f1b38132516c31c5d |
| Caminho | packages/coelo_database/supabase/tests/superadmin_agenda_read_v2_contract_test.sql |
| Blob | e8ea4a9322dfa94c6a75e0e65756639fc79f9569 |
| SHA-256 UTF-8/CRLF | b7f7eb396b62d84998cef75e000475f82e4d766cb1ffe9e15c6e6b12b463bcad |
| Estrutura | 412 linhas no commit; BEGIN, no_plan(), finish(), ROLLBACK |
| Materialização nesta tarefa | Não realizada |
| Execução nesta tarefa | Não realizada; contagem TAP somente após runtime |

A aprovação central recebida é para a fixture como RED, com seu conteúdo preservado. O comentário histórico da primeira linha menciona ausência de aprovação/execução à época; a autorização atual de preparação documental não é um lease de execução SQL.

Auth da fixture exige o bootstrap Supabase real: auth.users, auth.sessions, session.not_after e o tipo enum **auth.aal_level**, usado explicitamente na linha 44 para aal1/aal2. Esse tipo é externo à seleção de migrations de aplicação. Antes da fixture, o operador precisa comprovar to_regtype/labels aal1/aal2 e a compatibilidade da coluna auth.sessions.aal na versão pinada; não substituir por text ou um enum inventado. A cadeia039 fornece internal_identities/auth_links/memberships, composite de contexto e governança de escopo. A fixture inclui AAL1 positivo conforme H200206 e nega sessão expirada, sessão de outro usuário, vínculo revogado/suspenso, People-only, ausência de claims e capability deny.

O setup resolve os dois gates físicos apontados pelo Eng2:

- Linhas39–60 criam usuários/sessões e leitores039 sintéticos. Os leitores internos não recebem person_auth_link; a asserção157–159 verifica essa ausência.
- Linhas62–71 criam a pessoa histórica601 separada e seu auth_user105, que não tem identidade interna. As claims105 são estabelecidas antes dos INSERTs de Activities. Isso atende o guard195944:68–75 por autoria global legítima, sem marker ou capability Activities.
- Linhas72–82 criam as três activity_definitions e seus três activity_unit_links ativos. As FKs mantêm instituição/unidade coerentes, inclusive a origem arquivada usada como negativa de projeção.
- **SET CONSTRAINTS ALL IMMEDIATE na linha83**, antes de limpar claims na84, força a prova dos constraint triggers inicialmente adiados. Foundation20260724120307:688–696 exige ao menos um vínculo de unidade ativo/não encerrado;1048–1056 define os triggers. O ROLLBACK final não é usado para esconder fixture estruturalmente inválida.
- Os triggers de auditoria do setup permanecem ativos. As comparações de eventos/history são capturadas depois do setup nas linhas119–124; os testes de audit360–378 identificam ação/correlação de cada chamada e não confundem contagem global com audit das atividades. Não há DELETE/UPDATE de audit para “zerar baseline”.
- Agenda possui autor People601 válido, sem usar esse vínculo para autorizar o leitor. History A com institution B e evento A com context_id de B são casos estruturalmente possíveis porque essas relações não têm a FK composta correspondente; a fixture não desativa constraints. A resposta B vinculada ao evento A serve de sentinela para provar sua omissão.

A fixture cria papéis sintéticos901/902 com allow/deny de agenda.read. O único controle adicional de concessão é agenda.create, em papel sintético, nas linhas250–277: allow, leitura contexts, deny e nova leitura; mutation_actions_available continua false e nenhuma RPC de escrita é invocada. Esses dados são rollback e não estabelecem matriz de papéis produtivos.

A captura pg_temp.ag_capture:130–140 é SECURITY INVOKER, usa o SQL role real e armazena body/sqlstate/message/current_user em TEMP. Todas as chamadas sob authenticated são seguidas de RESET ROLE antes de TAP/audit. Se os três readers v2 estiverem ausentes, o EXECUTE dinâmico captura 42883; não cria wrapper substituto nem eleva privilégios. Os testes has_function151–153 usam assinaturas explícitas:

~~~text
public.superadmin_agenda_list_v2(timestamptz,timestamptz,uuid,text,integer,integer)
public.superadmin_agenda_get_v2(uuid)
public.superadmin_agenda_contexts_v2()
~~~

Os testes ACL347–358 resolvem to_regprocedure/OID antes de has_function_privilege e usam coalesce de modo que função ausente/NULL falhe. Não chamam a variante textual com nome inexistente que abortaria antes da asserção. As extrações de IDs/correlações da resposta são comparações textuais, sem casts UUID de resposta ausente; os casts restantes vistos são UUID sintético determinístico e counts inteiros. A ausência capturada produz body SQL NULL, propagando pelas operações JSON sem exigir conversão de um valor ausente. Isso é uma análise estática do RED esperado, não promessa de zero aborto em runtime; formato JSON inesperado ou falha de fixture/DDL deve ser relatado como tal.

A fixture exige sucesso/envelope em asserções próprias antes das allowlists/minimização, para não tratar resposta ausente como autorização correta. Há controles de paginação/ordem, busca literal de %/_/barra, filtro cross-tenant, inexistente versus tenantB indistinguíveis, contexto estrutural inválido, hierarquia ativa e sentinelas de autores/response/audience/history. Algumas asserções negativas isoladas podem passar sem corpo; elas não são consideradas prova de reader quando os gates positivos falham. no_plan e SELECTs que produzem várias linhas impedem declarar contagem TAP somente por contar chamadas SQL.

Auditoria360–378 exige correlação real, ator/link/membership039, scope/instituição, hash da sessão e after_json exatamente row_count, sem before_json/object_id. O trigger temporário380–399 injeta P0001 apenas em audit de sucesso Agenda, para exigir que falha de append propague sem resposta/data de sucesso; é rollback, sem substituir o trigger global ou capturar falha como sucesso. Os hashes de eventos/history e a quantidade de receipts no final preservam a prova de leitura sem efeitos de domínio.

A próxima sequência nominal proposta é:

1. Coordenador revisa esta composição53, os seis arquivos integrais/efeitos e o pin da fixture; confirma autorização para o harness fechado. Nenhuma SQL corretiva decorre automaticamente da aprovação do RED.
2. Root implementa/revisa o seletor nominal específico, preservando Auth45/Foundation, a fronteira AdditionalMigration, nomes/hashes/contagens/ordem/target, confinamento/reparse e rejeições de modos incompatíveis antes de staging/Docker. Não aceitar histórico livre, grants231645 ou helper extraído.
3. Após gate central separado de execução, operador único verifica bootstrap Auth real, auth.aal_level, identidade da stack, ausência de colisões e o catálogo/ACL audit14 da base aplicada. Aplicação normal deve manter checks/constraints/triggers; não usar skip ou relaxamento para superar uma falha.
4. Materializa a fixture do blob exato somente sob lease apropriado e executa RED isolado. Registra migrations efetivamente aplicadas, primeiro erro se houver, TAP realmente emitido, exit status, role da captura e cleanup independente. Espera estática: três readers v2 ausentes e 42883 capturado; não converter essa expectativa em resultado executado.
5. Qualquer dependência inesperada de DDL/bootstrap, falha de autoria ou constraint aborta e retorna para revisão nominal. A corretiva dos readers e eventual GREEN dependem de pacote/lease próprios; não alterar SQL nem ampliar Activities dentro do RED.

Parecer independente: os seis pins correspondem ao inventário Eng2; a composição53 é coerente estaticamente e a fixture trata os gates de autoria, constraints adiados, captura de ausência e ACL sem exigir grants adicionais de Activities. **A liberação aqui é para revisão da proposta, não para execução.** Não se comprovam compilação/aplicação nominal, número de TAP, matriz produtiva de Agenda, E2E ou runtime dos comandos legados. O conhecimento registrado é evidência operacional da proposta; nenhuma regra de produto ou projeção de conhecimento foi modificada.
