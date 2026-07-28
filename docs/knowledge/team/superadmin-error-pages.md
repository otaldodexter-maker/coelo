---
title: Páginas de erro do Superadmin
knowledge_id: superadmin-error-pages
source: docs/design/design-system.md
status: validated
generated_at: 2026-07-28
audience: team
surfaces: [superadmin, error-pages]
visibility: internal
review_owner: Coelo Product
---

# Páginas de erro do Superadmin

O Superadmin possui páginas fullscreen para 403, 404, 500 e 503. Elas usam uma
tela limpa, sem shell, menu ou cabeçalho, com fundo
`colorScheme.primaryContainer`, conteúdo em `onPrimaryContainer` e uma única
ação contextual. O 401 continua redirecionando para autenticação; o 429
permanece feedback contextual.

Código, divisor e mensagem ficam em linha quando há largura suficiente e passam
para coluna no compact ou com texto ampliado. Código e mensagem são anunciados
como uma única informação de erro. A referência deve ser validada em
375/768/1024/1440, light/dark e texto a 200%.

Este padrão não substitui `CoeloStatePanel`, usado para estados dentro de uma
superfície existente. O catálogo Coelo UI registra a referência em
`pattern.error-pages`. Admin e Principal exigem specs consumidoras antes de
adotar a composição.
