---
title: Preparação nominal corrigida — Modelos50 e Atividades55
source: Autorizações do Coordenador; corretivas63e2cdd6 e96de811b; writers/reviewers independentes; execução root dos gates
status: perfis preparados e revisados; replays SQL separados
generated: 2026-09-08
---

# ModelReadAuthorizationGreen e A01DirectoryAuditGreen

Dois seletores fechados acrescentados ao ValidateSet e ao switch literal de Invoke/Prepare. Reverter somente esses itens recupera os entrypoints anteriores36964bbb byte a byte normalizados. Não há alteração de guards, materializador, AdditionalMigration, mutex ou teardown. Todos os SQL remotos continuam fora do escopo.

## Modelos50

Base49 preservada, com a única corretiva20260908021821 na posição48:48canônicas+2preflights=50, target21821. SQL e fixture17 são cópias exatas do commit63e2cdd6011e25822cfc7ac2be6de7b6b3208b4e. A fixture11 permanece intacta; a17 repete essas11 e acrescenta seis controles de domínio sem platform.read. Ambas são viáveis antes e depois da corretiva.

A fixture local separada ACL10 verifica current_user postgres, existência/owner postgres do helper, SECURITY DEFINER, STABLE, search_path vazio e EXECUTE negado a PUBLIC e às três roles da API. Usa catálogo com ausência/NULL resultando em FAIL e não chama o helper privado como papel de API.

| Artefato | SHA256 CRLF UTF8 sem BOM |
|---|---|
| Descriptor ModelsGREEN | 0986be5b8b35c7498644d0eca4e55fca02b4657ec2a830d27186c3958d5581f8 |
| Resolver ModelsGREEN | e5ea4579b60253f4fe596a1e4d9e57669579d4d4289f5a6582f3db69bf61f4e6 |
| Pester ModelsGREEN | d244d5e86820829aee2cdc385a8e453d9d3ec7d7f80c1a2fee7b7d95c3850f6c |
| Corretiva21821 | b489f6ece6bc12c681d868ff9c68fdc13c00bdb52c3deda09b30aeccd418f992 |
| Fixture11 | 271aa5aca557f53ce6a9017cf6d3c29d40aa6498263deded26a7b31469f62543 |
| Fixture17 | d3464394c05ba86cc021e4fccdbcc4c8884548819b80048a48e61ba812beb76a |
| FixtureACL10 | cf1e4109a2fe0d0cf765aad81d7033a150dc668d1e11b7638fd56a04335a8631 |

Review replay_auth_rls aprovado:50hashes, autorização anterior ao lookup, gates de domínio e demais corpos/contratos preservados; fixture17 literal e ACL10 sem falsoPASS porNULL. Antes da integração, writer29Pester produziu28FAIL pelo seletor ausente e1controlePASS.

## Atividades55

V2 do commit96de811b8ce02333f302117e9ee8c4e7d5dc445d, blob2472a89b61cd34e3be866d80b33a042f5456d6c8, substitui o snapshot canônico local da mesma versão20260907222911. O perfil GREEN fixa v2; mantém os mesmos54outros inputs:53canônicas+2preflights=55, sem empilhar versões.

V1 literal foi preservada em scripts/tests/fixtures/A01DirectoryAuditRedV1, fora de migrations/replay. O RED mantém descriptor/helper e pin77b248 intactos. Seus testes validam a fixture histórica e a repõem apenas no TestDrive; um negativo explícito exige recusar o canônicov2. GREEN tem o negativo recíproco. O runtime não consulta a fixture. O RED real histórico continua reproduzível no snapshotd74a9bccdf70eabb8da2722fc27d420e5d0e05aa; sua rejeição no checkoutv2 é intencional.

| Artefato | SHA256 CRLF UTF8 sem BOM |
|---|---|
| Descriptor A01GREEN | bbd606be64e366502d84389f4a66e9e32ba500f29b043c5cf21cb332a14424ba |
| Resolver A01GREEN | 6b055f0c09b0a918ce5c027e2b59504d7662646535bdcf065e24cdcecde863f2 |
| Pester A01GREEN | 28c7a8108fff89c441f839956fa646744783e6bf54ab1b9a311ddad66dab83ae |
| Pester A01RED histórico | 772047862a472344ac8f45fc8d9337ac77f5e657fc41d664f0217a0f43ed50e1 |
| V1 literal | 77b248f6d60661ebf1fff941107b8fd148d9e2a19e9c27d1b4f45be01571847f |
| V2 canônica | e72e11c5d0f8fd8d49bfe098a230530edb3d4070d80ca5b4ae04b61b72eb196f |
| Fixture97 imutável | f028b86a065f7ea50c1447a62a2b0131ec8cc9119f117c5947355979b1c9648f |

Review replay_manifest aprovado: blobs, pins, contagem, posições e testes recíprocos. Antes da integração, root60Pester: A01GREEN29FAIL por seletor ausente+1controlePASS, A01REDhistórico30/30PASS, zeroSKIP,36.9214473s.

## Gate compartilhado

Invoke738e3c2b2aff0812ab195588f4ddeaa76e28f31b0dd678576132425ad38c928a; Prepare9953f62e43cfd37d48f5e486346e45940fe77d4af64329dd8c3117e341012bf3. Root reconferiu onze hashes, sete parsesPS e resolução direta50/55. Pester3.4.0/WindowsPowerShell5.1 usa somente -Path e -PassThru; a tentativa -Show falhou na ligação de parâmetros antes de qualquer teste e foi corrigida.

Root: **332/332 Pester PASS**, zeroFAIL/zeroSKIP,263.6777612segundos, regressão completa do diretório scripts/tests. Os dois seletores novos ficaram GREEN após o RED inicial; os controles históricos foram preservados.

Após os gates, a fila aprovada é ModelRED49 com11+17, ModelGREEN50 com11+17+ACL10, A01GREEN55 com97. Cada execução terá identidade e cleanup independentes. Preparação ou nome GREEN não constitui resultado SQL, E2E Flutter ou validação de produção. Nenhuma regra nova de produto ou conhecimento de atividade foi criada.
