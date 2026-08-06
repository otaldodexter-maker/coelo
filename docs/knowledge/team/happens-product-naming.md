---
title: Happens como nome oficial do feed privado
knowledge_id: happens-product-naming
source: decisions/0018-happens-product-name.md
status: validated
generated_at: 2026-08-04
audience: team
surfaces: [principal, admin, superadmin, plans, documentation]
visibility: internal
review_owner: Coelo Product
---

# Happens como nome oficial do feed privado

`Happens` é o nome oficial do feed privado do Coelo e substitui o nome anterior
em linguagem de produto, documentação ativa e identificadores planejados. A
mudança não altera comportamento, autorização, persistência nem eventos.

Happens, Now e Moments permanecem módulos independentes no domínio e compostos
na experiência do App Coelo. Novos contratos usam `happens`, como em
`PlanFeature.happens`, `social.happens`, `packages/happens` e
`features/happens`.

Usos genéricos de “flow” para descrever fluxos técnicos, `posts`, o evento
`post_published`, Supabase, migrations, schema e fontes históricas originais não
são renomeados por esta decisão.
