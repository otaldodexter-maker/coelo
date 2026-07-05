---
source: "AGENTS.md; docs/architecture/macro-architecture.md"
status: "planning-context"
generated_at: "2026-06-22"
---

# Apps

Esta pasta guarda as superficies executaveis do Coelo. Cada app deve ter
fronteira propria, contexto explicito e dependencia minima de outras
superficies.

## Superficies

- `site`: site publico Astro em `coelo.me`.
- `superadmin`: Flutter privado para operacao interna Coelo.
- `admin`: Flutter privado para gestao da instituicao.
- `principal`: Flutter privado/mobile-first para responsaveis, familias,
  alunos e equipe no uso diario.

## Regra de organizacao

O site usa convencoes web/Astro: `pages`, `layouts`, `components`,
`sections`, `styles`, `content`, `lib` e middleware quando necessario.

Os apps Flutter usam organizacao por feature: `app`, `core` e `features`.
Dentro de cada feature, quando houver codigo real, o padrao sera separar
`presentation`, `domain` e `data`.

## Padroes Flutter de performance

- Rotas devem usar `go_router` com `MaterialApp.router`; configuracao fica em
  `lib/app/router`.
- Cada app Flutter deve manter `lib/core/isolates` para helpers de computacao
  pesada, como parsing grande, filtros custosos, validacoes em massa,
  exportacoes e preparacao de metadados de midia.
- Telas roteaveis ficam em `presentation/screens`; widgets locais e pequenos
  ficam em `presentation/widgets`; estado e comandos ficam em
  `presentation/view_models`.
- Use `const` sempre que possivel para reduzir rebuilds desnecessarios.
- Use `async`/`await` e `Future` para I/O e tarefas assincronas; nenhum trabalho
  sincronico pesado deve acontecer em `build`, callbacks de scroll ou widgets.
- Listas grandes devem usar builders/slivers e paginacao; telas administrativas
  devem impor largura maxima e breakpoints Coelo.
- Imagens remotas devem usar dimensoes explicitas, thumbnails/variantes e cache
  controlado. Nao carregue original grande sem necessidade, especialmente midia
  privada infantil.
- Animacoes devem ser curtas, discretas, tokenizadas e respeitar reduced
  motion.

## Fronteiras

- `site` nao importa codigo Flutter.
- `principal` nao importa UI administrativa.
- Apps privados podem compartilhar tokens, dominio, auth e API via
  `packages/`, mas nao devem importar telas uns dos outros.
- Dados sensiveis, secrets e `service_role` nunca entram no cliente.
