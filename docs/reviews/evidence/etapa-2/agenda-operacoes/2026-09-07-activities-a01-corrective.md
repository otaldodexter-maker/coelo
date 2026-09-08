---
title: A01 — corretiva nominal do diretório de Atividades
source: Reserva central; RED real Eng1 em 2026-09-08T01:10:28Z; fixture e927c417fd79a6b879e2e61538ec02cffc067db2; contrato cliente 142bfbec
status: Implementação local revisada; replay GREEN nominal pendente; não E2E
generated: 2026-09-07
---

# Pacote fechado

Migration única: `20260907222911_superadmin_activity_directory_v2_client_contract.sql`.
SHA-256 dos bytes locais LF: `6770c9bcbf5a3c3f6560021c0ca6e03d7bb1f12449878a2e98df64105cc04f92`.

Altera somente `public.superadmin_activity_directory_v2(jsonb,integer,integer,text,boolean)`
e cria `public.superadmin_activity_filter_options_v2()`, com owner postgres e EXECUTE
somente para authenticated. Não altera tabelas, RLS, helpers compartilhados, Auth,
markers, auditoria, mutations, composition root ou migrations históricas.

O diretório mantém a assinatura e aliases legados, normaliza/valida dimensões,
rejeita arrays nulos, tipos inválidos, duplicatas normalizadas, mais de 100 membros,
chaves desconhecidas e mistura escalar/array. OR dentro de cada dimensão e AND entre
elas. Busca literal em nome/descrição; ordenação com desempate ID e total independente
da página. Unidades/grupos são agregados separadamente depois da paginação.

Options lê a hierarquia autorizada sem exigir escrita ou vínculo com atividade.
Preserva exclusão histórica de instituições soft-deleted e estruturas archived,
intersectando também os pais. Os dois wrappers usam activities.read e o contexto
interno vigente; negativa usa o helper minimizado e ações activity.directory ou
activity.filter_options. A01 não altera política AAL nem cria ponte people/internal.

# Evidência e limites

O artefato Eng1 `a01-directory-contract-red-2026-09-07.md`, consultado read-only em
`C:/Users/adrie/Documents/Coelo/.worktrees/e1-replay-harness/docs/reviews/evidence/etapa-2/engenheiro-1/`,
registra 52 migrations canônicas + dois preflights aplicados, fixture completa com
89 TAP: 42 PASS e 47 FAIL funcionais, sem aborto/erro de ACL. Cleanup confirmado
às 01:13:47 UTC. Os 47 FAIL não representam 47 causas independentes.

Esta corretiva nasceu depois desse RED real. A fixture permanece exatamente no
snapshot e927, sem relaxar expectativas para produzir GREEN. O perfil antigo
Foundation67 não é candidato; a base é a seleção nominal A01 do Eng1.

Validação local nova: 37/37 testes do adaptador em
`flutter test --no-pub test/features/activities/data/supabase_activity_directory_repository_test.dart`.
`git diff --check` passou. Duas revisões estáticas independentes verificaram contrato,
isolamento, cardinalidade, paginação, sintaxe e grants. Elas identificaram a
compatibilidade scalar/search-null e as exclusões do catálogo, preservadas no SQL.
Esses dois detalhes foram conferidos estaticamente, não por novos TAP executados.

Próximo gate: Eng1 executar a mesma fixture89 sobre a base nominal mais esta única
corretiva, após grant serial central do pacote/hash fechado. Root não executou SQL,
Docker, deploy, ledger ou operação remota. Não há alegação de GREEN SQL ou E2E.

As skills Coelo integrada/backend e TDD orientaram a separação entre RED real,
corretiva local e replay nominal; revisão de código preservou o contrato anterior.
Não mudou regra de produto aprovada: gate de conhecimento sem nova projeção.
