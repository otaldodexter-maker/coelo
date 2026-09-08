---
source:
  - "Coordenador Etapa2: implementação nominal LOC50 e Agenda53 autorizadas separadamente"
  - "98d166d25d18d1d0b615e244ba8af7e93f11420e e115df2ca35b04e4b8f48aecb1d2a46929bd19949"
  - "743591df3a17c32a4057933400d4c036889df71b: composição Agenda53"
status: preparacao_testada_revisada_sem_execucao_sql
generated_at: "2026-09-08"
---

Este pacote implementa somente os seletores fechados **LocationCatalogV2** e **AgendaReadContractRed** no harness local. O objetivo é aplicar futuramente os conjuntos já revisados, mantendo nomes/hashes/ordem/target e os guards dos demais perfis. O recorte inclui os dois descriptors/resolvers, testes Pester, seleção literal nos entrypoints, categoria separada para o bootstrap LOC e fixtures SQL pinadas. Não aplica SQL, não altera o manifesto Foundation, não flexibiliza AdditionalMigration, não corrige readers e não muda produção.

LOC retorna **47 canônicas + 2 preflights + 1 LocationBootstrap =50**, target20260908031000. São Auth45+235500+31000, com o derivado versionado030959 na posição49, imediatamente antes do candidato50. A fonte original bootstrap permanece no repositório para conferência; não entra no replay. O resolver verifica hashes normalizados e brutos, comprimento, origem Git, ancestrais sem reparse e a equivalência literal: fonte+uma única linha SET LOCAL de54bytes LF depois deBEGIN. O Prepare verifica a categoria somente paraLOC, contagem/posição antes de copiar, hash do derivado e cópia byte-idêntica. Os dois preflights herdados continuam exatamente dois.

Agenda retorna **Auth45 + seis canônicas =51 + dois preflights =53**, target20260901200206. Os seis arquivos completos mantêm os efeitos documentados na proposta743591df; não há grants231645, helper extraído ou inclusão automática das sete Activities. O delta compartilhado de Agenda é apenas allowlist e switch literal em cada entrypoint. O resolver fixa os pins e todas as cópias preservam bytes de origem.

Review encontrou uma falha real no primeiro deltaLOC: ValidateSet e switch aceitam caixa alternativa, mas três condições -ceq ignoravam o bootstrap quando o seletor era minúsculo/maiúsculo. Root reproduziu **1PASS/2FAIL**, observando49arquivos nos dois casos incorretos, em6.6870169s. Corrigiu somente essas três comparações para -eq; nomes/hashes continuam exatos com -cne. O novo grupo tem **5/5PASS**,10.3922387s: três casings exigem50/posição49/hashbruto e dois negativos rejeitam bootstrap alterado antes de copiar. A revisão independente reconstruiu o Prepare anterior revertendo exatamente as três comparações, confirmando ausência de delta adicional.

As duas fontes do bootstrap têm pins brutos LF. Um .gitattributes restrito a esses dois nomes força text eol=lf para preservar os blobs em checkoutWindows; gitcheckattr confirmou ambos. Não há normalização permissiva ou hash alternativo do bootstrap. O arquivo não alcança outros SQLs.

Validação concluída: **488/488 Pester PASS**, zero falhas/skips, WindowsPowerShell5.1/Pester3.4.0, lista explícita dos20 arquivos de regressão. Duração Pester416.7710363s; processo416.9259468s, sessão21811 encerrada exit0 em04:34:35Z. São373 testes anteriores +LOC58 +Agenda57. A rodada anterior foi interrompida ao achar o casing e não tem resultado final aproveitado. Nenhum arquivo mudou durante a rodada concluída. LOC tinha53/53PASS antes dos cinco casos novos; Agenda tinha30testes diretos do resolverPASS e26REDs por seletor ausente antes da integração. O root revisou os três arquivos de Agenda; o reviewer independente revisou LOC e o diff compartilhado corrigido.

Hashes SHA-256 UTF-8 normalizado CRLF do snapshot:

| Artefato | Hash |
|---|---|
| scripts/Invoke-SafeLocalMigrationReplay.ps1 | a6511eb6e8e03d0dd51d9740030437ffb89c519cffbbd2fa8d44cac63c96f539 |
| scripts/Prepare-SafeMigrationReplay.ps1 | 3e5cab9d6fbc0285474d47f97c8efd8614e0e37dde5f3b6c5962ce00ca84ccbe |
| LocationCatalogV2/profile.json | 3edf1fc7608b50615f85994ce48c2e9875484eec6ea7e704516d84ee7c2a82f6 |
| LocationCatalogV2/Resolve-LocationCatalogV2.ps1 | 1aefa81d5d9cea906a85060cbc0979d5351153fdb0c5d3fda1ad09c8529fb750 |
| LocationCatalogV2.Tests.ps1 | c403d5976192398220fb4a8db879c0c0ef3d874cb099f899e7f0c93c6d1aacab |
| AgendaReadContractRed/profile.json | ba5e2b94e3f245bdeb634d86c7f4db2f39b23a6831e0bfbd7a7511031b8c0385 |
| AgendaReadContractRed/Resolve-AgendaReadContractRed.ps1 | dd2d76099fffb393df040ea910981908e0a65e149964a311df7af1a36864bf15 |
| AgendaReadContractRed.Tests.ps1 | 4e7a20bc33a5c7a6d510856ddea9cd088d52a7de1967031cd783d2f359454d7a |

