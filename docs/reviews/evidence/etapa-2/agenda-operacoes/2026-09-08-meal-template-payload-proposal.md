---
title: "Cardápios — proposta nominal de roundtrip de conteúdo de modelos"
source: "migration 20260820160000; MealPlanTemplateDraft.toJson; review activities_contract_read; direção de compatibilidade do Coordenador em 2026-09-08"
status: "matriz aprovada pelo Coordenador; correção cliente local-green; E2E aberto"
generated_at: "2026-09-08"
---

## Evidência e limite

O SQL grava `p_payload` inteiro em `meal_plan_templates.payload` e na versão,
tanto no insert quanto no update (855/884). List/get devolvem esse JSON sem
achatamento (724/783), e save devolve get (901). O caminho `saveAsTemplate`
(1207–1216) já envia conteúdo plano. O cliente de save direto envia uma camada
extra `payload`, enquanto diretório/wizard buscam conteúdo no primeiro nível.
O DEV guarda somente `draft.payload`, mascarando essa divergência.

Hashes SHA256 dos arquivos físicos desta worktree, sem transformação:

| Fonte SQL | SHA256 |
| --- | --- |
| 20260820160000_meal_plans_model_audience_availability.sql | f4e8c88ba3c92afeade49d969d625b124bf6196bc1d7da58008bea6bceacc8e3 |
| 20260820150500_meal_plans_scope_guard.sql | d824e0cba683b2afb193e711d7889b857b72de59830600f36f3492d1371dd479 |

Teste candidato `meal_template_payload_contract_test.dart`, sobre HEAD
`2f48c0b`: **6 casos, 2 PASS e 4 FAIL, exit1**. Falham comando sem menu plano,
get/list histórico aninhado e roundtrip save que devolve exatamente o p_payload
recebido. Get/list planos passam. A primeira rodada tinha um save duplicado
pelo parâmetro histórico sem efeito; removido antes da contagem final.
Nenhum SQL ou rede executados; o mock não prova persistência, autorização ou
validade de todos os campos no servidor. Serializer produtivo intacto nessa rodada.

## Matriz submetida e aprovada antes de implementar

Detectores de conteúdo (allowlist de forma, não autorização): `menu`,
`simpleImage`, `simpleImageAlt`, `simpleNotes`. Presença da chave conta,
inclusive array vazio ou imagem nula; não usar truthiness nem fallback que
ressuscite conteúdo histórico quando o atual está vazio.

| Payload armazenado/resposta | Proposta |
| --- | --- |
| `{menu:[...], futureField:{...}}` | Plano canônico; conservar todos os campos, inclusive desconhecidos |
| `{name:"...", payload:{menu:[...], futureField:{...}}}` | Uma camada histórica inequívoca; remover somente o wrapper reservado, conservando campos externos/internos não conflitantes |
| `{menu:[], payload:{menu:[...]}}` | Recusar com erro seguro; vazio explícito não autoriza selecionar conteúdo antigo |
| Conteúdo reconhecido nos dois níveis, mesmo idêntico | Proposta conservadora: recusar forma mista; não inferir qual é autoritativo |
| Colisão de nome de campo externo/interno ao normalizar | Recusar, sem overwrite silencioso de campo desconhecido |
| `{payload:{payload:{menu:[...]}}}` | Recusar; nunca achatar recursivamente |
| Wrapper presente não objeto ou sem nenhuma chave reconhecida | Recusar forma histórica ambígua; não converter em conteúdo vazio |
| `{}` sem wrapper | Preservar compatibilidade de DTO vazio; validação de salvar/publicar continua separada |

Metadados autoritativos do DTO continuam exclusivamente no envelope externo da
RPC. Nunca derivar tenant, instituição, ID, versão, tipo ou público de menu,
imagem ou campo desconhecido. Conteúdo não concede autorização.

Comando proposto: espalhar conteúdo normalizado no nível superior e escrever
explicitamente por último os campos conhecidos do comando (`requestId`, `id`,
`tenantId`, `institutionId`, `name`, `planVariant`, `audienceSegment`), com a
precedência documentada. A fonte desses valores é o draft já construído, não
JSON arbitrário dentro de refeições. O parâmetro `p_template_id` e a revisão
continuam separados como hoje. O wrapper reservado `payload` não é reenviado.

Há um complemento necessário para não perder campos desconhecidos na edição:
o wizard hoje reconstrói `_templatePayload` com só quatro chaves. A proposta
inclui preservar a base normalizada de `_originalTemplate.payload` e substituir
somente os quatro campos editáveis conhecidos; nunca copiar dados de outro
contexto/modelo. O save de modelo novo continua partindo de base vazia. Esse
ajuste exige teste de edição com campo desconhecido, além de roundtrip do DTO.
Não alegar conservação de campos por apenas corrigir o serializer.

Antes de implementação: revisão central desta matriz, especialmente recusa de
formas mistas e precedência de metadados conhecidos; depois REDs adicionais de
ambiguidade/níveis/unknown-field e teste de edição; correção mínima; regressão
dados/wizard/rota e review independente. Não há alteração SQL ou migração de
registros nesta proposta. Backend People legado, integração039, R2 e E2E
permanecem fora da evidência local.

## Resultado da implementação autorizada

O Coordenador leu a matriz e autorizou a correção cliente, incluindo recusa de
formas mistas e conservação da base do mesmo modelo, sem SQL. Foram adicionados
REDs de forma ambígua/recursiva/colisão, metadados e conteúdo histórico: **18
casos, 3 PASS/15 FAIL** antes da correção. Wizard: **2 FAIL** por campo opaco
perdido na edição de A/B e **1 PASS** para modelo novo sem base antiga.

Implementado `_readMealPlanTemplatePayload`, usado no parser e no comando:
normalização de exatamente uma camada inequívoca, preservação de chaves opacas
e erro de domínio seguro para formas recusadas. Comando plano escreve os sete
metadados conhecidos por último. Wizard preserva o payload original somente
na edição de modelo e substitui as quatro chaves editáveis da matriz.

Controle adicional pelo adapter prova que campos opacos `p_template_id`,
`p_expected_version` e `p_publish` não substituem os parâmetros RPC explícitos;
não transforma isso em autorização server-side. Suite de payload totaliza 19
casos. Regressores de dados, wizard, diretório e duas suites de rota:
**100 PASS, exit0**. Analyzer quatro arquivos e validador visual: PASS.
Review independente `activities_contract_read`: sem blocker.

Limite preciso da conservação: campos desconhecidos de primeiro nível fora das
quatro chaves editáveis são preservados. As quatro chaves, inclusive `menu`,
são substituídas integralmente pelo editor como aprovado; não há conservação
recursiva de campos desconhecidos dentro das refeições reconstruídas. Não
alegar roundtrip sem perda para um schema futuro de refeição desconhecido.

Nenhum SQL, Docker, persistência, migração de registros ou HTTP real nesta fatia.
Regra de compatibilidade técnica aprovada registrada nesta fonte; não altera
regra de produto para públicos finais ou cria nova projeção de conhecimento.
