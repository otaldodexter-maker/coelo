---
title: "Happens como nome oficial do feed privado"
status: "Accepted for planning"
generated_at: "2026-08-04"
source: "Aprovação explícita do Coelo Owner"
---

# Happens como nome oficial do feed privado

## Contexto

O módulo de feed privado do Coelo era apresentado como `Flow`. A nomenclatura
foi substituída para consolidar a identidade de produto sem alterar seu domínio,
comportamento, regras de autorização ou persistência.

## Decisão

`Happens` substitui `Flow` em linguagem de produto, feature entitlements,
scaffolds locais e documentação ativa. Os módulos `Happens`, `Now` e `Moments`
continuam independentes no domínio e compostos na experiência do App Coelo.

Identificadores planejados passam a usar `happens`, incluindo
`PlanFeature.happens`, `social.happens`, `packages/happens` e
`features/happens`.

## Consequências

- A mudança é somente de nomenclatura e não cria alteração funcional.
- Tabelas, migrations, schema, eventos existentes como `post_published` e o
  conceito genérico de fluxo técnico permanecem inalterados.
- Fontes históricas preservadas em `docs/source/originals/` não são reescritas.
- Novas specs e implementações devem usar `Happens`/`happens`.