Os dois entrypoints estão em packages/coelo_database/scripts; os perfis em replay/profiles e os testes PS em scripts/tests. A prova de sintaxe cobre seis PS e dois JSON; a resolução direta confirmouLOC47/2/1 eAgenda51/2. O confinamento/mutex/cleanup existentes não foram alterados.

Proveniência LOC: candidato98d166d2, blob **0d4223268de032d7e3536ba58b350b481f8db7c6**, SHA LF **7c7ca4da2aa4eece06f386aee9ada7c52db69eecd996bca18ed434a922f90538**, CRLF **02fb69cbff42834ffa9a9cdebb60bab7e15c6cd0cf150175020de8c8d0f823f6**. O único delta SQL desde947 é service_role:MAINTAIN:false no vetor exato, observado no probeAuth47/46a6077a. Fontebootstrap blob b811809655d8081175965b3120ade41f8af7f0b3, bruto3dd0bf5c11e52a68102e3e707e48835eb676513c235daab5defcdb1e7ad24bfb; derivado115df2ca blob43adedc3a6149c5c2d42bfcec2fe7f74c8286ed5, bruto d46583bc936dfb284b5d05bdba8dea8f965d31a0f899164bfdd8a8c6bd6d2471 eCRLF7d7ae81d7adc7d4d998e7b7f6ffaa7f1d16f463b106bb68b804e01caa0bf5bdc.

Fixtures LOC preservadas do snapshot947, sob supabase/tests:

| Arquivo | Blob | SHA-256 CRLF |
|---|---|---|
| superadmin_location_catalog_v2_test.sql | f2c553069267fb8d7ba3429f42a4b5dccc3ad42d | 550ddb956e1ac83a4a2f6dc91626dde613e8441dcfc96bf17e1c454659853fb6 |
| superadmin_location_catalog_v2_authorization_test.sql | 3545f95b144fe776ebc8af5955ad8cf375c5fcf0 | f6e3b911c41b5bc416bf82c03c9961ef5b869a76efc01baa425ab4afcac25f37 |
| superadmin_location_catalog_v2_isolation_test.sql | da197d2a1fad24737f46e740cb17f3ab4e6ea127 | 85f9aaa937ad71b738d08a947efd04e000678a3ebbfaffea993116535c690ede |

Fixture Agenda a3b76f5b26fc2f787311e87f1b38132516c31c5d, path superadmin_agenda_read_v2_contract_test.sql, blob e8ea4a9322dfa94c6a75e0e65756639fc79f9569, SHA CRLF b7f7eb396b62d84998cef75e000475f82e4d766cb1ffe9e15c6e6b12b463bcad. Materializada sem alteração, autoria105/People601 separada039, constraints imediatas e TAP fora deauthenticated mantidos. A contagem TAP é somente runtime.

A fixture adicional própria **agenda_read_auth_audit_catalog_test.sql**, SHA CRLF **256208ee4cba4af4425fa4f57fd8725c5d9e2b6db05923f842ce495812b9ddec**, prepara **plan10** apenas de catálogo e um diagnósticoJSON. Conferepostgres, enumAuth real/labels/coluna eappender14 exato (OID/retorno/owner/definer/volatilidade/search_path/ACL PUBLIC+trêsrolesAPI). Ausência não viraPASS. BEGIN/RESET/pgtap/ROLLBACK, sem chamada de aplicação, grants ou dados sintéticos. Ela registra os gates exigidos na propostaAgenda; não foi executada neste pacote. A revisão independente confirmou os dez gates, os44linhas e o hash, sem SQL executado; a fixturea3b foi conferida intacta novamente.

A próxima etapa depende de gate central específico: LOC50 com as três fixtures exatas; Agenda53 com catálogo10 e fixturea3b intacta. Somente root operaDocker/SQL, serializado, com identidade criada, marker, saídas reais e cleanup independente. Se houver falha, registrar primeira migration/SQLSTATE eTAP efetivamente emitido; nenhuma ponte/adaptação silenciosa. PreparaçãoGREEN não certifica catálogo aplicado, RPC funcional, UI, E2E ou produção. Não houve mudança durável de regra de produto; fontes e evidência operacional ficaram no pacote próprio, sem atualizar trackers centrais.
