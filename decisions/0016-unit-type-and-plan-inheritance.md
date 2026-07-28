---
title: "Tipo Próprio E Herança De Plano Por Unidade"
source: "aprovação do plano Tela de Unidades no Superadmin em 2026-07-28; schema Supabase consultado em 2026-07-28"
status: "Accepted"
generated_at: "2026-07-28"
---

# Tipo Próprio E Herança De Plano Por Unidade

## Contexto

Uma instituição pode operar unidades com especializações e condições comerciais
diferentes. O tipo e o plano da instituição, isoladamente, não descrevem todos
os seus filhos. Ao mesmo tempo, repetir o plano em cada unidade eliminaria a
herança e faria alterações institucionais deixarem de se propagar.

O schema Supabase consultado possui `units`, `unit_addresses`,
`unit_contacts`, `unit_branding`, `groups` e `activity_unit_links`. Hoje
`units` contém vínculo institucional, nome, slug, status e timestamps, mas não
possui coluna de tipo nem assinatura ou override de plano.

## Decisão

- Toda unidade pertence obrigatoriamente a uma instituição.
- A unidade possui tipo próprio e usa o mesmo catálogo taxonômico dos tipos de
  instituição; não existe um segundo catálogo de tipos.
- O plano efetivo da unidade é `override da unidade ?? plano da instituição`.
- Uma unidade nova herda o plano institucional por padrão.
- Enquanto não houver override, alterações no plano institucional são
  refletidas automaticamente na unidade.
- Remover o override restaura a herança.
- A instituição de uma unidade existente não pode ser trocada nesta operação.
- Os status persistíveis são `draft`, `active`, `inactive`, `suspended` e
  `archived`.
- Grupos e atividades aparecem como métricas na gestão da unidade, mas são
  cadastrados em seus próprios domínios.
- Branding institucional é herdado por padrão e pode receber override por
  unidade através do contrato de `unit_branding`.

## Consequências

A tela atual usa um repositório fake e expande o registro local de unidade
existente dentro de `InstitutionRecord`, preservando uma fonte única para
instituições, unidades e contagens.

A persistência futura precisa de spec própria para adicionar tipo e override de
plano, além de diretório agregado, migration, RLS, RPCs, auditoria e testes de
isolamento entre tenants. Esta decisão não autoriza alteração do banco.
