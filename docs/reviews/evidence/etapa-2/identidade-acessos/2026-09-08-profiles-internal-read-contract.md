---
title: "Perfis — diagnóstico nominal de leitura interna e paginação"
source: "Reserva LOCAL do Coordenador em 2026-09-08; spec 018; ADR 0019/spec 039; inspeção da composição e migrations 20260729144440/20260811215451"
status: "nominal-replay-red; acl-before-contract"
generated_at: "2026-09-08"
---

## Recorte e primeiro gate

Somente READ de Perfis no Superadmin. A reserva autoriza fixture diagnóstica,
não corretiva, atribuição, deleção, grants ou substituição de helper global.
Engenheiro 1 permanece o único operador de replay. Nenhum SQL, Docker ou
remoto executado por esta frente.

O caminho configurado injeta `SupabaseAccessProfileRepository` no Scope (286),
passa por main (32), App (225) e rota `/profiles` (2196). O Scope indisponível
(358) é fallback de configuração/erro. Isso prova composição no código, não
o ramo usado no ambiente remoto nem E2E.

O adapter envia `p_page`, `p_page_size` e filtros CSV, esperando `items`,
`total`, `page` e `page_size`. A compatibilidade v2 (migration 20260811215451,
1305) ignora `p_page` e chama cursor com cursores nulos; o cursor devolve
`items/next_cursor` e compara status/escopo como valores únicos. Seu guard
`require_profile_authority` ainda depende de `current_person_id` e vínculos
legados. São divergências estáticas, não três REDs comportamentais confirmados.

Há uma barreira potencial anterior: o wrapper é SECURITY INVOKER e chama
função privada cujo EXECUTE foi revogado de `authenticated`. Sem conceder
permissão artificial, a execução pode parar em ACL antes do guard/contrato.

## Fixture e interpretação

Arquivo: `packages/coelo_database/supabase/tests/access_profiles_internal_read_contract_test.sql`.
SHA-256 UTF-8/LF:
`3a5dd87b3574875279d7e59e9c75bd686252161d95c5839b1e6ad47dbea1aa9f`.

O plano 8 contém três precondições (sem vínculo people, papel authenticated e
bootstrap interno AAL1 positivo) e cinco expectativas do cliente: primeira
página, metadados total/página/tamanho, segunda página, múltiplos escopos e
compatibilidade do parâmetro status CSV. Não introduz filtro de status na UI.
Doze perfis sintéticos com prefixo exclusivo e ordenação fixa isolam os dados.

As RPCs executam sob authenticated; cada erro SQL é capturado sem alterar
grants/helpers. TAP roda após RESET ROLE e o final faz rollback. Diagnósticos
separam `acl-before-contract`, `authorization-denied` e `runtime-error`, sem
imprimir dados de resposta, credenciais ou mensagens SQL completas.

Se ACL bloquear, os cinco FAILs de contrato são efeitos da primeira barreira,
não evidência independente de paginação/filtro. Não usar actor postgres ou
ponte people para tornar artificialmente verde esse gate. Uma corretiva só
poderá ser proposta após o RED nominal e nova reserva do Coordenador.

Review independente `account_review`: sem bloqueios estáticos; plano 8
conferido, NULL após erro não aborta as asserções seguintes. Execução pendente.
Gate de memória: no-op; nenhuma decisão de produto nova ou promoção E2E.

## Resultado nominal — Auth47

Evidência final do Engenheiro 1 lida integralmente:
`engenheiro-1/auth47-loc-profiles-probe-2026-09-08.md`.
Base Auth45 + dois preflights; sem Models/Forms extras. Fixture original
b11c3c3e com o hash LF acima preservado. Execução iniciou em
2026-09-08T03:48:17.3708297Z. Perfis: 3 PASS de precondições e 5 FAIL (#4–8),
sem aborto; quatro chamadas com SQLSTATE 42501 / acl-before-contract.
O lote também tinha LOC, cujos três controles não pertencem a esta frente.

Catálogo confirma wrapper público SECURITY INVOKER/authenticated EXECUTE e
cursor privado SECURITY DEFINER/sem EXECUTE authenticated. Ambos são owner
postgres, search_path vazio e PUBLIC ACL vazio. Bootstrap interno Owner AAL1
e ausência de ponte people passaram. Paginação/CSV ainda não foram alcançados.

Identidade isolada `coelo_safe_c3e8951894af4fb198f46b7bba357`; cleanup
independente 2026-09-08T03:50:56.8629214Z: zero containers, volumes e redes
próprios, staging ausente e staging histórico preservado. Sem grant corretivo,
mutação remota ou promoção E2E. Proposta posterior fea97b2b aguarda contrato
canônico de escopo e contagem antes de SQL, conforme decisão do Coordenador.
