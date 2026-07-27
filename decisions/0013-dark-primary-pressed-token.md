---
title: "Dark Primary Pressed Token"
source: "docs/design/design-system.md; docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md; decisao aprovada pelo usuario em 2026-07-22"
status: "Accepted for implementation"
generated_at: "2026-07-22"
---

# Dark Primary Pressed Token

## Contexto

O Design System oficial define o botao primario escuro com `orange300` e o
tema atual usa `orange400` no hover. O estado pressionado esta documentado
somente para o tema claro, como `orange700`.

## Decisao

Usar `orange500` em `CoeloActionColors.primaryPressed` no tema escuro. A
progressao fica `orange300` no repouso, `orange400` no hover e `orange500` ao
pressionar. No tema claro, preservar a definicao oficial: `orange500`,
`orange600` e `orange700`, respectivamente.

## Consequencias

- O estado pressionado passa a ter um token semantico explicito em ambos os
  temas.
- Esta decisao nao altera componentes existentes por si so.
- Componentes so adotam o token quando sua migracao ou contrato aprovado
  exigir estado pressionado explicito e coberto por teste.
