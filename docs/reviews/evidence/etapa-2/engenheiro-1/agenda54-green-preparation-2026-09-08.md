---
fonte:
  - "Autorização nominal central AGGREEN54 transmitida pelo Engenheiro 1 em 2026-09-08"
  - "Git 0b55e9199502b7622c7fe82605196a901ecde430, blob aaa8a73a655b680372b98ac87a245814f054d7a2"
  - "packages/coelo_database/replay/profiles/AgendaReadContractRed/profile.json"
status: "preparação local integrada: 34/34 Pester PASS; replay SQL ainda não executado por este pacote"
data_geracao: "2026-09-08"
---

# AgendaReadContractGreen — preparação nominal de 54 entradas

O perfil acrescenta somente `20260908045531_superadmin_agenda_read_v2.sql` à seleção exata do pai `AgendaReadContractRed`. São **52 migrations canônicas + 2 preflights = 54 entradas**, com sete canônicas adicionais à base Auth45. O alvo obrigatório é `20260908045531`; a candidata ocupa a posição canônica 52 e a posição final 54 do replay.

O recorte autorizado desta preparação contém a materialização byte a byte da candidata, um descriptor fechado, um resolver que reutiliza o pai pinado, uma suíte Pester e esta evidência. O autor não modifica os entrypoints compartilhados, o perfil RED nem as duas fixtures SQL existentes. A integração mínima de `ValidateSet` e do braço literal de `switch` em `Invoke-SafeLocalMigrationReplay.ps1` e `Prepare-SafeMigrationReplay.ps1` pertence ao Engenheiro 1. Nenhum comando Docker, execução SQL, alteração de Git ou replay foi realizado por este pacote.

## Proveniência e preservação

A candidata foi lida diretamente do commit aprovado `0b55e9199502b7622c7fe82605196a901ecde430`, blob `aaa8a73a655b680372b98ac87a245814f054d7a2`. O arquivo canônico materializado mantém os **20.249 bytes LF** originais, sem alteração de SQL, nome ou timestamp.

| Entrada | SHA256 LF UTF-8 | SHA256 normalizado CRLF UTF-8 sem BOM |
| --- | --- | --- |
| Candidata `20260908045531_superadmin_agenda_read_v2.sql` | `b26487cb3d3ffbf483ba3f6ff7b94e7f6d4e95d3309dd9c96640b37532287cab` | `15a490013e556d4a271dc2e026dc564737f0bf078c25a9916e5276c3db57f4a9` |
| Descriptor pai RED53 | `ce0dae0f8fc34f812324fed2d967fc41348753ffc9c5dee1c64a1823b1d5724a` | `ba5e2b94e3f245bdeb634d86c7f4db2f39b23a6831e0bfbd7a7511031b8c0385` |
| Resolver pai RED53 | `9c0837a38d6edc6eda551c4f14b1d83656040619a5d5a4bf5472f306fefd6011` | `dd2d76099fffb393df040ea910981908e0a65e149964a311df7af1a36864bf15` |
| Fixture `agenda_read_auth_audit_catalog_test.sql` preservada | `fdac279cd60210fd858ba14a8288f4d44d10e36903d10914a17c1ad04d52a4ea` | `256208ee4cba4af4425fa4f57fd8725c5d9e2b6db05923f842ce495812b9ddec` |
| Fixture `superadmin_agenda_read_v2_contract_test.sql` preservada | `9d2df04630933638123ff5841aa65a5c49bb2198cc78db33bb849c68b9cb3418` | `b7f7eb396b62d84998cef75e000475f82e4d766cb1ffe9e15c6e6b12b463bcad` |

Os blobs LF observados do pai são `713af46a6328ffbe31a306eb4b9581c20a9ed67e` para o descriptor e `f6e8c6f81212025e01e391757a6ba50a043188ba` para o resolver. Os blobs LF das fixtures preservadas são, respectivamente, `221b663c0baee84c64c4951a1e9512f6e034bca8` e `e8ea4a9322dfa94c6a75e0e65756639fc79f9569`.

## Contrato do resolver

O descriptor GREEN é pinado pelo próprio resolver. Os caminhos do descriptor pai, do resolver pai e da candidata são literais; não há parâmetro de caminho, SQL livre, bridge adicional ou repin do RED. Antes da leitura de cada dependência, o resolver rejeita reparse point no arquivo e em toda a cadeia de ancestrais. Os dois arquivos do pai são verificados por hash antes de `&` executar o helper.

