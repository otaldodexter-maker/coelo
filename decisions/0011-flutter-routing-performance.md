---
title: "Flutter Routing and Performance Foundation"
status: "Accepted for implementation"
generated_at: "2026-06-30"
source: "User request on Flutter/Dart performance, componentization, isolates, async/await and GoRouter"
---

# Flutter Routing and Performance Foundation

## Contexto

Os apps privados do Coelo precisam nascer leves, componentizados e preparados
para Flutter Web/mobile sem travar a thread de interface. Admin, Superadmin e
Principal compartilham stack Flutter/Dart, mas nao devem compartilhar telas
entre si.

## Decisao

Adotar `go_router` como padrao de roteamento declarativo dos apps Flutter
privados e usar `MaterialApp.router` nas composicoes principais. Cada app deve
manter suas rotas em `lib/app/router`, com guards e redirects representando
apenas estado local de sessao/contexto; autorizacao real continua no backend,
Postgres/RLS ou funcoes server-side.

Cada app deve possuir `lib/core/isolates` para helpers de computacao pesada.
Parsing grande, normalizacao em lote, filtros custosos, preparacao de
exportacoes, validacoes em massa e transformacoes de midia/metadados nao devem
rodar dentro de `build`, callbacks de scroll ou widgets.

Telas devem ser pequenas e compostas por widgets locais. Widgets reutilizaveis
dentro de uma feature ficam em `presentation/widgets`; componentes
compartilhados sobem para `packages/coelo_ui_core`,
`packages/coelo_ui_admin` ou `packages/coelo_ui_principal`, conforme o dominio.

## Regras praticas

- Usar `const` em widgets, construtores e valores imutaveis sempre que possivel.
- Usar `async`/`await`, `Future` e cancelamento/estado explicito para tarefas
  assicronas; nao bloquear a UI com trabalho sincronico longo.
- Usar `ListView.builder`, `GridView.builder` ou slivers para listas grandes.
- Decidir layout por constraints (`LayoutBuilder`, breakpoints Coelo), nao por
  tipo de aparelho.
- Evitar animacoes longas, permanentes ou decorativas; respeitar tokens de
  motion e reduzir movimento quando o sistema pedir.
- Nao carregar imagens enormes a cega. Features com midia devem pedir
  thumbnails/variantes adequadas, dimensoes explicitas, placeholder/erro e cache
  controlado. O uso de `cached_network_image` deve ser introduzido pela spec da
  feature que realmente carrega midia remota.
- Dados sensiveis e URLs temporarias de midia privada nao devem ser cacheados
  sem regra explicita de seguranca, expiracao e limpeza.

## Consequencias

- O Superadmin passa primeiro para `go_router` e ganha helper de computacao em
  `core/isolates`.
- Admin e Principal devem seguir o mesmo padrao ao receber codigo executavel.
- Specs futuras de tela devem incluir criterio de performance, estados de UX,
  testes widget/unitarios e decisao de cache de imagem quando houver midia.
- Qualquer excecao relevante deve virar ADR ou pergunta aberta antes de virar
  padrao alternativo.
