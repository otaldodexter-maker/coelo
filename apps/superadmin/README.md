---
source: "AGENTS.md; docs/contexts/superadmin-context.md; docs/product/prd-superadmin.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Superadmin Flutter

Aplicacao privada para operacao interna Coelo em `superadmin.coelo.me`.
Controla instituicoes, planos manuais, usuarios internos, avisos, suporte
auditado, logs e governanca da plataforma.

## Estrutura planejada

- `lib/app`: composicao do app, shell e rotas.
- `lib/core`: configuracoes, guards e infraestrutura local do app.
- `lib/features`: modulos de produto do Superadmin.

## Base implementada

- O app usa `MaterialApp.router` com `go_router`.
- O router fica em `lib/app/router`.
- Computacoes pesadas devem passar por `lib/core/isolates`.
- O shell atual ja decide layout por constraints e breakpoints Coelo.

## Componentizacao

As telas do Superadmin devem nascer componentizadas por feature. A tela completa
fica em `apps/superadmin/lib/features/<feature>/presentation/screens`, e os
widgets locais daquela tela ficam em
`apps/superadmin/lib/features/<feature>/presentation/widgets`.

Use esta regra pratica:

- `presentation/screens`: telas completas e roteaveis.
- `presentation/widgets`: componentes locais da feature, como filtros,
  formularios, cards, linhas de tabela e blocos de detalhe.
- `presentation/view_models`: estado de tela, comandos e carregamento.
- `domain`: entidades e regras especificas da feature.
- `data`: repositories, DTOs, mocks e adapters.

Quando um componente for reutilizavel por mais de uma feature do Superadmin, ou
tambem fizer sentido para o Admin institucional, ele deve sair da feature e ir
para `packages/coelo_ui_admin`. Componentes sem dominio, como botoes, campos,
feedback, navegacao base e acessibilidade, pertencem a `packages/coelo_ui_core`.
Tokens de cor, tipografia, espacamento e temas pertencem a `packages/coelo_tokens`.

## Performance obrigatoria

- Use `const` em widgets e valores imutaveis sempre que possivel.
- Evite arquivos de tela grandes: extraia blocos repetidos ou complexos para
  widgets locais.
- ViewModels carregam dados com `Future`/`async`/`await` e expoem estados
  claros de loading, empty, erro, offline e permissao negada.
- Use builders/slivers para listas, tabelas longas e resultados paginados.
- Nao processe CSV, JSON grande, exportacao, filtros pesados ou metadados de
  midia no build da tela; use `core/isolates`.
- Midia remota deve usar variante adequada, tamanho conhecido e cache com regra
  de seguranca. Introduza dependencias como `cached_network_image` somente na
  spec da feature que precisar de midia remota.

## Contextos iniciais

- `institutions`: ativacao e gestao de instituicoes.
- `platform_users`: usuarios internos Coelo.
- `plans`: planos, status e limites manuais.
- `notices`: avisos globais ou segmentados.
- `support`: sessoes de suporte auditadas.
- `audit`: logs e evidencias de acoes sensiveis.

## Por que assim

O Superadmin concentra poder operacional. A estrutura por feature ajuda a
manter cada fluxo isolado, auditavel e pronto para receber autorizacao
server-side/RLS sem misturar telas de Admin ou Principal.