O pai conserva a seleção Auth45, seis adicionais e dois preflights, com manifesto `4279e67c9651f4049329591b6e8aad82e3a9052506c1a4e16ba8bbb693249d59`. O GREEN exige exatamente um objeto de saída desse pai, 51 canônicas, duas preflights e seis adicionais. Depois de validar nome e hash da candidata, acrescenta-a às canônicas e às adicionais. A saída usa somente as propriedades já existentes `Canonical`, `Preflight`, `Additional` e `ManifestHash`, com objetos `FileInfo`.

A ordem é lexical por nome/timestamp, com 54 versões únicas. A candidata é o único acréscimo e precisa ficar na posição final. As preflights herdadas permanecem nas posições totais 29 e 42:

| Posição total | Preflight | SHA256 normalizado CRLF |
| --- | --- | --- |
| 29 | `20260811151253_assert_function_execute_preflight.sql` | `718c2de052e9df29abc42642806d9a5e4d98c8964665453de6f14f0f8b61ab75` |
| 42 | `20260811215452_access_profile_labels_replay_bridge.sql` | `d97e02796fcd5897707b5657b7a1c1df690f831e09ed98df6ed21886f75f9ef3` |

A validação de integridade usa o mesmo hash de texto normalizado CRLF do harness. A materialização da candidata preserva o blob LF original, e o teste de preparação compara os hashes **raw** dos 54 destinos com os respectivos arquivos de origem. Não se afirma identidade raw entre checkouts com finais de linha diferentes a partir do pin normalizado.

## Gates executados e limites

O RED preciso anterior à implementação do perfil/resolver e à inclusão na allowlist foi **34 falhas de 34 testes, zero skips, 25,8970773 segundos**. Ele incluiu a rejeição explícita da opção ausente no `ValidateSet` dos entrypoints. Uma primeira versão do teste usava mensagem de erro excessivamente ampla; essa versão não é usada como evidência do RED preciso.

Após a implementação, os **25 testes diretos do resolver passaram**, com zero skips, em **22,2594565 segundos**, usando Pester **3.4.0**. Cobrem seleção herdada, contagem e ordem, alvo, drift do descriptor e dos pins do pai, integridade da base/preflights/pré-requisitos/manifesto, candidata ausente/renomeada/alterada, seis casos de metadata de reparse point e rejeição de terceiro SQL de replay. Os reparse points são simulados por mock de metadata; nenhum link real é criado.

A suíte completa possui nove casos adicionais para o contrato de integração: preparar 54 arquivos byte idênticos, aceitar o alvo nominal, rejeitar o alvo antigo, rejeitar combinações com `AuthOnly`, `FoundationOnly`, `AdditionalMigration`, `RunAuthLifecycle` e `RunActivityV2Concurrency`, e detectar drift antes de copiar ou iniciar o runner. As cópias do `Invoke` no TestDrive contêm uma sentinela imediatamente antes do mutex/Docker; esse caminho não executa o engine.

Após o Engenheiro 1 integrar e estabilizar os dois entrypoints, a suíte completa passou em **34/34 testes, zero falhas, zero skips, 31,6122351 segundos**, com Pester 3.4.0. O caso de preparação confirmou exatamente 54 destinos e igualdade raw dos 54 arquivos com suas origens, além da saída honesta `52 canonical + 2 preflight` e `additional=7`. O parser PowerShell passou nos quatro arquivos envolvidos (resolver, teste e dois entrypoints), sem erro. A verificação de whitespace dos quatro arquivos autorais de texto não apontou linhas com espaços finais. Os hashes do descriptor, resolver e teste listados abaixo permaneceram inalterados durante o GREEN integrado.

Os testes de preparação não comprovam execução PostgreSQL, compilação da migration, comportamento HTTP, autorização real ou passagem das fixtures pgTAP. O replay GREEN54 e seus gates operacionais continuam sob a autorização e operação serial do Engenheiro 1.

## Arquivos novos do perfil

| Arquivo | SHA256 normalizado CRLF UTF-8 sem BOM |
| --- | --- |
| `replay/profiles/AgendaReadContractGreen/profile.json` | `ec71fcca12d79b8e89051bf4f9e2f63f99bca17c0517d5ca9a4a7c4cd30c9051` |
| `replay/profiles/AgendaReadContractGreen/Resolve-AgendaReadContractGreen.ps1` | `2eb4f82db7770661aac783cdc4a534e481fbe95e0ae60eb8f019d65f7185347b` |
| `scripts/tests/AgendaReadContractGreen.Tests.ps1` | `f42aa964045bcd36dda354ca6799480c7fa9bff6abe6bb302ffa5f13d70b07f9` |

Os caminhos desta tabela são relativos a `packages/coelo_database`. Este documento registra preparação técnica e proveniência; não altera regras duráveis de produto ou permissões.
